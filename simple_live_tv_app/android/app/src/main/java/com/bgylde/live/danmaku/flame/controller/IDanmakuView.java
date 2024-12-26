
package com.bgylde.live.danmaku.flame.controller;

import android.view.View;

import com.bgylde.live.danmaku.flame.controller.DrawHandler.Callback;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.model.android.DanmakuContext;
import com.bgylde.live.danmaku.flame.parser.BaseDanmakuParser;

public interface IDanmakuView {
    
    public final static int THREAD_TYPE_NORMAL_PRIORITY = 0x0;
    public final static int THREAD_TYPE_MAIN_THREAD = 0x1;
    public final static int THREAD_TYPE_HIGH_PRIORITY = 0x2;
    public final static int THREAD_TYPE_LOW_PRIORITY = 0x3;
    

    public boolean isPrepared();
    
    public boolean isPaused();

    public boolean isHardwareAccelerated();
    /**
     * 
     * @param type One of THREAD_TYPE_MAIN_THREAD, THREAD_TYPE_HIGH_PRIORITY, THREAD_TYPE_NORMAL_PRIORITY, or THREAD_TYPE_LOW_PRIORITY.
     */
    public void setDrawingThreadType(int type);

    public void enableDanmakuDrawingCache(boolean enable);

    public boolean isDanmakuDrawingCacheEnabled();

    public void showFPS(boolean show);
    
    /**
     * danmaku.isLive == true的情况下,请在非UI线程中使用此方法,避免可能卡住主线程
     * @param item
     */
    public void addDanmaku(BaseDanmaku item);

    public void invalidateDanmaku(BaseDanmaku item, boolean remeasure);
    
    public void removeAllDanmakus(boolean isClearDanmakusOnScreen);
    
    public void removeAllLiveDanmakus();

    public IDanmakus getCurrentVisibleDanmakus();
    
    public void setCallback(Callback callback);
    
    /**
     * for getting the accurate play-time. use this method intead of parser.getTimer().currMillisecond
     * @return
     */
    public long getCurrentTime();

    public DanmakuContext getConfig();
    
    // ------------- Android View方法  --------------------
    
    public View getView();

    public int getWidth();

    public int getHeight();

    public void setVisibility(int visibility);
    
    public boolean isShown();
    

    // ------------- 播放控制 -------------------
    
    public void prepare(BaseDanmakuParser parser, DanmakuContext config);

    public void seekTo(Long ms);

    public void start();

    public void start(long postion);

    public void stop();

    public void pause();

    public void resume();

    public void release();
    
    public void toggle();
    
    public void show();
    
    public void hide();
    
    /**
     * show the danmakuview again if you called hideAndPauseDrawTask()
     * @param position The position you want to resume
     * @see #hideAndPauseDrawTask
     */
    public void showAndResumeDrawTask(Long position);
    
    /**
     * hide the danmakuview and pause the drawtask
     * @return the paused position
     * @see #showAndResumeDrawTask
     */
    public long hideAndPauseDrawTask();

    public void clearDanmakusOnScreen();

 // ------------- Click Listener -------------------
    public interface OnDanmakuClickListener {
     /**
      *
      * @param latest the latest one is clicked
      */
      void onDanmakuClick(BaseDanmaku latest);

     /**
      *
      * @param danmakus all to be clicked
      */
        void onDanmakuClick(IDanmakus danmakus);
    }

    public void setOnDanmakuClickListener(OnDanmakuClickListener listener);
    public OnDanmakuClickListener getOnDanmakuClickListener();

}
