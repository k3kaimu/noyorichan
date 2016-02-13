module threads.tweet;


import core.time;
import core.atomic;
import core.memory;

import std.datetime;
import std.json;
import std.stdio;
import std.string;
import std.typecons;
import std.container;

import carbon.actor;

import graphite.twitter;

import msgpack;

import noyori;


/**
ツイートスレッド

定期的にツイートを行うスレッドです
*/
struct TweetThread
{
    this(shared(Noyori) noyori, AccessToken twToken, string settingJSON, shared(bool)* endFlag)
    {
        _noyori = noyori;
        _twitter = Twitter(twToken);
        _endFlag = endFlag;
        _lastTime = Clock.currTime - 10.minutes;
        _logFile = File("genLog.txt", "a");
    }


    bool isEnd() const @property { return atomicLoad(*_endFlag); }


    @ThreadEvent
    void onReceiveTweet(string tweetJSON)
    {

    }


    void onResurrection(Throwable ex)
    {
        writeln("On TweetThread: ", ex);
    }


    enum Duration maxInterval = 10.seconds;


    void onUpdate()
    {
        auto currTime = Clock.currTime;

        if(Clock.currTime - _lastTime > 10.minutes){
            string ngen = _noyori.generate;
            auto wordCNT = _noyori.totalWordCount,
                 keyCNT = _noyori.keyCount,
                 learnedCNT = _noyori.learnedCount;

            wordCNT -= learnedCNT;

            _twitter.callAPI!"statuses.update"(["status": ngen]);
            _logFile.writefln("%s,%s,%s,%s,%s,",
                [ngen], learnedCNT, keyCNT, wordCNT, wordCNT / cast(real)keyCNT);
            _logFile.flush();

            // 1時間ごとに状態を保存
            if(_lastTime.hour != currTime.hour){
                Array!ubyte arr;    // malloc,freeで管理されるので，こいつを使う
                auto p = packer((ubyte[] b...){ arr ~= b; });

                synchronized(_noyori)
                    p.pack(_noyori);

                auto f = File("noyori.dat", "w");
                f.rawWrite((&(arr[0]))[0 .. arr.length]);
            }

            // 1日ごとにバックアップを作成
            if(cast(Date)_lastTime < cast(Date)currTime){
                std.file.copy("noyori.dat", format("backup/%s%s%s.dat", _lastTime.year, _lastTime.month, _lastTime.day));
            }

            GC.collect();
            GC.minimize();

            _lastTime = Clock.currTime;
        }
    }


  private:
    shared(Noyori) _noyori;
    Twitter _twitter;
    shared(bool)* _endFlag;
    SysTime _lastTime;
    File _logFile;
}


static assert(isIncessantActor!TweetThread && isPhoenixActor!TweetThread);
