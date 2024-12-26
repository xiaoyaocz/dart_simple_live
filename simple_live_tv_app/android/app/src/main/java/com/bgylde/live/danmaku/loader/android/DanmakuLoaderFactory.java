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

package com.bgylde.live.danmaku.loader.android;

import com.bgylde.live.danmaku.loader.ILoader;

public class DanmakuLoaderFactory {

    public static String TAG_BILI = "bili";
    public static String TAG_ACFUN = "acfun";
    
    public static ILoader create(String tag) {
        if (TAG_BILI.equalsIgnoreCase(tag)) {
            return BiliDanmakuLoader.instance();
        } else if(TAG_ACFUN.equalsIgnoreCase(tag))
        	return AcFunDanmakuLoader.instance();
        return null;
    }

}
