package com.xycz.simple_live_tv.model;

import androidx.annotation.NonNull;

import com.google.gson.annotations.SerializedName;

import java.util.List;
import java.util.Map;

/**
 * Created by wangyan on 2024/12/20
 */
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

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getRoomId() {
        return roomId;
    }

    public void setRoomId(String roomId) {
        this.roomId = roomId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getLogo() {
        return logo;
    }

    public void setLogo(String logo) {
        this.logo = logo;
    }

    public Integer getIndex() {
        return index;
    }

    public void setIndex(Integer index) {
        this.index = index;
    }

    public boolean isFollowed() {
        return followed;
    }

    public void setFollowed(boolean followed) {
        this.followed = followed;
    }

    public Integer getCurrentLineIndex() {
        return currentLineIndex;
    }

    public void setCurrentLineIndex(Integer currentLineIndex) {
        this.currentLineIndex = currentLineIndex;
    }

    public List<String> getPlayUrls() {
        return playUrls;
    }

    public void setPlayUrls(List<String> playUrls) {
        this.playUrls = playUrls;
    }

    public Integer getCurrentQuality() {
        return currentQuality;
    }

    public void setCurrentQuality(Integer currentQuality) {
        this.currentQuality = currentQuality;
    }

    public List<String> getQualites() {
        return qualites;
    }

    public void setQualites(List<String> qualites) {
        this.qualites = qualites;
    }

    public Map<String, String> getHeaderMap() {
        return headerMap;
    }

    public void setHeaderMap(Map<String, String> headerMap) {
        this.headerMap = headerMap;
    }

    public String getRoomTitle() {
        return roomTitle;
    }

    public void setRoomTitle(String roomTitle) {
        this.roomTitle = roomTitle;
    }

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
