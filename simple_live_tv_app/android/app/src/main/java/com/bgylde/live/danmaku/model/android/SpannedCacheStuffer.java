package com.bgylde.live.danmaku.model.android;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.text.Layout;
import android.text.Spanned;
import android.text.StaticLayout;
import android.text.TextPaint;

import java.lang.ref.SoftReference;

import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.util.DanmakuUtils;

/**
 * Created by ch on 15-7-16.
 */
public class SpannedCacheStuffer extends SimpleTextCacheStuffer {

    @Override
    public void measure(BaseDanmaku danmaku, TextPaint paint, boolean fromWorkerThread) {
        if (danmaku.text instanceof Spanned) {
            if (mProxy != null) {
                mProxy.prepareDrawing(danmaku, fromWorkerThread);
            }
            CharSequence text = danmaku.text;
            if (text != null) {
                StaticLayout staticLayout = new StaticLayout(text, paint, (int) Math.ceil(StaticLayout.getDesiredWidth(danmaku.text, paint)), Layout.Alignment.ALIGN_NORMAL, 1.0f, 0.0f, true);
                danmaku.paintWidth = staticLayout.getWidth();
                danmaku.paintHeight = staticLayout.getHeight();
                danmaku.obj = new SoftReference<>(staticLayout);
                return;
            }
        }
        super.measure(danmaku, paint, fromWorkerThread);
    }

    @Override
    public void drawStroke(BaseDanmaku danmaku, String lineText, Canvas canvas, float left, float top, Paint paint) {
        if (danmaku.obj == null) {
            super.drawStroke(danmaku, lineText, canvas, left, top, paint);
        }
    }

    @Override
    public void drawText(BaseDanmaku danmaku, String lineText, Canvas canvas, float left, float top, TextPaint paint, boolean fromWorkerThread) {
        if (danmaku.obj == null) {
            super.drawText(danmaku, lineText, canvas, left, top, paint, fromWorkerThread);
            return;
        }
        SoftReference<StaticLayout> reference = (SoftReference<StaticLayout>) danmaku.obj;
        StaticLayout staticLayout = reference.get();
        boolean requestRemeasure = 0 != (danmaku.requestFlags & BaseDanmaku.FLAG_REQUEST_REMEASURE);
        boolean requestInvalidate = 0 != (danmaku.requestFlags & BaseDanmaku.FLAG_REQUEST_INVALIDATE);

        if (requestInvalidate || staticLayout == null) {
            if (requestInvalidate) {
                danmaku.requestFlags &= ~BaseDanmaku.FLAG_REQUEST_INVALIDATE;
            } else if (mProxy != null) {
                mProxy.prepareDrawing(danmaku, fromWorkerThread);
            }
            CharSequence text = danmaku.text;
            if (text != null) {
                if (requestRemeasure) {
                    staticLayout = new StaticLayout(text, paint, (int) Math.ceil(StaticLayout.getDesiredWidth(danmaku.text, paint)), Layout.Alignment.ALIGN_NORMAL, 1.0f, 0.0f, true);
                    danmaku.paintWidth = staticLayout.getWidth();
                    danmaku.paintHeight = staticLayout.getHeight();
                    danmaku.requestFlags &= ~BaseDanmaku.FLAG_REQUEST_REMEASURE;
                } else {
                    staticLayout = new StaticLayout(text, paint, (int) danmaku.paintWidth, Layout.Alignment.ALIGN_NORMAL, 1.0f, 0.0f, true);
                }
                danmaku.obj = new SoftReference<>(staticLayout);
            } else {
                return;
            }
        }
        boolean needRestore = false;
        if (left != 0 && top != 0) {
            canvas.save();
            canvas.translate(left, top + paint.ascent());
            needRestore = true;
        }
        staticLayout.draw(canvas);
        if (needRestore) {
            canvas.restore();
        }
    }

    @Override
    public void clearCaches() {
        super.clearCaches();
        System.gc();
    }

    @Override
    public void clearCache(BaseDanmaku danmaku) {
        super.clearCache(danmaku);
        if (danmaku.obj instanceof SoftReference<?>) {
            ((SoftReference<?>) danmaku.obj).clear();
        }
    }

    @Override
    public void releaseResource(BaseDanmaku danmaku) {
        clearCache(danmaku);
        super.releaseResource(danmaku);
    }
}
