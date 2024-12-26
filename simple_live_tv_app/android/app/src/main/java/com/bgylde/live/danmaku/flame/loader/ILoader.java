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

package com.bgylde.live.danmaku.flame.loader;

import java.io.InputStream;

import com.bgylde.live.danmaku.flame.parser.IDataSource;

public interface ILoader {
    /**
     * @return data source
     */
    IDataSource<?> getDataSource();
    /**
     * @param uri 弹幕文件地址(http:// file://)
     */
    void load(String uri) throws IllegalDataException;
    /**
     * 
     * @param in stream from Internet or local file
     */
    void load(InputStream in) throws IllegalDataException;
}
