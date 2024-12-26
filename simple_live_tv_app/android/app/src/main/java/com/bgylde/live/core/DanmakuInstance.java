package com.bgylde.live.core;

import com.bgylde.live.danmaku.flame.controller.DrawHandler;
import com.bgylde.live.danmaku.flame.controller.IDanmakuView;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.DanmakuTimer;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.model.android.Danmakus;
import com.bgylde.live.danmaku.flame.parser.BaseDanmakuParser;

/**
 * Created by wangyan on 2024/12/26
 */
public class DanmakuInstance extends BaseDanmakuParser implements DrawHandler.Callback {

    private final IDanmakuView danmakuView;

    public DanmakuInstance(IDanmakuView danmakuView) {
        this.danmakuView = danmakuView;
    }

    @Override
    protected IDanmakus parse() {
        return new Danmakus();
    }

    @Override
    public void prepared() {
        danmakuView.start();
    }

    @Override
    public void updateTimer(DanmakuTimer timer) {

    }

    @Override
    public void danmakuShown(BaseDanmaku danmaku) {

    }

    @Override
    public void drawingFinished() {

    }
}
