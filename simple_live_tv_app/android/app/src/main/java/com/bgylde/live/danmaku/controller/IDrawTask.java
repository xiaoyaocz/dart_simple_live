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

package com.bgylde.live.danmaku.controller;

import com.bgylde.live.danmaku.model.AbsDisplayer;
import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.model.IDanmakus;
import com.bgylde.live.danmaku.parser.BaseDanmakuParser;
import com.bgylde.live.danmaku.renderer.IRenderer.RenderingState;

public interface IDrawTask {

    public void addDanmaku(BaseDanmaku item);

    public void removeAllDanmakus(boolean isClearDanmakusOnScreen);

    public void removeAllLiveDanmakus();

    public void clearDanmakusOnScreen(long currMillis);

	public IDanmakus getVisibleDanmakusOnTime(long time);

    public RenderingState draw(AbsDisplayer displayer);

    public void reset();

    public void seek(long mills);

    public void start();

    public void quit();

    public void prepare();

    public void requestClear();

    public void setParser(BaseDanmakuParser parser);

    void invalidateDanmaku(BaseDanmaku item, boolean remeasure);

    public interface TaskListener {
        public void ready();

        public void onDanmakuAdd(BaseDanmaku danmaku);

        public void onDanmakuShown(BaseDanmaku danmaku);

        public void onDanmakuConfigChanged();

        public void onDanmakusDrawingFinished();
    }

    public void requestHide();

}
