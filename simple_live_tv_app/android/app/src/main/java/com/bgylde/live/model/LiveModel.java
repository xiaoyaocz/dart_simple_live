package com.bgylde.live.model;

import android.os.Parcel;
import android.os.Parcelable;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by wangyan on 2024/12/20
 */
public class LiveModel implements Parcelable {

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
    private ArrayList<String> playUrls = new ArrayList<>();
    // 当前清晰度index
    private Integer currentQuality;
    // 清晰度
    private ArrayList<String> qualites = new ArrayList<>();

    private static final String kBiliBili = "bilibili";
    private static final String kDouyu = "douyu";
    private static final String kHuya = "huya";
    private static final String kDouyin = "douyin";

    public LiveModel() {
    }

    public LiveModel(String id, String roomId, String name, String logo, Integer index, Boolean followed, ArrayList<String> playUrls, ArrayList<String> qualites) {
        this.id = id;
        this.roomId = roomId;
        this.name = name;
        this.logo = logo;
        this.index = index;
        this.followed = followed;
        this.playUrls = playUrls;
        this.qualites = qualites;
    }


    protected LiveModel(Parcel in) {
        id = in.readString();
        roomId = in.readString();
        name = in.readString();
        logo = in.readString();
        if (in.readByte() == 0) {
            index = null;
        } else {
            index = in.readInt();
        }
        followed = in.readByte() != 0;
        if (in.readByte() == 0) {
            currentLineIndex = null;
        } else {
            currentLineIndex = in.readInt();
        }
        playUrls = in.createStringArrayList();
        if (in.readByte() == 0) {
            currentQuality = null;
        } else {
            currentQuality = in.readInt();
        }
        qualites = in.createStringArrayList();
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(id);
        dest.writeString(roomId);
        dest.writeString(name);
        dest.writeString(logo);
        if (index == null) {
            dest.writeByte((byte) 0);
        } else {
            dest.writeByte((byte) 1);
            dest.writeInt(index);
        }
        dest.writeByte((byte) (followed ? 1 : 0));
        if (currentLineIndex == null) {
            dest.writeByte((byte) 0);
        } else {
            dest.writeByte((byte) 1);
            dest.writeInt(currentLineIndex);
        }
        dest.writeStringList(playUrls);
        if (currentQuality == null) {
            dest.writeByte((byte) 0);
        } else {
            dest.writeByte((byte) 1);
            dest.writeInt(currentQuality);
        }
        dest.writeStringList(qualites);
    }

    @Override
    public int describeContents() {
        return 0;
    }

    public static final Creator<LiveModel> CREATOR = new Creator<LiveModel>() {
        @Override
        public LiveModel createFromParcel(Parcel in) {
            return new LiveModel(in);
        }

        @Override
        public LiveModel[] newArray(int size) {
            return new LiveModel[size];
        }
    };

    public boolean isPlayEmpty() {
        return playUrls == null || playUrls.isEmpty();
    }

    public Map<String, String> getRequestHeader() {
        Map<String, String> headerMap = new HashMap<>();
        if (kBiliBili.equals(id)) {
            headerMap.put("referer", "https://live.bilibili.com");
            headerMap.put("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.188");
        } else if (kHuya.equals(id)) {
            headerMap.put("user-agent", "HYSDK(Windows, 20000308)");
        }

        return headerMap;
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

    public String getId() {
        return id;
    }

    public String getRoomId() {
        return roomId;
    }

    public String getName() {
        return name;
    }

    public String getLogo() {
        return logo;
    }

    public Integer getIndex() {
        return index;
    }

    public boolean isFollowed() {
        return followed;
    }

    public Integer getCurrentLineIndex() {
        return currentLineIndex;
    }

    public ArrayList<String> getPlayUrls() {
        return playUrls;
    }

    public Integer getCurrentQuality() {
        return currentQuality;
    }

    public ArrayList<String> getQualites() {
        return qualites;
    }

    public LiveModel setId(String id) {
        this.id = id;
        return this;
    }

    public LiveModel setRoomId(String roomId) {
        this.roomId = roomId;
        return this;
    }

    public LiveModel setName(String name) {
        this.name = name;
        return this;
    }

    public LiveModel setLogo(String logo) {
        this.logo = logo;
        return this;
    }

    public LiveModel setIndex(Integer index) {
        this.index = index;
        return this;
    }

    public LiveModel setFollowed(boolean followed) {
        this.followed = followed;
        return this;
    }

    public LiveModel setCurrentLineIndex(Integer currentLineIndex) {
        this.currentLineIndex = currentLineIndex;
        return this;
    }

    public LiveModel setPlayUrls(ArrayList<String> playUrls) {
        this.playUrls = playUrls;
        return this;
    }

    public LiveModel setCurrentQuality(Integer currentQuality) {
        this.currentQuality = currentQuality;
        return this;
    }

    public LiveModel setQualites(ArrayList<String> qualites) {
        this.qualites = qualites;
        return this;
    }
}
