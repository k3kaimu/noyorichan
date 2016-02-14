module threads.reply;


import core.time;
import core.atomic;

import std.algorithm;
import std.ascii;
import std.conv;
import std.json;
import std.random;
import std.regex;
import std.stdio;
import std.string;
import std.uni;
import std.utf;
import std.file;

import carbon.actor;

import graphite.twitter;

import noyori;


/**
リプライスレッド

リプライを返すためのスレッドです．
*/
struct ReplyThread
{
    this(shared(Noyori) noyori, AccessToken twToken, string settingJSON, shared(bool)* endFlag)
    {
        _noyori = noyori;
        _twitter = Twitter(twToken);
        _endFlag = endFlag;

        auto json = parseJSON(settingJSON)["account"];
        _myId = json["id"].str;
        foreach(e; json["names"].array)
            _myNames ~= e.str;
    }


    bool isEnd() const @property { return atomicLoad(*_endFlag); }


    @ThreadEvent
    void onReceiveTweet(string tweetJSON)
    {
        void reply(JSONValue json, string msg)
        {
            _twitter.callAPI!"statuses.update"([
                "status": format("@%s %s", json["user"]["screen_name"].str, msg),
                "in_reply_to_status_id": json["id"].to!string
            ]);
        }

        void replyforCallMe(JSONValue json, string str)
        {
            reply(json, format("%s　%s", "呼んだ？", str));
        }


        JSONValue json;

        try json = toJSONValue(tweetJSON);
        catch(JSONException) return;

        if(json.type != JSON_TYPE.OBJECT || "text" !in json.object) return;


        string text = json["text"].str;
        if(json["user"]["screen_name"].str == _myId || text.startsWith("RT")) return;
        if(text.canFind("@" ~ _myId)){
            if(text.canFind("おみくじ")){
                reply(json, Omikuji.omikuji());
            }else if(text.canFind("フォロー") || text.canFind("ふぉろー")){
                scope(success) reply(json, "フォローしたよ");
                scope(failure) reply(json, "フォローミスった");

                _twitter.post("https://api.twitter.com/1.1/friendships/create.json", [
                    "screen_name": json["user"]["screen_name"].str,
                    "follow": "false"
                ]);
            }else{
                reply(json, _noyori.generate);
            }
        }else if(reduce!((a, b) => a || text.canFind(b))(false, _myNames)){
            replyforCallMe(json, _noyori.generate());
        }else if(text.canFind("ひばり") || text.canFind("ひばカス")){
            if(uniform01() < 0.1)
                replyforCallMe(json, _noyori.generate());
        }
    }


    void onResurrection(Throwable ex)
    {
        writeln("On ReplyThread: ", ex);
    }


    enum Duration maxInterval = 10.dur!"seconds";

    void onUpdate() {}


  private:
    shared(Noyori) _noyori;
    Twitter _twitter;
    shared(bool)* _endFlag;
    string _myId;
    string[] _myNames;


    // http://qiita.com/mono_shoo/items/47ae6011faed6ee78334
    static
    JSONValue toJSONValue(string tweet)
    {
        enum rgx = ctRegex!r"\\u([0-9a-fA-F]{4})";
        
        static string tr(Captures!string c)
        {
            dchar val = 0;
            char[4] buf = void;

            auto str = c[1].toUpper();
            foreach(i, ch; str)
                val += (isDigit(ch) ? ch - '0' : ch - ('A' - 10)) << (4 * (3-i));

            return isValidDchar(val) ? toUTF8(buf, val).idup : "□";
        }

        return tweet.replaceAll!tr(rgx).parseJSON();
    }
}

static assert(isIncessantActor!ReplyThread && isPhoenixActor!ReplyThread);

struct Omikuji
{
  static:
    immutable real[string] dict;

    static this()
    {
        dict =
        [
            "大吉" : 50,
            "吉" : 100,
            "中吉" : 50,
            "小吉": 40,
            "凶" : 30,
            "大凶": 10,
            "白紙": 10,
            "占う価値なし": 5,
            "ツイートしてる暇があったら課題したほうがいいんじゃない？": 5,
            "寝てください": 5,
        ];
    }


    string omikuji()
    {
        real sum = 0;
        foreach(k, v; dict) sum += v;

        real q = 0;
        real p = uniform01();
        foreach(k, v; dict){
            q += v / sum;
            if(q >= p)
                return k;
        }

        return dict.keys[uniform(0, $)];
    }
}
