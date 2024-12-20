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
    private ArrayList<String> playUrls = new ArrayList<>();

    private static final String kBiliBili = "bilibili";
    private static final String kDouyu = "douyu";
    private static final String kHuya = "huya";
    private static final String kDouyin = "douyin";

    public LiveModel() {
    }

    public LiveModel(String id, String roomId, String name, String logo, Integer index, ArrayList<String> playUrls) {
        this.id = id;
        this.roomId = roomId;
        this.name = name;
        this.logo = logo;
        this.index = index;
        this.playUrls = playUrls;
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
        playUrls = in.createStringArrayList();
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

    public ArrayList<String> getPlayUrls() {
        return playUrls;
    }

    public void setPlayUrls(ArrayList<String> playUrls) {
        this.playUrls = playUrls;
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(@NonNull Parcel parcel, int i) {
        parcel.writeString(id);
        parcel.writeString(roomId);
        parcel.writeString(name);
        parcel.writeString(logo);
        if (index == null) {
            parcel.writeByte((byte) 0);
        } else {
            parcel.writeByte((byte) 1);
            parcel.writeInt(index);
        }
        parcel.writeStringList(playUrls);
    }
}
