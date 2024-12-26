/*
 * Copyright (C) 2013 Chen Hui <calmer91@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.bgylde.live.danmaku.model.android;

import android.annotation.SuppressLint;
import android.graphics.Camera;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.Typeface;
import android.os.Build;
import android.text.TextPaint;

import java.util.HashMap;
import java.util.Map;

import com.bgylde.live.danmaku.model.AbsDisplayer;
import com.bgylde.live.danmaku.model.AlphaValue;
import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.renderer.IRenderer;

public class AndroidDisplayer extends AbsDisplayer<Canvas, Typeface> {

    private Camera camera = new Camera();

    private Matrix matrix = new Matrix();

    private float sLastScaleTextSize;
    private final Map<Float, Float> sCachedScaleSize = new HashMap<>(10);

    public TextPaint PAINT, PAINT_DUPLICATE;

    private Paint ALPHA_PAINT;

    private Paint UNDERLINE_PAINT;

    private Paint BORDER_PAINT;

    /**
     * 下划线高度
     */
    public int UNDERLINE_HEIGHT = 4;

    /**
     * 边框厚度
     */
    public static final int BORDER_WIDTH = 4;

    /**
     * 阴影半径
     */
    private float SHADOW_RADIUS = 4.0f;

    /**
     * 描边宽度
     */
    private float STROKE_WIDTH = 3.5f;

    /**
     * 投影参数
     */
    private float sProjectionOffsetX = 1.0f;
    private float sProjectionOffsetY = 1.0f;
    private int sProjectionAlpha = 0xCC;

    /**
     * 开启阴影，可动态改变
     */
    public boolean CONFIG_HAS_SHADOW = false;
    private boolean HAS_SHADOW = CONFIG_HAS_SHADOW;

    /**
     * 开启描边，可动态改变
     */
    public boolean CONFIG_HAS_STROKE = true;
    private boolean HAS_STROKE = CONFIG_HAS_STROKE;

    /**
     * 开启投影，可动态改变
     */
    public boolean CONFIG_HAS_PROJECTION = false;
    private boolean HAS_PROJECTION = CONFIG_HAS_PROJECTION;

    /**
     * 开启抗锯齿，可动态改变
     */
    public boolean CONFIG_ANTI_ALIAS = true;
    private boolean ANTI_ALIAS = CONFIG_ANTI_ALIAS;

    private BaseCacheStuffer sStuffer = new SimpleTextCacheStuffer();
    private boolean isTranslucent;
    private int transparency = AlphaValue.MAX;
    private float scaleTextSize = 1.0f;
    private boolean isTextScaled = false;

    public AndroidDisplayer() {
        PAINT = new TextPaint();
        PAINT.setStrokeWidth(STROKE_WIDTH);
        PAINT_DUPLICATE = new TextPaint(PAINT);
        ALPHA_PAINT = new Paint();
        UNDERLINE_PAINT = new Paint();
        UNDERLINE_PAINT.setStrokeWidth(UNDERLINE_HEIGHT);
        UNDERLINE_PAINT.setStyle(Style.STROKE);
        BORDER_PAINT = new Paint();
        BORDER_PAINT.setStyle(Style.STROKE);
        BORDER_PAINT.setStrokeWidth(BORDER_WIDTH);
    }

    @SuppressLint("NewApi")
    private static final int getMaximumBitmapWidth(Canvas c) {
        if (Build.VERSION.SDK_INT >= 14) {
            return c.getMaximumBitmapWidth();
        } else {
            return c.getWidth();
        }
    }

    @SuppressLint("NewApi")
    private static final int getMaximumBitmapHeight(Canvas c) {
        if (Build.VERSION.SDK_INT >= 14) {
            return c.getMaximumBitmapHeight();
        } else {
            return c.getHeight();
        }
    }

    public void setTypeFace(Typeface font) {
        if (PAINT != null)
            PAINT.setTypeface(font);
    }

    public void setShadowRadius(float s) {
        SHADOW_RADIUS = s;
    }

    public void setPaintStorkeWidth(float s) {
        PAINT.setStrokeWidth(s);
        STROKE_WIDTH = s;
    }

    public void setProjectionConfig(float offsetX, float offsetY, int alpha) {
        if (sProjectionOffsetX != offsetX || sProjectionOffsetY != offsetY || sProjectionAlpha != alpha) {
            sProjectionOffsetX = (offsetX > 1.0f) ? offsetX : 1.0f;
            sProjectionOffsetY = (offsetY > 1.0f) ? offsetY : 1.0f;
            sProjectionAlpha = (alpha < 0) ? 0 : ((alpha > 255) ? 255 : alpha);
        }
    }

    public void setFakeBoldText(boolean fakeBoldText) {
        PAINT.setFakeBoldText(fakeBoldText);
    }

    @Override
    public void setTransparency(int newTransparency) {
        isTranslucent = (newTransparency != AlphaValue.MAX);
        transparency = newTransparency;
    }

    @Override
    public void setScaleTextSizeFactor(float factor) {
        isTextScaled = (factor != 1f);
        scaleTextSize = factor;
    }

    @Override
    public void setCacheStuffer(BaseCacheStuffer cacheStuffer) {
        if (cacheStuffer != sStuffer) {
            sStuffer = cacheStuffer;
        }
    }

    @Override
    public BaseCacheStuffer getCacheStuffer() {
        return sStuffer;
    }

    public Canvas canvas;

    private int width;

    private int height;

    private float density = 1;

    private int densityDpi = 160;

    private float scaledDensity = 1;

    private int mSlopPixel = 0;

    private boolean mIsHardwareAccelerated = true;

    private int mMaximumBitmapWidth = 2048;

    private int mMaximumBitmapHeight = 2048;

    private void update(Canvas c) {
        canvas = c;
        if (c != null) {
            width = c.getWidth();
            height = c.getHeight();
            if (mIsHardwareAccelerated) {
                mMaximumBitmapWidth = getMaximumBitmapWidth(c);
                mMaximumBitmapHeight = getMaximumBitmapHeight(c);
            }
        }
    }

    @Override
    public int getWidth() {
        return width;
    }

    @Override
    public int getHeight() {
        return height;
    }

    @Override
    public float getDensity() {
        return density;
    }

    @Override
    public int getDensityDpi() {
        return densityDpi;
    }

    @Override
    public int draw(BaseDanmaku danmaku) {
        float top = danmaku.getTop();
        float left = danmaku.getLeft();
        if (canvas != null) {

            Paint alphaPaint = null;
            boolean needRestore = false;
            if (danmaku.getType() == BaseDanmaku.TYPE_SPECIAL) {
                if (danmaku.getAlpha() == AlphaValue.TRANSPARENT) {
                    return IRenderer.NOTHING_RENDERING;
                }
                if (danmaku.rotationZ != 0 || danmaku.rotationY != 0) {
                    saveCanvas(danmaku, canvas, left, top);
                    needRestore = true;
                }

                int alpha = danmaku.getAlpha();
                if (alpha != AlphaValue.MAX) {
                    alphaPaint = ALPHA_PAINT;
                    alphaPaint.setAlpha(danmaku.getAlpha());
                }
            }

            // skip drawing when danmaku is transparent
            if (alphaPaint != null && alphaPaint.getAlpha() == AlphaValue.TRANSPARENT) {
                return IRenderer.NOTHING_RENDERING;
            }
            // drawing cache
            boolean cacheDrawn = false;
            int result = IRenderer.CACHE_RENDERING;
            if (danmaku.hasDrawingCache()) {
                DrawingCacheHolder holder = ((DrawingCache) danmaku.cache).get();
                if (holder != null) {
                    cacheDrawn = holder.draw(canvas, left, top, alphaPaint);
                }
            }
            if (!cacheDrawn) {
                if (alphaPaint != null) {
                    PAINT.setAlpha(alphaPaint.getAlpha());
                } else {
                    resetPaintAlpha(PAINT);
                }
                drawDanmaku(danmaku, canvas, left, top, false);
                result = IRenderer.TEXT_RENDERING;
            }

            if (needRestore) {
                restoreCanvas(canvas);
            }

            return result;
        }

        return IRenderer.NOTHING_RENDERING;
    }

    private void resetPaintAlpha(Paint paint) {
        if (paint.getAlpha() != AlphaValue.MAX) {
            paint.setAlpha(AlphaValue.MAX);
        }
    }

    private void restoreCanvas(Canvas canvas) {
        canvas.restore();
    }

    private int saveCanvas(BaseDanmaku danmaku, Canvas canvas, float left, float top) {
        camera.save();
        camera.rotateY(-danmaku.rotationY);
        camera.rotateZ(-danmaku.rotationZ);
        camera.getMatrix(matrix);
        matrix.preTranslate(-left, -top);
        matrix.postTranslate(left, top);
        camera.restore();
        int count = canvas.save();
        canvas.concat(matrix);
        return count;
    }

    @Override
    public synchronized void drawDanmaku(BaseDanmaku danmaku, Canvas canvas, float left, float top,
                            boolean fromWorkerThread) {
        float _left = left;
        float _top = top;
        left += danmaku.padding;
        top += danmaku.padding;
        if (danmaku.borderColor != 0) {
            left += BORDER_WIDTH;
            top += BORDER_WIDTH;
        }

        HAS_STROKE = CONFIG_HAS_STROKE;
        HAS_SHADOW = CONFIG_HAS_SHADOW;
        HAS_PROJECTION = CONFIG_HAS_PROJECTION;
        ANTI_ALIAS = fromWorkerThread && CONFIG_ANTI_ALIAS;
        TextPaint paint = getPaint(danmaku, fromWorkerThread);
        sStuffer.drawBackground(danmaku, canvas, _left, _top);
        if (danmaku.lines != null) {
            String[] lines = danmaku.lines;
            if (lines.length == 1) {
                if (hasStroke(danmaku)) {
                    applyPaintConfig(danmaku, paint, true);
                    float strokeLeft = left;
                    float strokeTop = top - paint.ascent();
                    if (HAS_PROJECTION) {
                        strokeLeft += sProjectionOffsetX;
                        strokeTop += sProjectionOffsetY;
                    }
                    sStuffer.drawStroke(danmaku, lines[0], canvas, strokeLeft, strokeTop, paint);
                }
                applyPaintConfig(danmaku, paint, false);
                sStuffer.drawText(danmaku, lines[0], canvas, left, top - paint.ascent(), paint, fromWorkerThread);
            } else {
                float textHeight = (danmaku.paintHeight - 2 * danmaku.padding) / lines.length;
                for (int t = 0; t < lines.length; t++) {
                    if (lines[t] == null || lines[t].length() == 0) {
                        continue;
                    }
                    if (hasStroke(danmaku)) {
                        applyPaintConfig(danmaku, paint, true);
                        float strokeLeft = left;
                        float strokeTop = t * textHeight + top - paint.ascent();
                        if (HAS_PROJECTION) {
                            strokeLeft += sProjectionOffsetX;
                            strokeTop += sProjectionOffsetY;
                        }
                        sStuffer.drawStroke(danmaku, lines[t], canvas, strokeLeft, strokeTop, paint);
                    }
                    applyPaintConfig(danmaku, paint, false);
                    sStuffer.drawText(danmaku, lines[t], canvas, left, t * textHeight + top - paint.ascent(), paint, fromWorkerThread);
                }
            }
        } else {
            if (hasStroke(danmaku)) {
                applyPaintConfig(danmaku, paint, true);
                float strokeLeft = left;
                float strokeTop = top - paint.ascent();

                if (HAS_PROJECTION) {
                    strokeLeft += sProjectionOffsetX;
                    strokeTop += sProjectionOffsetY;
                }
                sStuffer.drawStroke(danmaku, null, canvas, strokeLeft, strokeTop, paint);
            }

            applyPaintConfig(danmaku, paint, false);
            sStuffer.drawText(danmaku, null, canvas, left, top - paint.ascent(), paint, fromWorkerThread);
        }

        // draw underline
        if (danmaku.underlineColor != 0) {
            Paint linePaint = getUnderlinePaint(danmaku);
            float bottom = _top + danmaku.paintHeight - UNDERLINE_HEIGHT;
            canvas.drawLine(_left, bottom, _left + danmaku.paintWidth, bottom, linePaint);
        }

        //draw border
        if (danmaku.borderColor != 0) {
            Paint borderPaint = getBorderPaint(danmaku);
            canvas.drawRect(_left, _top, _left + danmaku.paintWidth, _top + danmaku.paintHeight,
                    borderPaint);
        }

    }

    private boolean hasStroke(BaseDanmaku danmaku) {
        return (HAS_STROKE || HAS_PROJECTION) && STROKE_WIDTH > 0 && danmaku.textShadowColor != 0;
    }

    public Paint getBorderPaint(BaseDanmaku danmaku) {
        BORDER_PAINT.setColor(danmaku.borderColor);
        return BORDER_PAINT;
    }

    public Paint getUnderlinePaint(BaseDanmaku danmaku) {
        UNDERLINE_PAINT.setColor(danmaku.underlineColor);
        return UNDERLINE_PAINT;
    }

    private synchronized TextPaint getPaint(BaseDanmaku danmaku, boolean fromWorkerThread) {
        TextPaint paint;
        if (fromWorkerThread) {
            paint = PAINT;
        } else {
            paint = PAINT_DUPLICATE;
            paint.set(PAINT);
        }
        paint.setTextSize(danmaku.textSize);
        applyTextScaleConfig(danmaku, paint);

        //ignore the transparent textShadowColor
        if (!HAS_SHADOW || SHADOW_RADIUS <= 0 || danmaku.textShadowColor == 0) {
            paint.clearShadowLayer();
        } else {
            paint.setShadowLayer(SHADOW_RADIUS, 0, 0, danmaku.textShadowColor);
        }
        paint.setAntiAlias(ANTI_ALIAS);
        return paint;
    }

    private void applyPaintConfig(BaseDanmaku danmaku, Paint paint, boolean stroke) {

        if (isTranslucent) {
            if (stroke) {
                paint.setStyle(HAS_PROJECTION ? Style.FILL : Style.STROKE);
                paint.setColor(danmaku.textShadowColor & 0x00FFFFFF);
                int alpha = HAS_PROJECTION ? (int) (sProjectionAlpha * ((float) transparency / AlphaValue.MAX))
                        : transparency;
                paint.setAlpha(alpha);
            } else {
                paint.setStyle(Style.FILL);
                paint.setColor(danmaku.textColor & 0x00FFFFFF);
                paint.setAlpha(transparency);
            }
        } else {
            if (stroke) {
                paint.setStyle(HAS_PROJECTION ? Style.FILL : Style.STROKE);
                paint.setColor(danmaku.textShadowColor & 0x00FFFFFF);
                int alpha = HAS_PROJECTION ? sProjectionAlpha : AlphaValue.MAX;
                paint.setAlpha(alpha);
            } else {
                paint.setStyle(Style.FILL);
                paint.setColor(danmaku.textColor & 0x00FFFFFF);
                paint.setAlpha(AlphaValue.MAX);
            }
        }

    }

    private void applyTextScaleConfig(BaseDanmaku danmaku, Paint paint) {
        if (!isTextScaled) {
            return;
        }
        Float size = sCachedScaleSize.get(danmaku.textSize);
        if (size == null || sLastScaleTextSize != scaleTextSize) {
            sLastScaleTextSize = scaleTextSize;
            size = danmaku.textSize * scaleTextSize;
            sCachedScaleSize.put(danmaku.textSize, size);
        }
        paint.setTextSize(size);
    }

    @Override
    public void measure(BaseDanmaku danmaku, boolean fromWorkerThread) {
        TextPaint paint = getPaint(danmaku, fromWorkerThread);
        if (HAS_STROKE) {
            applyPaintConfig(danmaku, paint, true);
        }
        calcPaintWH(danmaku, paint, fromWorkerThread);
        if (HAS_STROKE) {
            applyPaintConfig(danmaku, paint, false);
        }
    }

    private void calcPaintWH(BaseDanmaku danmaku, TextPaint paint, boolean fromWorkerThread) {
        sStuffer.measure(danmaku, paint, fromWorkerThread);
        setDanmakuPaintWidthAndHeight(danmaku, danmaku.paintWidth, danmaku.paintHeight);
    }

    private void setDanmakuPaintWidthAndHeight(BaseDanmaku danmaku, float w, float h) {
        float pw = w + 2 * danmaku.padding;
        float ph = h + 2 * danmaku.padding;
        if (danmaku.borderColor != 0) {
            pw += 2 * BORDER_WIDTH;
            ph += 2 * BORDER_WIDTH;
        }
        danmaku.paintWidth = pw + getStrokeWidth();
        danmaku.paintHeight = ph;
    }

    @Override
    public void clearTextHeightCache() {
        sStuffer.clearCaches();
        sCachedScaleSize.clear();
    }

    @Override
    public float getScaledDensity() {
        return scaledDensity;
    }

    @Override
    public void resetSlopPixel(float factor) {
        float d = Math.max(factor, getWidth() / DanmakuFactory.BILI_PLAYER_WIDTH); //correct for low density and high resolution
        float slop = d * DanmakuFactory.DANMAKU_MEDIUM_TEXTSIZE;
        mSlopPixel = (int) slop;
        if (factor > 1f)
            mSlopPixel = (int) (slop * factor);
    }

    @Override
    public int getSlopPixel() {
        return mSlopPixel;
    }

    @Override
    public void setDensities(float density, int densityDpi, float scaledDensity) {
        this.density = density;
        this.densityDpi = densityDpi;
        this.scaledDensity = scaledDensity;
    }

    @Override
    public void setSize(int width, int height) {
        this.width = width;
        this.height = height;
    }

    @Override
    public void setDanmakuStyle(int style, float[] values) {
        switch (style) {
            case DANMAKU_STYLE_NONE:
                CONFIG_HAS_SHADOW = false;
                CONFIG_HAS_STROKE = false;
                CONFIG_HAS_PROJECTION = false;
                break;
            case DANMAKU_STYLE_SHADOW:
                CONFIG_HAS_SHADOW = true;
                CONFIG_HAS_STROKE = false;
                CONFIG_HAS_PROJECTION = false;
                setShadowRadius(values[0]);
                break;
            case DANMAKU_STYLE_DEFAULT:
            case DANMAKU_STYLE_STROKEN:
                CONFIG_HAS_SHADOW = false;
                CONFIG_HAS_STROKE = true;
                CONFIG_HAS_PROJECTION = false;
                setPaintStorkeWidth(values[0]);
                break;
            case DANMAKU_STYLE_PROJECTION:
                CONFIG_HAS_SHADOW = false;
                CONFIG_HAS_STROKE = false;
                CONFIG_HAS_PROJECTION = true;
                setProjectionConfig(values[0], values[1], (int) values[2]);
                break;
        }
    }

    @Override
    public void setExtraData(Canvas data) {
        update(data);
    }

    @Override
    public Canvas getExtraData() {
        return this.canvas;
    }

    @Override
    public float getStrokeWidth() {
        if (HAS_SHADOW && HAS_STROKE) {
            return Math.max(SHADOW_RADIUS, STROKE_WIDTH);
        }
        if (HAS_SHADOW) {
            return SHADOW_RADIUS;
        }
        if (HAS_STROKE) {
            return STROKE_WIDTH;
        }
        return 0f;
    }

    @Override
    public void setHardwareAccelerated(boolean enable) {
        mIsHardwareAccelerated = enable;
    }

    @Override
    public boolean isHardwareAccelerated() {
        return mIsHardwareAccelerated;
    }

    @Override
    public int getMaximumCacheWidth() {
        return mMaximumBitmapWidth;
    }

    @Override
    public int getMaximumCacheHeight() {
        return mMaximumBitmapHeight;
    }


}
