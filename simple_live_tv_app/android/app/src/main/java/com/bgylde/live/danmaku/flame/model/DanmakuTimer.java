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

package com.bgylde.live.danmaku.flame.model;

public class DanmakuTimer {
    public long currMillisecond;

    private long lastInterval;

    public long update(long curr) {
        lastInterval = curr - currMillisecond;
        currMillisecond = curr;
        return lastInterval;
    }

    public long add(long mills) {
        return update(currMillisecond + mills);
    }

    public long lastInterval() {
        return lastInterval;
    }

}
