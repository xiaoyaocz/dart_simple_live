package com.bgylde.live.model;

import androidx.annotation.NonNull;

import com.google.gson.annotations.SerializedName;

import java.util.List;
import java.util.Map;

import lombok.Getter;
import lombok.Setter;

/**
 * Created by wangyan on 2024/12/20
 */
@Setter
@Getter
public class LiveModel {

    private String id;
    private String roomId;
    private String name;
    private String logo;
    private Integer index;
    // 是否已经关注
    private boolean followed;
    // 当前播放线路
    private Integer currentLineIndex;
    // 播放线路地址
    @SerializedName("liveUrl")
    private List<String> playUrls;
    // 当前清晰度index
    private Integer currentQuality;
    // 清晰度
    @SerializedName("qualites")
    private List<String> qualites;
    @SerializedName("headers")
    private Map<String, String> headerMap;
    @SerializedName("roomTitle")
    private String roomTitle;

    private static final String kBiliBili = "bilibili";
    private static final String kDouyu = "douyu";
    private static final String kHuya = "huya";
    private static final String kDouyin = "douyin";

    public boolean isPlayEmpty() {
        return playUrls == null || playUrls.isEmpty();
    }

    @NonNull
    @Override
    public String toString() {
        return "LiveModel{" +
                "roomId='" + roomId + '\'' +
                ", name='" + name + '\'' +
                ", logo='" + logo + '\'' +
                ", index='" + index + '\'' +
                ", playUrls=" + playUrls +
                '}';
    }

    public String getClarity() {
        String clarity = null;
        if (currentQuality >= 0) {
            clarity = qualites.get(currentQuality);
        }

        return clarity == null ? "" : clarity;
    }

    public String getLine() {
        String line = null;
        if (currentLineIndex >= 0) {
            line = playUrls.get(currentLineIndex);
        }

        return line == null ? "" : line;
    }
}
