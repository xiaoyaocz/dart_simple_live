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

import java.io.InputStream;

import com.bgylde.live.danmaku.loader.ILoader;
import com.bgylde.live.danmaku.loader.IllegalDataException;
import com.bgylde.live.danmaku.parser.android.AndroidFileSource;

public class BiliDanmakuLoader implements ILoader {

    private static BiliDanmakuLoader _instance;

    private AndroidFileSource dataSource;

    private BiliDanmakuLoader() {

    }

    public static BiliDanmakuLoader instance() {
        if (_instance == null) {
            _instance = new BiliDanmakuLoader();
        }
        return _instance;
    }

    public void load(String uri) throws IllegalDataException {
        try {            
            dataSource = new AndroidFileSource(uri);
        } catch (Exception e) {
        	throw new IllegalDataException(e);
        }
    }

    public void load(InputStream stream) {
        dataSource = new AndroidFileSource(stream);
    }

    @Override
    public AndroidFileSource getDataSource() {
        return dataSource;
    }
}
