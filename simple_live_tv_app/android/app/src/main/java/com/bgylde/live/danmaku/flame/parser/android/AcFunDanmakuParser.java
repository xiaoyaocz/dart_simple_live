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

package com.bgylde.live.danmaku.flame.parser.android;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.graphics.Color;

import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.android.Danmakus;
import com.bgylde.live.danmaku.flame.parser.BaseDanmakuParser;
import com.bgylde.live.danmaku.flame.util.DanmakuUtils;

public class AcFunDanmakuParser extends BaseDanmakuParser {

    @Override
    public Danmakus parse() {
        if (mDataSource != null && mDataSource instanceof JSONSource) {
            JSONSource jsonSource = (JSONSource) mDataSource;
            return doParse(jsonSource.data());
        }
        return new Danmakus();
    }

    /**
     * @param danmakuListData 弹幕数据
     *                        传入的数组内包含普通弹幕，会员弹幕，锁定弹幕。
     * @return 转换后的Danmakus
     */
    private Danmakus doParse(JSONArray danmakuListData) {
        Danmakus danmakus = new Danmakus();
        if (danmakuListData == null || danmakuListData.length() == 0) {
            return danmakus;
        }
        for (int i = 0; i < danmakuListData.length(); i++) {
            try {
                JSONObject danmakuArray = danmakuListData.getJSONObject(i);
                if (danmakuArray != null) {
                    danmakus = _parse(danmakuArray, danmakus);
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
        return danmakus;
    }

    private Danmakus _parse(JSONObject jsonObject, Danmakus danmakus) {
        if (danmakus == null) {
            danmakus = new Danmakus();
        }
        if (jsonObject == null || jsonObject.length() == 0) {
            return danmakus;
        }
        for (int i = 0; i < jsonObject.length(); i++) {
            try {
                JSONObject obj = jsonObject;
                String c = obj.getString("c");
                String[] values = c.split(",");
                if (values.length > 0) {
                    int type = Integer.parseInt(values[2]); // 弹幕类型
                    if (type == 7)
                        // FIXME : hard code
                        // TODO : parse advance danmaku json
                        continue;
                    long time = (long) (Float.parseFloat(values[0]) * 1000); // 出现时间
                    int color = Integer.parseInt(values[1]) | 0xFF000000; // 颜色
                    float textSize = Float.parseFloat(values[3]); // 字体大小
                    BaseDanmaku item = mContext.mDanmakuFactory.createDanmaku(type, mContext);
                    if (item != null) {
                        item.time = time;
                        item.textSize = textSize * (mDispDensity - 0.6f);
                        item.textColor = color;
                        item.textShadowColor = color <= Color.BLACK ? Color.WHITE : Color.BLACK;
                        DanmakuUtils.fillText(item, obj.optString("m", "...."));
                        item.index = i;
                        item.setTimer(mTimer);
                        danmakus.addItem(item);
                    }
                }
            } catch (JSONException e) {
            } catch (NumberFormatException e) {
            }
        }
        return danmakus;
    }
}
