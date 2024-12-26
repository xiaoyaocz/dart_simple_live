package com.bgylde.live.core;

import com.bgylde.live.danmaku.controller.DrawHandler;
import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.model.DanmakuTimer;
import com.bgylde.live.danmaku.model.IDanmakus;
import com.bgylde.live.danmaku.model.android.Danmakus;
import com.bgylde.live.danmaku.parser.BaseDanmakuParser;
import com.bgylde.live.danmaku.widget.DanmakuView;

/**
 * Created by wangyan on 2024/12/26
 */
public class DanmakuInstance extends BaseDanmakuParser implements DrawHandler.Callback {

    private final DanmakuView danmakuView;

    public DanmakuInstance(DanmakuView danmakuView) {
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
