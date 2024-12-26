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

package com.bgylde.live.danmaku.flame.controller;

import android.graphics.Canvas;

import com.bgylde.live.danmaku.flame.model.AbsDisplayer;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.DanmakuTimer;
import com.bgylde.live.danmaku.flame.model.IDanmakuIterator;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.model.android.DanmakuContext;
import com.bgylde.live.danmaku.flame.model.android.Danmakus;
import com.bgylde.live.danmaku.flame.renderer.IRenderer;
import com.bgylde.live.danmaku.flame.renderer.android.DanmakuRenderer;
import com.bgylde.live.danmaku.flame.parser.BaseDanmakuParser;
import com.bgylde.live.danmaku.flame.util.SystemClock;

public class DrawTask implements IDrawTask {

    protected final DanmakuContext mContext;
    
    protected final AbsDisplayer mDisp;

    protected IDanmakus danmakuList;

    protected BaseDanmakuParser mParser;

    TaskListener mTaskListener;

    final IRenderer mRenderer;

    DanmakuTimer mTimer;

    private IDanmakus danmakus = new Danmakus(Danmakus.ST_BY_LIST);

    protected boolean clearRetainerFlag;

    private long mStartRenderTime = 0;

    private IRenderer.RenderingState mRenderingState = new IRenderer.RenderingState();

    protected boolean mReadyState;

    private long mLastBeginMills;

    private long mLastEndMills;

    private boolean mIsHidden;

    private BaseDanmaku mLastDanmaku;

    private Danmakus mLiveDanmakus = new Danmakus(Danmakus.ST_BY_LIST);

    private DanmakuContext.ConfigChangedCallback mConfigChangedCallback = new DanmakuContext.ConfigChangedCallback() {
        @Override
        public boolean onDanmakuConfigChanged(DanmakuContext config, DanmakuContext.DanmakuConfigTag tag, Object... values) {
            return DrawTask.this.onDanmakuConfigChanged(config, tag, values);
        }
    };

    public DrawTask(DanmakuTimer timer, DanmakuContext context,
            TaskListener taskListener) {
        if (context == null) {
            throw new IllegalArgumentException("context is null");
        }
        mContext = context;
        mDisp = context.getDisplayer();
        mTaskListener = taskListener;
        mRenderer = new DanmakuRenderer(context);
        mRenderer.setOnDanmakuShownListener(new IRenderer.OnDanmakuShownListener() {

            @Override
            public void onDanmakuShown(BaseDanmaku danmaku) {
                if (mTaskListener != null) {
                    mTaskListener.onDanmakuShown(danmaku);
                }
            }
        });
        mRenderer.setVerifierEnabled(mContext.isPreventOverlappingEnabled() || mContext.isMaxLinesLimited());
        initTimer(timer);
        Boolean enable = mContext.isDuplicateMergingEnabled();
        if (enable != null) {
            if(enable) {
                mContext.mDanmakuFilters.registerFilter(DanmakuFilters.TAG_DUPLICATE_FILTER);
            } else {
                mContext.mDanmakuFilters.unregisterFilter(DanmakuFilters.TAG_DUPLICATE_FILTER);
            }
        }
    }

    protected void initTimer(DanmakuTimer timer) {
        mTimer = timer;
    }

    @Override
    public synchronized void addDanmaku(BaseDanmaku item) {
        if (danmakuList == null)
            return;
        if (item.isLive) {
            mLiveDanmakus.addItem(item);
            removeUnusedLiveDanmakusIn(10);
        }
        item.index = danmakuList.size();
        boolean subAdded = true;
        if (mLastBeginMills <= item.time && item.time <= mLastEndMills) {
            synchronized (danmakus) {
                subAdded = danmakus.addItem(item);
            }
        } else if (item.isLive) {
            subAdded = false;
        }
        boolean added = false;
        synchronized (danmakuList) {
            added = danmakuList.addItem(item);
        }
        if (!subAdded) {
            mLastBeginMills = mLastEndMills = 0;
        }
        if (added && mTaskListener != null) {
            mTaskListener.onDanmakuAdd(item);
        }
        if (mLastDanmaku == null || (item != null && mLastDanmaku != null && item.time > mLastDanmaku.time)) {
            mLastDanmaku = item;
        }
    }

    @Override
    public void invalidateDanmaku(BaseDanmaku item, boolean remeasure) {
        mContext.getDisplayer().getCacheStuffer().clearCache(item);
        if (remeasure) {
            item.paintWidth = -1;
            item.paintHeight = -1;
        }
    }
    
    @Override
    public synchronized void removeAllDanmakus(boolean isClearDanmakusOnScreen) {
        if (danmakuList == null || danmakuList.isEmpty())
            return;
        synchronized (danmakuList) {
            if (!isClearDanmakusOnScreen) {
                long beginMills = mTimer.currMillisecond - mContext.mDanmakuFactory.MAX_DANMAKU_DURATION - 100;
                long endMills = mTimer.currMillisecond + mContext.mDanmakuFactory.MAX_DANMAKU_DURATION;
                IDanmakus tempDanmakus = danmakuList.subnew(beginMills, endMills);
                if (tempDanmakus != null)
                    danmakus = tempDanmakus;
            }
            danmakuList.clear();
        }
    }

    protected void onDanmakuRemoved(BaseDanmaku danmaku) {
        // TODO call callback here
    }

    @Override
    public synchronized void removeAllLiveDanmakus() {
        if (danmakus == null || danmakus.isEmpty())
            return;
        synchronized (danmakus) {
            IDanmakuIterator it = danmakus.iterator();
            while (it.hasNext()) {
                BaseDanmaku danmaku = it.next();
                if (danmaku.isLive) {
                    it.remove();
                    onDanmakuRemoved(danmaku);
                }
            }
        }
    }

    protected synchronized void removeUnusedLiveDanmakusIn(int msec) {
        if (danmakuList == null || danmakuList.isEmpty() || mLiveDanmakus.isEmpty())
            return;
        long startTime = SystemClock.uptimeMillis();
        IDanmakuIterator it = mLiveDanmakus.iterator();
        while (it.hasNext()) {
            BaseDanmaku danmaku = it.next();
            boolean isTimeout = danmaku.isTimeOut();
            if (isTimeout) {
                it.remove();
                danmakuList.removeItem(danmaku);
                onDanmakuRemoved(danmaku);
            } else {
                break;
            }
            if (!isTimeout || SystemClock.uptimeMillis() - startTime > msec) {
                break;
            }
        }
    }

    @Override
    public IDanmakus getVisibleDanmakusOnTime(long time) {
        long beginMills = time - mContext.mDanmakuFactory.MAX_DANMAKU_DURATION - 100;
        long endMills = time + mContext.mDanmakuFactory.MAX_DANMAKU_DURATION;
        IDanmakus subDanmakus = danmakuList.subnew(beginMills, endMills);
        IDanmakus visibleDanmakus = new Danmakus();
        if (null != subDanmakus && !subDanmakus.isEmpty()) {
            IDanmakuIterator iterator = subDanmakus.iterator();
            while (iterator.hasNext()) {
                BaseDanmaku danmaku = iterator.next();
                if (danmaku.isShown() && !danmaku.isOutside()) {
                    visibleDanmakus.addItem(danmaku);
                }
            }
        }

        return visibleDanmakus;
    }

    @Override
    public synchronized IRenderer.RenderingState draw(AbsDisplayer displayer) {
        return drawDanmakus(displayer,mTimer);
    }

    @Override
    public void reset() {
        if (danmakus != null)
            danmakus = new Danmakus();
        if (mRenderer != null)
            mRenderer.clear();
    }

    @Override
    public void seek(long mills) {
        reset();
        mContext.mGlobalFlagValues.updateVisibleFlag();
        mContext.mGlobalFlagValues.updateFirstShownFlag();
        mStartRenderTime = mills < 1000 ? 0 : mills;
        if (mRenderingState != null) {
            mRenderingState.reset();
            mRenderingState.endTime = mStartRenderTime;
        }
        if (danmakuList != null) {
            BaseDanmaku last = danmakuList.last();
            if (last != null && !last.isTimeOut()) {
                mLastDanmaku = last;
            }
        }
    }

    @Override
    public void clearDanmakusOnScreen(long currMillis) {
        reset();
        mContext.mGlobalFlagValues.updateVisibleFlag();
        mContext.mGlobalFlagValues.updateFirstShownFlag();
        mStartRenderTime = currMillis;
    }

    @Override
    public void start() {
        mContext.registerConfigChangedCallback(mConfigChangedCallback);
    }

    @Override
    public void quit() {
        mContext.unregisterAllConfigChangedCallbacks();
        if (mRenderer != null)
            mRenderer.release();
    }

    public void prepare() {
        assert (mParser != null);
        loadDanmakus(mParser);
        mLastBeginMills = mLastEndMills = 0;
        if (mTaskListener != null) {
            mTaskListener.ready();
            mReadyState = true;
        }
    }

    protected void loadDanmakus(BaseDanmakuParser parser) {
        danmakuList = parser.setConfig(mContext).setDisplayer(mDisp).setTimer(mTimer).getDanmakus();
        if (danmakuList != null && !danmakuList.isEmpty()) {
            if (danmakuList.first().flags == null) {
                IDanmakuIterator it = danmakuList.iterator();
                while (it.hasNext()) {
                    BaseDanmaku item = it.next();
                    if (item != null) {
                        item.flags = mContext.mGlobalFlagValues;
                    }
                }
            }
        }
        mContext.mGlobalFlagValues.resetAll();

        if(danmakuList != null) {
            mLastDanmaku = danmakuList.last();
        }
    }

    public void setParser(BaseDanmakuParser parser) {
        mParser = parser;
        mReadyState = false;
    }

    protected IRenderer.RenderingState drawDanmakus(AbsDisplayer disp, DanmakuTimer timer) {
        if (clearRetainerFlag) {
            mRenderer.clearRetainer();
            clearRetainerFlag = false;
        }
        if (danmakuList != null) {
            Canvas canvas = (Canvas) disp.getExtraData();
            DrawHelper.clearCanvas(canvas);
            if (mIsHidden) {
                return mRenderingState;
            }
            long beginMills = timer.currMillisecond - mContext.mDanmakuFactory.MAX_DANMAKU_DURATION - 100;
            long endMills = timer.currMillisecond + mContext.mDanmakuFactory.MAX_DANMAKU_DURATION;
            if(mLastBeginMills > beginMills || timer.currMillisecond > mLastEndMills) {
                IDanmakus subDanmakus = danmakuList.sub(beginMills, endMills);
                if(subDanmakus != null) {
                    danmakus = subDanmakus;
                }
                mLastBeginMills = beginMills;
                mLastEndMills = endMills;
            } else {
                beginMills = mLastBeginMills;
                endMills = mLastEndMills;
            }
            if (danmakus != null && !danmakus.isEmpty()) {
                IRenderer.RenderingState renderingState = mRenderingState = mRenderer.draw(mDisp, danmakus, mStartRenderTime);
                if (renderingState.nothingRendered) {
                    if(mLastDanmaku != null && mLastDanmaku.isTimeOut()) {
                        mLastDanmaku = null;
                        if (mTaskListener != null) {
                            mTaskListener.onDanmakusDrawingFinished();
                        }
                    }
                    if (renderingState.beginTime == IRenderer.RenderingState.UNKNOWN_TIME) {
                        renderingState.beginTime = beginMills;
                    }
                    if (renderingState.endTime == IRenderer.RenderingState.UNKNOWN_TIME) {
                        renderingState.endTime = endMills;
                    }
                }
                return renderingState;
            } else {
                mRenderingState.nothingRendered = true;
                mRenderingState.beginTime = beginMills;
                mRenderingState.endTime = endMills;
                return mRenderingState;
            }
        }
        return null;
    }

    public void requestClear() {
        mLastBeginMills = mLastEndMills = 0;
        mIsHidden = false;
    }

    public void requestClearRetainer() {
        clearRetainerFlag = true;
    }

    public boolean onDanmakuConfigChanged(DanmakuContext config, DanmakuContext.DanmakuConfigTag tag,
            Object... values) {
        boolean handled = handleOnDanmakuConfigChanged(config, tag, values);
        if (mTaskListener != null) {
            mTaskListener.onDanmakuConfigChanged();
        }
        return handled;
    }

    protected boolean handleOnDanmakuConfigChanged(DanmakuContext config, DanmakuContext.DanmakuConfigTag tag, Object[] values) {
        boolean handled = false;
        if (tag == null || DanmakuContext.DanmakuConfigTag.MAXIMUM_NUMS_IN_SCREEN.equals(tag)) {
            handled = true;
        } else if (DanmakuContext.DanmakuConfigTag.DUPLICATE_MERGING_ENABLED.equals(tag)) {
            Boolean enable = (Boolean) values[0];
            if (enable != null) {
                if (enable) {
                    mContext.mDanmakuFilters.registerFilter(DanmakuFilters.TAG_DUPLICATE_FILTER);
                } else {
                    mContext.mDanmakuFilters.unregisterFilter(DanmakuFilters.TAG_DUPLICATE_FILTER);
                }
                handled = true;
            }
        } else if (DanmakuContext.DanmakuConfigTag.SCALE_TEXTSIZE.equals(tag) || DanmakuContext.DanmakuConfigTag.SCROLL_SPEED_FACTOR.equals(tag)) {
            requestClearRetainer();
            handled = false;
        } else if (DanmakuContext.DanmakuConfigTag.MAXIMUN_LINES.equals(tag) || DanmakuContext.DanmakuConfigTag.OVERLAPPING_ENABLE.equals(tag)) {
            if (mRenderer != null) {
                mRenderer.setVerifierEnabled(mContext.isPreventOverlappingEnabled() || mContext.isMaxLinesLimited());
            }
            handled = true;
        }
        return handled;
    }

    @Override
    public void requestHide() {
        mIsHidden = true;
    }
}
