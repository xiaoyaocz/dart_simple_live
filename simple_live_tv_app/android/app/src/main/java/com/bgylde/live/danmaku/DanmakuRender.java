package com.bgylde.live.danmaku;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.text.TextPaint;

import androidx.annotation.NonNull;

import com.kuaishou.akdanmaku.DanmakuConfig;
import com.kuaishou.akdanmaku.data.DanmakuItem;
import com.kuaishou.akdanmaku.data.DanmakuItemData;
import com.kuaishou.akdanmaku.render.DanmakuRenderer;
import com.kuaishou.akdanmaku.ui.DanmakuDisplayer;
import com.kuaishou.akdanmaku.utils.Size;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by wangyan on 2024/12/28
 */
public class DanmakuRender implements DanmakuRenderer {

    private static final int DEFAULT_DARK_COLOR = Color.argb(255, 34, 34, 34);
    private static final int CANVAS_PADDING = 6;
    private final Map<Float, Float> textHeightCache = new HashMap<>();

    private final TextPaint textPaint = new TextPaint();

    private final TextPaint strokePaint = new TextPaint();

    public DanmakuRender() {
        strokePaint.setStyle(Paint.Style.STROKE);
    }

    public void setStrokeWidth(int width) {
        strokePaint.setStrokeWidth(width);
    }

    @Override
    public void draw(@NonNull DanmakuItem danmakuItem, @NonNull Canvas canvas, @NonNull DanmakuDisplayer danmakuDisplayer, @NonNull DanmakuConfig danmakuConfig) {
        updatePaint(danmakuItem, danmakuDisplayer, danmakuConfig);
        DanmakuItemData danmakuItemData = danmakuItem.getData();
        float x = CANVAS_PADDING * 0.5f;
        float y = CANVAS_PADDING * 0.5f - textPaint.ascent();
        if (strokePaint.getStrokeWidth() > 0) {
            canvas.drawText(danmakuItemData.getContent(), x, y, strokePaint);
        }

        canvas.drawText(danmakuItemData.getContent(), x, y, textPaint);
    }

    @Override
    public void updatePaint(@NonNull DanmakuItem danmakuItem, @NonNull DanmakuDisplayer danmakuDisplayer, @NonNull DanmakuConfig danmakuConfig) {
        DanmakuItemData danmakuItemData = danmakuItem.getData();
        // update textPaint
        float textSize = danmakuItemData.getTextSize() * 2.0f;
        textPaint.setTextSize(textSize * danmakuConfig.getTextSizeScale());
        textPaint.setTypeface(danmakuConfig.getBold() ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
        textPaint.setColor(danmakuItemData.getTextColor());
        // update strokePaint
        strokePaint.setTextSize(textPaint.getTextSize());
        strokePaint.setTypeface(textPaint.getTypeface());
        strokePaint.setColor(textPaint.getColor() == DEFAULT_DARK_COLOR ? Color.WHITE : Color.BLACK);
    }

    @NonNull
    @Override
    public Size measure(@NonNull DanmakuItem danmakuItem, @NonNull DanmakuDisplayer danmakuDisplayer, @NonNull DanmakuConfig danmakuConfig) {
        updatePaint(danmakuItem, danmakuDisplayer, danmakuConfig);
        DanmakuItemData danmakuItemData = danmakuItem.getData();
        float textWidth = textPaint.measureText(danmakuItemData.getContent());
        float textHeight = getCacheHeight(textPaint);
        return new Size((int)textWidth + CANVAS_PADDING, (int)textHeight + CANVAS_PADDING);
    }

    private float getCacheHeight(Paint paint) {
        float textSize = paint.getTextSize();
        Float textHeight = textHeightCache.get(textSize);
        if (textHeight != null) {
            return textHeight;
        }

        Paint.FontMetrics fontMetrics = paint.getFontMetrics();
        textHeight = fontMetrics.descent - fontMetrics.ascent + fontMetrics.leading;
        textHeightCache.put(textSize, textHeight);
        return textHeight;
    }
}
