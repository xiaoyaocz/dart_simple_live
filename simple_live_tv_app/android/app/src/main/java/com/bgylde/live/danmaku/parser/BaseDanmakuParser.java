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

package com.bgylde.live.danmaku.parser;

import com.bgylde.live.danmaku.model.DanmakuTimer;
import com.bgylde.live.danmaku.model.IDanmakus;
import com.bgylde.live.danmaku.model.IDisplayer;
import com.bgylde.live.danmaku.model.android.DanmakuContext;

/**
 *
 */
public abstract class BaseDanmakuParser {
    protected IDataSource<?> mDataSource;

    protected DanmakuTimer mTimer;
    protected int mDispWidth;
    protected int mDispHeight;
    protected float mDispDensity;
    protected float mScaledDensity;

    private IDanmakus mDanmakus;

    protected IDisplayer mDisp;
    protected DanmakuContext mContext;

    public BaseDanmakuParser setDisplayer(IDisplayer disp){
        mDisp = disp;
    	mDispWidth = disp.getWidth();
        mDispHeight = disp.getHeight();
        mDispDensity = disp.getDensity();
        mScaledDensity = disp.getScaledDensity();
        mContext.mDanmakuFactory.updateViewportState(mDispWidth, mDispHeight, getViewportSizeFactor());
        mContext.mDanmakuFactory.updateMaxDanmakuDuration();
        return this;
    }
    
    /**
     * decide the speed of scroll-danmakus
     * @return
     */
    protected float getViewportSizeFactor() {
        return 1 / (mDispDensity - 0.6f);
    }

    public IDisplayer getDisplayer(){
        return mDisp;
    }
    
    public BaseDanmakuParser load(IDataSource<?> source) {
        mDataSource = source;
        return this;
    }
    
    public BaseDanmakuParser setTimer(DanmakuTimer timer) {
        mTimer = timer;
        return this;
    }

    public DanmakuTimer getTimer() {
        return mTimer;
    }
    
    public IDanmakus getDanmakus() {
        if (mDanmakus != null)
            return mDanmakus;
        mContext.mDanmakuFactory.resetDurationsData();
        mDanmakus = parse();
        releaseDataSource();
        mContext.mDanmakuFactory.updateMaxDanmakuDuration();
        return mDanmakus;
    }
    
    protected void releaseDataSource() {
        if(mDataSource!=null)
            mDataSource.release();
        mDataSource = null;
    }

    protected abstract IDanmakus parse();

    public void release() {
        releaseDataSource();
    }

    public BaseDanmakuParser setConfig(DanmakuContext config) {
        if (mContext != null && mContext != config) {
            mDanmakus = null; // call re-parse() under different context
        }
        mContext = config;
        return this;
    }
}
