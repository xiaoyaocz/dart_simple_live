package com.bgylde.live.danmaku.controller;

import android.content.Context;

/**
 * For internal control. DO NOT ACCESS this interface.
 */
public interface IDanmakuViewController {

    public boolean isViewReady();

    public int getWidth();

    public int getHeight();

    public Context getContext();

    public long drawDanmakus();

    public void clear();

    public boolean isHardwareAccelerated();

    public boolean isDanmakuDrawingCacheEnabled();

}
