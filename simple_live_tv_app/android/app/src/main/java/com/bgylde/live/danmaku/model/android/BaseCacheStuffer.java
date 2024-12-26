package com.bgylde.live.danmaku.model.android;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.text.TextPaint;

import com.bgylde.live.danmaku.model.BaseDanmaku;

/**
 * Created by ch on 15-7-16.
 */
public abstract class BaseCacheStuffer {

    public static abstract class Proxy {
        /**
         * 在弹幕显示前使用新的text,使用新的text
         * @param danmaku
         * @param fromWorkerThread 是否在工作(非UI)线程,在true的情况下可以做一些耗时操作(例如更新Span的drawblae或者其他IO操作)
         * @return 如果不需重置，直接返回danmaku.text
         */
        public abstract void prepareDrawing(BaseDanmaku danmaku, boolean fromWorkerThread);

        public abstract void releaseResource(BaseDanmaku danmaku);
    }

    protected Proxy mProxy;

    /**
     * set paintWidth, paintHeight to danmaku
     * @param danmaku
     * @param fromWorkerThread
     */
    public abstract void measure(BaseDanmaku danmaku, TextPaint paint, boolean fromWorkerThread);

    /**
     * draw the danmaku-stroke on canvas with the given params
     * @param danmaku
     * @param lineText
     * @param canvas
     * @param left
     * @param top
     * @param paint
     */
    public abstract void drawStroke(BaseDanmaku danmaku, String lineText, Canvas canvas, float left, float top, Paint paint);

    /**
     * draw the danmaku-text on canvas with the given params
     * @param danmaku
     * @param lineText
     * @param canvas
     * @param left
     * @param top
     * @param paint
     * @param fromWorkerThread
     */
    public abstract void drawText(BaseDanmaku danmaku, String lineText, Canvas canvas, float left, float top, TextPaint paint, boolean fromWorkerThread);

    /**
     * clear caches which created by this stuffer
     */
    public abstract void clearCaches();

    /**
     * draw the background in rect (left, top, left + danmaku.paintWidth, top + danmaku.paintHeight)
     * @param danmaku
     * @param canvas
     * @param left
     * @param top
     */
    public abstract void drawBackground(BaseDanmaku danmaku, Canvas canvas, float left, float top);

    public void clearCache(BaseDanmaku danmaku) {

    }

    public void setProxy(Proxy adapter) {
        mProxy = adapter;
    }

    public void releaseResource(BaseDanmaku danmaku) {
        if (mProxy != null) {
            mProxy.releaseResource(danmaku);
        }
    }

}
