package com.bgylde.live.danmaku;

import android.content.Context;
import android.util.DisplayMetrics;

/**
 * Created by LittleFogCat.
 * <p>
 * 自动适配屏幕像素的工具类。
 * 需要先调用{@link ScreenUtil#init(Context)}才能正常使用。如果屏幕旋转，
 * 那么需要再次调用{@link ScreenUtil#init(Context)}以更新。
 */

@SuppressWarnings({"unused", "WeakerAccess", "SuspiciousNameCombination"})
public class ScreenUtil {
    private static final String TAG = "ScreenUtil";
    /**
     * 屏幕宽度，在调用init()之后通过{@link ScreenUtil#getScreenWidth()}获取
     */
    private static int sScreenWidth = 1920;

    /**
     * 屏幕高度，在调用init()之后通过{@link ScreenUtil#getScreenHeight()} ()}获取
     */
    private static int sScreenHeight = 1080;

    /**
     * 设计宽度。用于{@link ScreenUtil#autoWidth(int)}
     */
    private static int sDesignWidth = 1080;

    /**
     * 设计高度。用于{@link ScreenUtil#autoHeight(int)} (int)}
     */
    private static int sDesignHeight = 1920;

    /**
     * 初始化ScreenUtil。在屏幕旋转之后，需要再次调用这个方法，否则计算将会出错。
     */
    public static void init(Context context) {
        DisplayMetrics m = context.getResources().getDisplayMetrics();

        sScreenWidth = m.widthPixels;
        sScreenHeight = m.heightPixels;

        if (sDesignWidth > sDesignHeight != sScreenWidth > sScreenHeight) {
            int tmp = sDesignWidth;
            sDesignWidth = sDesignHeight;
            sDesignHeight = tmp;
        }
    }

    public static void setDesignWidthAndHeight(int width, int height) {
        sDesignWidth = width;
        sDesignHeight = height;
    }

    /**
     * 根据实际屏幕和设计图的比例，自动缩放像素大小。
     * <p>
     * 例如设计图大小是1920像素x1080像素，实际屏幕是2560像素x1440像素，那么对于一个设计图中100x100像素的方形，
     * 实际屏幕中将会缩放为133像素x133像素。这有可能导致图形的失真（当实际的横竖比和设计图不同时）
     *
     * @param origin 设计图上的像素大小
     * @return 实际屏幕中的尺寸
     */
    public static int autoSize(int origin) {
        return autoWidth(origin);
    }

    /**
     * 对于在横屏和竖屏下尺寸不同的物体，分别给出设计图的像素，返回实际屏幕中应有的像素。
     *
     * @param land 在横屏设计图中的像素大小
     * @param port 在竖屏设计图中的像素大小
     */
    public static int autoSize(int land, int port) {
        return isPortrait() ? autoSize(port) : autoSize(land);
    }

    /**
     * 根据屏幕分辨率自适应宽度。
     *
     * @param origin 设计图中的宽度，像素
     * @return 实际屏幕中的宽度，像素
     */
    public static int autoWidth(int origin) {
        if (sScreenWidth == 0 || sDesignWidth == 0) {
            return origin;
        }
        int autoSize = origin * sScreenWidth / sDesignWidth;
        if (origin != 0 && autoSize == 0) {
            return 1;
        }
        return autoSize;
    }

    /**
     * 根据屏幕分辨率自适应高度
     *
     * @param origin 设计图中的高度，像素
     * @return 实际屏幕中的高度，像素
     */
    public static int autoHeight(int origin) {
        if (sScreenHeight == 0 || sDesignHeight == 0) {
            return origin;
        }
        int auto = origin * sScreenHeight / sDesignHeight;
        if (origin != 0 && auto == 0) {
            return 1;
        }
        return auto;
    }

    public static int getScreenWidth() {
        return sScreenWidth;
    }

    public static void setScreenWidth(int w) {
        sScreenWidth = w;
    }

    public static int getScreenHeight() {
        return sScreenHeight;
    }

    public static void setScreenHeight(int h) {
        sScreenHeight = h;
    }

    /**
     * 是否是竖屏
     */
    public static boolean isPortrait() {
        return getScreenHeight() > getScreenWidth();
    }
}
