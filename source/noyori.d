module noyori;

import tinysegmenter;
import markov;
import std.conv;
import std.range;
import std.random;
import std.container;

import msgpack;


final synchronized class Noyori
{
    this()
    {
        _markov3_ = cast(shared)new Markov3(TinySegmenter.init);
        _markov2_ = cast(shared)new Markov2(TinySegmenter.init);
    }


    void learn(C)(const(C)[] tweet)
    {
        foreach(s; normalize(tweet.to!dstring)){
            _markov2.learn(s.to!string);
            _markov3.learn(s.to!string);
        }
    }


    string generate()
    {
        string t;

        if(dice(0.3, 0.7) == 0)
            t = _markov2.generate();
        else{
            size_t size = dice(0.1, 0.1, 0.2, 0.2, 0.3, 0.1) * 10;
            while(t.walkLength < size)
                t = _markov3.generate();
        }

        return t;
    }


    size_t keyCount() const @property
    {
        return _markov3.keyCount;
    }


    size_t learnedCount() const @property
    {
        return _markov3.learnedCount;
    }


    ulong totalWordCount() const @property
    {
        return _markov3.totalWordCount;
    }


  private:
    inout(Markov3) _markov3() inout @property { return cast(inout)cast()_markov3_; }
    inout(Markov2) _markov2() inout @property { return cast(inout)cast()_markov2_; }

    alias Markov3 = Markov!(TinySegmenter, 3);
    alias Markov2 = Markov!(TinySegmenter, 2);

    Markov3 _markov3_;
    Markov2 _markov2_;

  static:
    // ツイートを有効な文に区切ります
    dstring[] normalize(const(dchar)[] tweet)
    {
        import std.algorithm,
               std.string,
               std.regex,
               std.array;

        // RTツイートは無視する(重複するため)
        if(canFind(tweet, "RT"d)) return [];

        // 解析精度を上げるために，これらの文字が入ったツイートは無視する
        foreach(dchar c; [':', '/', '?', '!', '.', '@', '#', '[', ']', '(', ')', '（', '）', '「', '」', '【', '】', '『', '』', '&', '"', '”', '“'])
            if(canFind(tweet, c))
                return [];

        // "．"などでツイートを区切る
        return tweet
        .splitter!"b.canFind(a)"(cast(dchar[])['．', '。', '？', '！'])
        .map!strip
        .filter!"a.length"()
        .map!(a => a.to!dstring)
        .array;
    }
}
