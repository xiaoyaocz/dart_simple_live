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

package com.bgylde.live.danmaku.flame.util;

import android.text.TextUtils;

import com.bgylde.live.danmaku.flame.model.AbsDisplayer;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.IDisplayer;
import com.bgylde.live.danmaku.flame.model.android.DrawingCache;
import com.bgylde.live.danmaku.flame.model.android.DrawingCacheHolder;

public class DanmakuUtils {

    /**
     * 检测两个弹幕是否会碰撞
     * 允许不同类型弹幕的碰撞
     * @param d1
     * @param d2
     * @return
     */
    public static boolean willHitInDuration(IDisplayer disp, BaseDanmaku d1, BaseDanmaku d2,
                                            long duration, long currTime) {
        final int type1 = d1.getType();
        final int type2 = d2.getType();
        // allow hit if different type
        if(type1 != type2)
            return false;
        
        if(d1.isOutside()){
            return false;
        }
        long dTime = d2.time - d1.time;
        if (dTime <= 0)
            return true;
        if (Math.abs(dTime) >= duration || d1.isTimeOut() || d2.isTimeOut()) {
            return false;
        }

        if (type1 == BaseDanmaku.TYPE_FIX_TOP || type1 == BaseDanmaku.TYPE_FIX_BOTTOM) {
            return true;
        }

        return checkHitAtTime(disp, d1, d2, currTime) 
                || checkHitAtTime(disp, d1, d2,  d1.time + d1.getDuration());
    }
    
    private static boolean checkHitAtTime(IDisplayer disp, BaseDanmaku d1, BaseDanmaku d2, long time){
        final float[] rectArr1 = d1.getRectAtTime(disp, time);
        final float[] rectArr2 = d2.getRectAtTime(disp, time);
        if (rectArr1 == null || rectArr2 == null)
            return false;
        return checkHit(d1.getType(), d2.getType(), rectArr1, rectArr2);
    }
    
    private static boolean checkHit(int type1, int type2, float[] rectArr1,
            float[] rectArr2) {
        if(type1 != type2)
            return false;
        if (type1 == BaseDanmaku.TYPE_SCROLL_RL) {
            // hit if left2 < right1
            return rectArr2[0] < rectArr1[2];
        }
        
        if (type1 == BaseDanmaku.TYPE_SCROLL_LR){
            // hit if right2 > left1
            return rectArr2[2] > rectArr1[0];
        }
        
        return false;
    }

    public static DrawingCache buildDanmakuDrawingCache(BaseDanmaku danmaku, IDisplayer disp,
                                                        DrawingCache cache) {
        if (cache == null)
            cache = new DrawingCache();

        cache.build((int) Math.ceil(danmaku.paintWidth), (int) Math.ceil(danmaku.paintHeight), disp.getDensityDpi(), false);
        DrawingCacheHolder holder = cache.get();
        if (holder != null) {
            ((AbsDisplayer) disp).drawDanmaku(danmaku, holder.canvas, 0, 0, true);
            if(disp.isHardwareAccelerated()) {
                holder.splitWith(disp.getWidth(), disp.getHeight(), disp.getMaximumCacheWidth(),
                        disp.getMaximumCacheHeight());
            }
        }
        return cache;
    }

    public static int getCacheSize(int w, int h) {
        return (w) * (h) * 4;
    }
    
    public final static boolean isDuplicate(BaseDanmaku obj1, BaseDanmaku obj2) {
        if(obj1 == obj2) {
            return false;
        }
//        if(obj1.isTimeOut() || obj2.isTimeOut()) {
//            return false;
//        }
//        long dtime = Math.abs(obj1.time - obj2.time);
//        if(dtime > obj1.getDuration()) {
//            return false;
//        }
        if (obj1.text == obj2.text) {
            return true;
        }
        if (obj1.text != null && obj1.text.equals(obj2.text)) {
            return true;
        }
        return false;
    }

    public final static int compare(BaseDanmaku obj1, BaseDanmaku obj2) {
        
        if (obj1 == obj2) {
            return 0;
        }

        if (obj1 == null) {
            return -1;
        }

        if (obj2 == null) {
            return 1;
        }

        long val = obj1.time - obj2.time;
        if (val > 0) {
            return 1;
        } else if (val < 0) {
            return -1;
        }
        
        int result = obj1.index - obj2.index;
        if (result > 0) {
            return 1;
        } else if (result < 0) {
            return -1;
        }

        result = obj1.getType() - obj2.getType();
        if (result > 0) {
            return 1;
        } else if (result < 0) {
            return -1;
        }

        if (obj1.text == null) {
            return -1;
        }
        if (obj2.text == null) {
            return 1;
        }

        int r = obj1.text.toString().compareTo(obj2.text.toString());
        if (r != 0) {
            return r;
        }

        r = obj1.textColor - obj2.textColor;
        if (r != 0)
            return r < 0 ? -1 : 1;

        r = obj1.index - obj2.index;
        if (r != 0)
            return r < 0 ? -1 : 1;

        r = obj1.hashCode() - obj1.hashCode();
        return r;
    }

    public final static boolean isOverSize(IDisplayer disp, BaseDanmaku item) {
        return disp.isHardwareAccelerated() && (item.paintWidth > disp.getMaximumCacheWidth() || item.paintHeight > disp.getMaximumCacheHeight());
    }

    public static void fillText(BaseDanmaku danmaku, CharSequence text) {
        danmaku.text = text;
        if (TextUtils.isEmpty(text) || !text.toString().contains(BaseDanmaku.DANMAKU_BR_CHAR)) {
            return;
        }

        String[] lines = String.valueOf(danmaku.text).split(BaseDanmaku.DANMAKU_BR_CHAR, -1);
        if (lines.length > 1) {
            danmaku.lines = lines;
        }
    }
}
