package com.xycz.simple_live_tv.core;

import android.util.Log;

/**
 * Created by wangyan on 2020-07-24
 */
public class LogUtils {
    private static boolean isShowLog = true;
    private static final String DEFAULT_TAG = "Live";

    public static void i(String tag, String message) {
        if (isShowLog) {
            Log.i(DEFAULT_TAG, tag + " [" + message + "]");
        }
    }

    public static void i(String message) {
        if (isShowLog) {
            Log.i(DEFAULT_TAG, message);
        }
    }

    public static void d(String tag, String message) {
        if (isShowLog) {
            Log.w(DEFAULT_TAG, tag + " [" + message + "]");
        }
    }

    public static void d(String message) {
        if (isShowLog) {
            Log.w(DEFAULT_TAG, message);
        }
    }

    public static void w(String tag, String message) {
        if (isShowLog) {
            Log.w(DEFAULT_TAG, tag + " [" + message + "]");
        }
    }

    public static void w(String message) {
        if (isShowLog) {
            Log.w(DEFAULT_TAG, message);
        }
    }

    public static void e(String tag, String message, Throwable e) {
        if (isShowLog) {
            Log.e(DEFAULT_TAG, tag + " [" + message + "]", e);
        }
    }

    public static void e(String tag, Throwable e) {
        if (isShowLog) {
            Log.e(DEFAULT_TAG, tag + " [" + Log.getStackTraceString(e) + "]");
        }
    }

    public static void setDebug(boolean isDebug) {
        isShowLog = isDebug;
    }

    public static boolean isDebug() {
        return isShowLog;
    }

    public static void showLog(String tag, String msg) throws StringIndexOutOfBoundsException {
        msg = msg.trim();
        int var2 = 0;
        short var3 = 4000;

        while(var2 < msg.length()) {
            String var4;
            if (msg.length() <= var2 + var3) {
                var4 = msg.substring(var2);
            } else {
                var4 = msg.substring(var2, var2 + var3);
            }

            var2 += var3;
            Log.i(tag, var4.trim());
        }
    }
}
