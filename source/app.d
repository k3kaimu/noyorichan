module app;

import core.thread;
import core.memory;
import core.atomic;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.process;
import std.regex;
import std.uri;
import std.datetime;
import std.json;
import std.file;

import carbon.actor;

import graphite.twitter;

import markov;
import tinysegmenter;
import noyori;
import threads.tweet;
import threads.learn;
import threads.reply;

import msgpack;


void main(string[] args)
{
    // 設定読み込み
    auto settingJSON = readText("setting.json");
    auto setting = parseJSON(settingJSON);

    // アクセストークン等の設定
    auto accessTok = AccessToken(ConsumerToken(
                                 setting["consumer"]["key"].str,
                                 setting["consumer"]["secret"].str
                                 ),
                                 setting["access"]["key"].str,
                                 setting["access"]["secret"].str);

    auto twitter = Twitter(accessTok);

    // のよりちゃんの復元
    shared(Noyori) noyori;

    if(exists("noyori.dat"))
        unpack(cast(ubyte[])std.file.read("noyori.dat"), noyori);
    else
        noyori = new shared Noyori();


    // 全スレッドを停止させるための停止フラグ
    shared(bool)* endFlag = new shared bool;
    scope(exit){
        // main関数終了とともに，すべてのスレッドに停止命令を発行する
        atomicStore(*endFlag, true);
    }

    // 各スレッドの起動
    auto learnThread = runPhoenixActor!LearnThread(noyori, settingJSON, endFlag),
         tweetThread = runPhoenixActor!TweetThread(noyori, accessTok, settingJSON, endFlag),
         replyThread = runPhoenixActor!ReplyThread(noyori, accessTok, settingJSON, endFlag);

    while(1)
    {
        try{
            writeln("start");

            // Userstreamに接続
            auto ustLines = twitter.callAPI!"userstream.user"(null);

            // Userstreamスレッドで例外は生じた場合にどうするかを設定
            ustLines.onReceiveException = delegate(Exception ex, bool isEnd) { writeln(isEnd ? "End Of Userstream thread: " : "ReceiveException from Userstream thread: ", ex); };

            // Userstreamから来たメッセージを読む
            foreach(ustLine; ustLines.map!chomp.filter!"a.length") {
                // 各スレッドが死亡していた場合，再起動をかける
                if(learnThread.isDestroyed) learnThread = runPhoenixActor!LearnThread(noyori, settingJSON, endFlag);
                if(tweetThread.isDestroyed) tweetThread = runPhoenixActor!TweetThread(noyori, accessTok, settingJSON, endFlag);
                if(replyThread.isDestroyed) replyThread = runPhoenixActor!ReplyThread(noyori, accessTok, settingJSON, endFlag);

                // 各スレッドにツイートを流し込む
                learnThread.onReceiveTweet(ustLine);
                tweetThread.onReceiveTweet(ustLine);
                replyThread.onReceiveTweet(ustLine);
            }
        }
        catch(Exception ex) { writeln(ex); }
        catch(Error ex) { writeln(ex); }
    }
}
