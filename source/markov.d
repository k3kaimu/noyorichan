module markov;

import std.array;
import std.random;
import std.algorithm;
import std.string;
import std.typecons;

import msgpack;


@safe:

enum bool isSegmenter(S) = is(typeof((S s)
{
    string str;
    auto ss = s.segment(str);
    static assert(isInputRange!(typeof(ss)));
    static assert(isSomeString!(ElementType!(typeof(ss))));
}));


/**
直前のN項で次の1項を推定するマルコフ連鎖
*/
final class Markov(S, size_t N)
{
    shared static immutable string[N] START_KEY;
    shared static immutable string END_STR = "\n";

    // START_KEYの初期化
    shared static this()
    {
        string[N] startKey;
        startKey[] = "\n";
        START_KEY = startKey;
    }


    this() { _segmenter = S.init; }
    this(S segmenter) { _segmenter = segmenter; }


    void learn(string sentence)
    {
        auto ss = _segmenter.segment(sentence);

        () nothrow {
            string[N] key = START_KEY;
            foreach(e; ss){
                addWord(key, e);
                shiftAdd(key, e);
            }

            if(key != START_KEY){
                addWord(key, END_STR);
            }
        }();
    }


    string generate() const
    {
      Lrestart:
        bool[string[N]] set;
        string[N] key = START_KEY;
        auto app = appender!string();

        while(1){
            if(auto p = key in _knowledge){
                if(key in set)
                    goto Lrestart;
                else
                    set[key] = false;

                auto next = (*p).randomGet;
                if(next == END_STR) break;

                app.put(next);
                shiftAdd(key, next);
            }else
                break;
        }

        return app.data;
    }


    size_t keyCount() const @property pure nothrow
    {
        return _knowledge.length;
    }


    size_t learnedCount() const @property pure nothrow
    {
        if(auto p = START_KEY in _knowledge)
            return (*p).totalCount;
        else
            return 0;
    }


    ulong totalWordCount() const @property pure nothrow @safe
    {
        return _totalCount;
    }


  private:
    WordList[string[N]] _knowledge;
    @nonPacked S _segmenter;
    ulong _totalCount;


    static struct Word
    {
        string word;
        size_t count;
    }


    static struct WordList
    {
        Word[] words;
        size_t totalCount;


        void add(string word) pure nothrow
        {
            totalCount += 1;
            foreach(ref e; words)
                if(e.word == word){
                    e.count += 1;
                    return;
                }

            words ~= Word(word, 1);
        }


        string randomGet() const
        {
            auto p = uniform01();
            size_t sum = 0;
            foreach(ref e; words){
                sum += e.count;
                auto q = sum / cast(real)totalCount;
                if(q >= p) return e.word;
            }

            return words[$-1].word;
        }
    }


    /*
    key <- [key[1 ..  $], newKey]
    */
    static void shiftAdd(ref string[N] key, string newKey) pure nothrow @nogc
    {
        foreach(i; 0 ..  N-1)
            key[i] = key[i+1];

        key[$-1] = newKey;
    }


    void addWord(const ref string[N] key, string word) pure nothrow
    {
        if(key !in _knowledge) _knowledge[key] = WordList.init;
        _knowledge[key].add(word);
        _totalCount += 1;
    }
}
