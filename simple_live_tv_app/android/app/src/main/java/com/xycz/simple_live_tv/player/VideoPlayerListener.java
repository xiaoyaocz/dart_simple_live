package com.xycz.simple_live_tv.player;

import androidx.ijk.listener.OnVideoListener;

import tv.danmaku.ijk.media.player.IMediaPlayer;

/**
 * Created by wangyan on 2024/12/21
 */
public interface VideoPlayerListener extends OnVideoListener {

    default void onVideoPrepared(IMediaPlayer var1) {}

    default void onVideoSizeChanged(IMediaPlayer mp, int width, int height, int sar_num, int sar_den) {}

    default void onVideoSeekEnable(boolean var1) {}

    default void onVideoBufferingStart(IMediaPlayer var1, int var2) {}

    default void onVideoBufferingEnd(IMediaPlayer var1, int var2) {}

    default void onVideoRenderingStart(IMediaPlayer var1, int var2) {}

    default void onVideoRotationChanged(IMediaPlayer var1, int var2) {}

    default void onVideoTrackLagging(IMediaPlayer var1, int var2) {}

    default void onVideoBadInterleaving(IMediaPlayer var1, int var2) {}

    default void onVideoSeekComplete(IMediaPlayer var1) {}

    default void onVideoProgress(IMediaPlayer var1, long var2, long var4) {}

    default void onVideoCompletion(IMediaPlayer var1) {}

    default void onVideoError(IMediaPlayer mp, int what, int extra) {}
}