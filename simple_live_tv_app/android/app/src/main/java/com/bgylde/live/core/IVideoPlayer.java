package com.bgylde.live.core;

/**
 * Created by wangyan on 2024/12/22
 */
public interface IVideoPlayer {

    void prepare();

    void start();

    void stop();

    void release();
}
