package com.bgylde.live.danmaku.flame.util;

/**
 * Created by ch on 15-12-9.
 */
public class SystemClock {
    public static final long uptimeMillis() {
        return android.os.SystemClock.elapsedRealtime();
    }

    public static final void sleep(long mills) {
        android.os.SystemClock.sleep(mills);
    }
}
