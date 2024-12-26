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

package com.bgylde.live.danmaku.flame.model.android;

import com.bgylde.live.danmaku.flame.model.FTDanmaku;
import com.bgylde.live.danmaku.flame.model.L2RDanmaku;
import com.bgylde.live.danmaku.flame.model.R2LDanmaku;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.Duration;
import com.bgylde.live.danmaku.flame.model.FBDanmaku;
import com.bgylde.live.danmaku.flame.model.IDanmakuIterator;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.model.IDisplayer;
import com.bgylde.live.danmaku.flame.model.SpecialDanmaku;
import com.bgylde.live.danmaku.flame.model.SpecialDanmaku.LinePath;

public class DanmakuFactory {

    public final static float OLD_BILI_PLAYER_WIDTH = 539;
    
    public final static float BILI_PLAYER_WIDTH = 682;

    public final static float OLD_BILI_PLAYER_HEIGHT = 385;

    public final static float BILI_PLAYER_HEIGHT = 438;

    public final static long COMMON_DANMAKU_DURATION = 3800; // B站原始分辨率下弹幕存活时间

    public final static int DANMAKU_MEDIUM_TEXTSIZE = 25;

    public final static long MIN_DANMAKU_DURATION = 4000;

    public final static long MAX_DANMAKU_DURATION_HIGH_DENSITY = 9000;

    public int CURRENT_DISP_WIDTH = 0, CURRENT_DISP_HEIGHT = 0;
    
    private float CURRENT_DISP_SIZE_FACTOR = 1.0f;

    public long REAL_DANMAKU_DURATION = COMMON_DANMAKU_DURATION;

    public long MAX_DANMAKU_DURATION = MIN_DANMAKU_DURATION;
    
    public Duration MAX_Duration_Scroll_Danmaku;
    
    public Duration MAX_Duration_Fix_Danmaku;
    
    public Duration MAX_Duration_Special_Danmaku;
    
    public IDanmakus sSpecialDanmakus = new Danmakus();

    public IDisplayer sLastDisp;
    private DanmakuContext sLastConfig;

    static DanmakuFactory create() {
        return new DanmakuFactory();
    }

    protected DanmakuFactory() {

    }

    public void resetDurationsData() {
        sLastDisp = null;
        CURRENT_DISP_WIDTH = CURRENT_DISP_HEIGHT = 0;
        sSpecialDanmakus.clear();
        MAX_Duration_Scroll_Danmaku = null;
        MAX_Duration_Fix_Danmaku = null;
        MAX_Duration_Special_Danmaku = null;
        MAX_DANMAKU_DURATION = MIN_DANMAKU_DURATION;
    }
    
    public void notifyDispSizeChanged(DanmakuContext context) {
        sLastConfig = context;
        sLastDisp = context.getDisplayer();
        createDanmaku(BaseDanmaku.TYPE_SCROLL_RL, context);
    }
    
    public BaseDanmaku createDanmaku(int type) {
        return createDanmaku(type, sLastConfig);
    }

    public BaseDanmaku createDanmaku(int type, DanmakuContext context) {
        if (context == null)
            return null;
        sLastConfig = context;
        sLastDisp = context.getDisplayer();
        return createDanmaku(type, sLastDisp.getWidth(), sLastDisp.getHeight(), CURRENT_DISP_SIZE_FACTOR, context.scrollSpeedFactor);
    }
    
    public BaseDanmaku createDanmaku(int type, IDisplayer disp, float viewportScale, float scrollSpeedFactor) {
        if (disp == null)
            return null;
        sLastDisp = disp;
        return createDanmaku(type, disp.getWidth(), disp.getHeight(), viewportScale, scrollSpeedFactor);
    } 
    
    /**
     * 创建弹幕数据请尽量使用此方法,参考BiliDanmakuParser或AcfunDanmakuParser
     * @param type 弹幕类型
     * @param viewportWidth danmakuview宽度,会影响滚动弹幕的存活时间(duration)
     * @param viewportHeight danmakuview高度
     * @param viewportScale 缩放比例,会影响滚动弹幕的存活时间(duration)
     * @return
     */
    public BaseDanmaku createDanmaku(int type, int viewportWidth, int viewportHeight,
            float viewportScale, float scrollSpeedFactor) {
        return createDanmaku(type, (float) viewportWidth, (float) viewportHeight, viewportScale, scrollSpeedFactor);
    }
    
    /**
     * 创建弹幕数据请尽量使用此方法,参考BiliDanmakuParser或AcfunDanmakuParser
     * @param type 弹幕类型
     * @param viewportWidth danmakuview宽度,会影响滚动弹幕的存活时间(duration)
     * @param viewportHeight danmakuview高度
     * @param viewportSizeFactor 会影响滚动弹幕的速度/存活时间(duration)
     * @return
     */
    public BaseDanmaku createDanmaku(int type, float viewportWidth, float viewportHeight,
            float viewportSizeFactor, float scrollSpeedFactor) {
        int oldDispWidth = CURRENT_DISP_WIDTH;
        int oldDispHeight = CURRENT_DISP_HEIGHT;
        boolean sizeChanged = updateViewportState(viewportWidth, viewportHeight, viewportSizeFactor);
        if (MAX_Duration_Scroll_Danmaku == null) {
            MAX_Duration_Scroll_Danmaku = new Duration(REAL_DANMAKU_DURATION);
            MAX_Duration_Scroll_Danmaku.setFactor(scrollSpeedFactor);
        } else if (sizeChanged) {
            MAX_Duration_Scroll_Danmaku.setValue(REAL_DANMAKU_DURATION);
        }

        if (MAX_Duration_Fix_Danmaku == null) {
            MAX_Duration_Fix_Danmaku = new Duration(COMMON_DANMAKU_DURATION);
        }

        if (sizeChanged && viewportWidth > 0) {
            updateMaxDanmakuDuration();
            float scaleX = 1f;
            float scaleY = 1f;
            if (oldDispWidth > 0 && oldDispHeight > 0) {
                scaleX = viewportWidth / (float) oldDispWidth;
                scaleY = viewportHeight / (float) oldDispHeight;
            }
            if (viewportHeight > 0) {
                updateSpecialDanmakusDate(scaleX, scaleY);
            }
        }

        BaseDanmaku instance = null;
        switch (type) {
            case 1: // 从右往左滚动
                instance = new R2LDanmaku(MAX_Duration_Scroll_Danmaku);
                break;
            case 4: // 底端固定
                instance = new FBDanmaku(MAX_Duration_Fix_Danmaku);
                break;
            case 5: // 顶端固定
                instance = new FTDanmaku(MAX_Duration_Fix_Danmaku);
                break;
            case 6: // 从左往右滚动
                instance = new L2RDanmaku(MAX_Duration_Scroll_Danmaku);
                break;
            case 7: // 特殊弹幕
                instance = new SpecialDanmaku();
                sSpecialDanmakus.addItem(instance);
                break;
        }
        return instance;
    }
    
    public boolean updateViewportState(float viewportWidth, float viewportHeight,
            float viewportSizeFactor) {
        boolean sizeChanged = false;
        if (CURRENT_DISP_WIDTH != (int) viewportWidth
                || CURRENT_DISP_HEIGHT != (int) viewportHeight
                || CURRENT_DISP_SIZE_FACTOR != viewportSizeFactor) {
            sizeChanged = true;
            REAL_DANMAKU_DURATION = (long) (COMMON_DANMAKU_DURATION * (viewportSizeFactor
                    * viewportWidth / BILI_PLAYER_WIDTH));
            REAL_DANMAKU_DURATION = Math.min(MAX_DANMAKU_DURATION_HIGH_DENSITY,
                    REAL_DANMAKU_DURATION);
            REAL_DANMAKU_DURATION = Math.max(MIN_DANMAKU_DURATION, REAL_DANMAKU_DURATION);
            
            CURRENT_DISP_WIDTH = (int) viewportWidth;
            CURRENT_DISP_HEIGHT = (int) viewportHeight;
            CURRENT_DISP_SIZE_FACTOR = viewportSizeFactor;
        }
        return sizeChanged;
    }

    private void updateSpecialDanmakusDate(float scaleX, float scaleY) {
        IDanmakus list = sSpecialDanmakus;
        IDanmakuIterator it = list.iterator();
        while (it.hasNext()) {
            SpecialDanmaku speicalDanmaku = (SpecialDanmaku) it.next();
            fillTranslationData(speicalDanmaku, speicalDanmaku.beginX, speicalDanmaku.beginY,
                    speicalDanmaku.endX, speicalDanmaku.endY, speicalDanmaku.translationDuration,
                    speicalDanmaku.translationStartDelay, scaleX, scaleY);
            LinePath[] linePaths = speicalDanmaku.linePaths;
            if (linePaths != null && linePaths.length > 0) {
                int length = linePaths.length;
                float[][] points = new float[length + 1][2];
                for (int j = 0; j < length; j++) {
                    points[j] = linePaths[j].getBeginPoint();
                    points[j + 1] = linePaths[j].getEndPoint();
                }
                fillLinePathData(speicalDanmaku, points, scaleX, scaleY);
            }
        }
    }

    public void updateMaxDanmakuDuration() {
        long maxScrollDuration = (MAX_Duration_Scroll_Danmaku == null ? 0: MAX_Duration_Scroll_Danmaku.value), 
              maxFixDuration = (MAX_Duration_Fix_Danmaku == null ? 0 : MAX_Duration_Fix_Danmaku.value), 
              maxSpecialDuration = (MAX_Duration_Special_Danmaku == null ? 0: MAX_Duration_Special_Danmaku.value);

        MAX_DANMAKU_DURATION = Math.max(maxScrollDuration, maxFixDuration);
        MAX_DANMAKU_DURATION = Math.max(MAX_DANMAKU_DURATION, maxSpecialDuration);

        MAX_DANMAKU_DURATION = Math.max(COMMON_DANMAKU_DURATION, MAX_DANMAKU_DURATION);
        MAX_DANMAKU_DURATION = Math.max(REAL_DANMAKU_DURATION, MAX_DANMAKU_DURATION);
    }
    
    public void updateDurationFactor(float f) {
        if (MAX_Duration_Scroll_Danmaku == null || MAX_Duration_Fix_Danmaku == null)
            return;
        MAX_Duration_Scroll_Danmaku.setFactor(f);
        updateMaxDanmakuDuration();
    }

    /**
     * Initial translation data of the special danmaku
     * 
     * @param item
     * @param beginX
     * @param beginX
     * @param beginY
     * @param endX
     * @param endY
     * @param translationDuration
     * @param translationStartDelay
     */
    public void fillTranslationData(BaseDanmaku item, float beginX, float beginY,
            float endX, float endY, long translationDuration, long translationStartDelay,
            float scaleX, float scaleY) {
        if (item.getType() != BaseDanmaku.TYPE_SPECIAL)
            return;
        ((SpecialDanmaku) item).setTranslationData(beginX * scaleX, beginY * scaleY, endX * scaleX,
                endY * scaleY, translationDuration, translationStartDelay);
        updateSpecicalDanmakuDuration(item);
    }
    
    public static void fillLinePathData(BaseDanmaku item, float[][] points, float scaleX,
            float scaleY) {
        if (item.getType() != BaseDanmaku.TYPE_SPECIAL || points.length == 0
                || points[0].length != 2)
            return;
        for (int i = 0; i < points.length; i++) {
            points[i][0] *= scaleX;
            points[i][1] *= scaleY;
        }
        ((SpecialDanmaku) item).setLinePathData(points);
    }

    /**
     * Initial alpha data of the special danmaku
     * 
     * @param item
     * @param beginAlpha
     * @param endAlpha
     * @param alphaDuraion
     */
    public void fillAlphaData(BaseDanmaku item, int beginAlpha, int endAlpha,
            long alphaDuraion) {
        if (item.getType() != BaseDanmaku.TYPE_SPECIAL)
            return;
        ((SpecialDanmaku) item).setAlphaData(beginAlpha, endAlpha, alphaDuraion);
        updateSpecicalDanmakuDuration(item);
    }
    
    private void updateSpecicalDanmakuDuration(BaseDanmaku item) {
        if (MAX_Duration_Special_Danmaku == null || (item.duration != null && item.duration.value > MAX_Duration_Special_Danmaku.value)) {
            MAX_Duration_Special_Danmaku = item.duration;
            updateMaxDanmakuDuration();
        }
    }

}
