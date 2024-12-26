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

package com.bgylde.live.danmaku.renderer.android;

import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.model.DanmakuTimer;
import com.bgylde.live.danmaku.model.ICacheManager;
import com.bgylde.live.danmaku.model.IDanmakuIterator;
import com.bgylde.live.danmaku.model.IDanmakus;
import com.bgylde.live.danmaku.model.IDisplayer;
import com.bgylde.live.danmaku.model.android.DanmakuContext;
import com.bgylde.live.danmaku.renderer.IRenderer;
import com.bgylde.live.danmaku.renderer.Renderer;
import com.bgylde.live.danmaku.util.SystemClock;


public class DanmakuRenderer extends Renderer {

    private final DanmakuTimer mStartTimer = new DanmakuTimer();
    private final RenderingState mRenderingState = new RenderingState();
    private final DanmakuContext mContext;
    private DanmakusRetainer.Verifier mVerifier;
    private final DanmakusRetainer.Verifier verifier = new DanmakusRetainer.Verifier() {
        @Override
        public boolean skipLayout(BaseDanmaku danmaku, float fixedTop, int lines, boolean willHit) {
            if (danmaku.priority == 0 && mContext.mDanmakuFilters.filterSecondary(danmaku, lines, 0, mStartTimer, willHit, mContext)) {
                danmaku.setVisibility(false);
                return true;
            }
            return false;
        }
    };
    private final DanmakusRetainer mDanmakusRetainer;
    private ICacheManager mCacheManager;
    private OnDanmakuShownListener mOnDanmakuShownListener;

    public DanmakuRenderer(DanmakuContext config) {
        mContext = config;
        mDanmakusRetainer = new DanmakusRetainer();
    }

    @Override
    public void clear() {
        clearRetainer();
        mContext.mDanmakuFilters.clear();
    }

    @Override
    public void clearRetainer() {
        mDanmakusRetainer.clear();
    }

    @Override
    public void release() {
        mDanmakusRetainer.release();
        mContext.mDanmakuFilters.clear();
    }

    @Override
    public void setVerifierEnabled(boolean enabled) {
        mVerifier = (enabled ? verifier : null);
    }

    @Override
    public RenderingState draw(IDisplayer disp, IDanmakus danmakus, long startRenderTime) {
        int lastTotalDanmakuCount = mRenderingState.totalDanmakuCount;
        mRenderingState.reset();       
        IDanmakuIterator itr = danmakus.iterator();
        int orderInScreen = 0;        
        mStartTimer.update(SystemClock.uptimeMillis());
        int sizeInScreen = danmakus.size();
        BaseDanmaku drawItem = null;
        while (itr.hasNext()) {

            drawItem = itr.next();

            if (!drawItem.hasPassedFilter()) {
                mContext.mDanmakuFilters.filter(drawItem, orderInScreen, sizeInScreen, mStartTimer, false, mContext);
            }

            if (drawItem.time < startRenderTime
                    || (drawItem.priority == 0 && drawItem.isFiltered())) {
                continue;
            }

            if (drawItem.isLate()) {
                if (mCacheManager != null && !drawItem.hasDrawingCache()) {
                    mCacheManager.addDanmaku(drawItem);
                }
                break;
            }
            
            if (drawItem.getType() == BaseDanmaku.TYPE_SCROLL_RL){
                // 同屏弹幕密度只对滚动弹幕有效
                orderInScreen++;
            }

            // measure
            if (!drawItem.isMeasured()) {
                drawItem.measure(disp, false);
            }

            // layout
            mDanmakusRetainer.fix(drawItem, disp, mVerifier);

            // draw
            if (!drawItem.isOutside() && drawItem.isShown()) {
                if (drawItem.lines == null && drawItem.getBottom() > disp.getHeight()) {
                    continue;    // skip bottom outside danmaku
                }
                int renderingType = drawItem.draw(disp);
                if(renderingType == IRenderer.CACHE_RENDERING) {
                    mRenderingState.cacheHitCount++;
                } else if(renderingType == IRenderer.TEXT_RENDERING) {
                    mRenderingState.cacheMissCount++;
                    if (mCacheManager != null) {
                        mCacheManager.addDanmaku(drawItem);
                    }
                }
                mRenderingState.addCount(drawItem.getType(), 1);
                mRenderingState.addTotalCount(1);

                if (mOnDanmakuShownListener != null
                        && drawItem.firstShownFlag != mContext.mGlobalFlagValues.FIRST_SHOWN_RESET_FLAG) {
                    drawItem.firstShownFlag = mContext.mGlobalFlagValues.FIRST_SHOWN_RESET_FLAG;
                    mOnDanmakuShownListener.onDanmakuShown(drawItem);
                }
            }

        }
        
        mRenderingState.nothingRendered = (mRenderingState.totalDanmakuCount == 0);
        mRenderingState.endTime = drawItem != null ? drawItem.time : RenderingState.UNKNOWN_TIME;
        if (mRenderingState.nothingRendered) {
            mRenderingState.beginTime = RenderingState.UNKNOWN_TIME;
        }
        mRenderingState.incrementCount = mRenderingState.totalDanmakuCount - lastTotalDanmakuCount;
        mRenderingState.consumingTime = mStartTimer.update(SystemClock.uptimeMillis());
        return mRenderingState;
    }

    public void setCacheManager(ICacheManager cacheManager) {
        mCacheManager = cacheManager;
    }

    @Override
    public void setOnDanmakuShownListener(OnDanmakuShownListener onDanmakuShownListener) {
        mOnDanmakuShownListener = onDanmakuShownListener;
    }

    @Override
    public void removeOnDanmakuShownListener() {
        mOnDanmakuShownListener = null;
    }
}
