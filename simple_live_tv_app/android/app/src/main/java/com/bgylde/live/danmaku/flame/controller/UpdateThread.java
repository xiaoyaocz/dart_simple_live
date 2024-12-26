
package com.bgylde.live.danmaku.flame.controller;

public class UpdateThread extends Thread {

    public UpdateThread(String name) {
        super(name);
    }

    volatile boolean mIsQuited;

    public void quit() {
        mIsQuited = true;
    }
    
    public boolean isQuited() {
        return mIsQuited;
    }

    @Override
    public void run() {
        if (mIsQuited)
            return;
    }

}
