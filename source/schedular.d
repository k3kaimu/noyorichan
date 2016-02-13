module schedular;


__EOF__

final class Schedular
{
    void onReceiveTweet()
    {
        auto curr = Clock.currTime;
        if(cast(Date)_lastTime < cast(Date)curr)
        {
            onUpdateDate(curr);
            _lastTime = curr;
        }

        auto h = Clock.currTime.hour;
        ++todayFreq[h];
    }


    void onUpdateDate(SysTime curr)
    {
        ulong s = _todayFreq.sum();

        foreach(i; 0 .. 24){
            _freq[i] = _freq[i] * 0.9 + (_todayFreq[i] / cast(real)s) * 0.1;
            _todayFreq[i] = 0;
            _todayTweets[i] = 0;
        }
    }


    bool dice(uint tweetsPerDay, Duration interval)
    {
        // todo
        return false;
    }


  private:
    SysTime _lastTime;
    real[24] _freq;
    ulong[24] _todayFreq;
    ulong[24] _todayTweets;
}
