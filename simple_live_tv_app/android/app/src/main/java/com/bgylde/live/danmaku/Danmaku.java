package com.bgylde.live.danmaku;

import android.graphics.Color;

import androidx.annotation.ColorInt;

/**
 * Created by LittleFogCat.
 */

public class Danmaku {
    public static final int COLOR_WHITE = 0xFFFFFFFF;

    public static final int DEFAULT_TEXT_SIZE = 24;

    public String text;// 文字
    public int size = DEFAULT_TEXT_SIZE;// 字号
    public Mode mode = Mode.scroll;// 模式：滚动、顶部、底部
    @ColorInt
    public int color = COLOR_WHITE;// 默认白色

    // 描边颜色
    public int strokeColor = Color.BLACK;
    // 描边宽度
    public int strokeWidth = 1;

    public enum Mode {
        scroll, top, bottom
    }

    public Danmaku() {
    }

    public Danmaku(String text, int textSize, Mode mode, int color) {
        this.text = text;
        this.size = textSize;
        this.mode = mode;
        this.color = color;
    }

    @Override
    public String toString() {
        return "Danmaku{" +
                "text='" + text + '\'' +
                ", textSize=" + size +
                ", mode=" + mode +
                ", color='" + color + '\'' +
                '}';
    }
}
