
package com.bgylde.live.danmaku.util;

import android.app.ActivityManager;
import android.content.Context;

public class AndroidUtils {

    public static int getMemoryClass(final Context context) {
        return ((ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE))
                .getMemoryClass();
    }
}
