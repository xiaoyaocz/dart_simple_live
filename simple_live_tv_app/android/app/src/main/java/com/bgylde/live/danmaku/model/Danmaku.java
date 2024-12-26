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

package com.bgylde.live.danmaku.model;

import com.bgylde.live.danmaku.util.DanmakuUtils;

public class Danmaku extends BaseDanmaku {

    public Danmaku(CharSequence text) {
        DanmakuUtils.fillText(this, text);
    }

    @Override
    public boolean isShown() {
        return false;
    }

    @Override
    public void layout(IDisplayer displayer, float x, float y) {

    }

    @Override
    public float[] getRectAtTime(IDisplayer displayer, long time) {
        return null;
    }

    @Override
    public float getLeft() {
        return 0;
    }

    @Override
    public float getTop() {
        return 0;
    }

    @Override
    public float getRight() {
        return 0;
    }

    @Override
    public float getBottom() {
        return 0;
    }

    @Override
    public int getType() {
        return 0;
    }
}
