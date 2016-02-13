module threads.learn;

import core.time;
import core.atomic;

import std.json;
import std.stdio;

import carbon.actor;

import noyori;


/**
学習スレッド

ツイートを学習するためのスレッドです．
*/
struct LearnThread
{
    this(shared(Noyori) noyori, string settingJSON, shared(bool)* endFlag)
    {
        _noyori = noyori;
        _endFlag = endFlag;
        _logFile = File("tweetsLog.txt", "a");
        _myId = parseJSON(settingJSON)["account"]["id"].str;
    }


    bool isEnd() const @property { return atomicLoad(*_endFlag); }


    @ThreadEvent
    void onReceiveTweet(string tweetJSON)
    {
        JSONValue json;
        try json = parseJSON(tweetJSON);
        catch(JSONException) return;

        if(json.type != JSON_TYPE.OBJECT || "text" !in json.object) return;
        if(json["user"]["screen_name"].str == _myId) return;

        _noyori.learn(json["text"].str);
        writeln("GET: ", json["text"].str);
        _logFile.writefln("%s,", [json["text"].str]);
    }


    void onResurrection(Throwable ex) const
    {
        if(auto e = cast(Exception)ex)
            writeln("On LearnThread: ", e);
        else if(auto e = cast(Error)ex)
            writeln("On LearnThread: ", e);
        else
            writeln("On LearnThread: ", ex);
    }


    enum Duration maxInterval = 10.dur!"seconds";

    void onUpdate() {}


  private:
    shared(Noyori) _noyori;
    shared(bool)* _endFlag;
    File _logFile;
    string _myId;
}

static assert(isIncessantActor!LearnThread && isPhoenixActor!LearnThread);
