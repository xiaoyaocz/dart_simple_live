package com.bgylde.live;

import android.app.Application;

import androidx.ijk.IJK;
import androidx.ijk.enums.Display;

import tv.danmaku.ijk.media.player.IjkMediaPlayer;

/**
 * Created by wangyan on 2024/12/21
 */
public class LiveApplication extends Application {

    @Override
    public void onCreate() {
        super.onCreate();
        initIjkConfig();
    }

    private void initIjkConfig() {
        IJK ijk = IJK.config();
        // 设置默认显示方式
        ijk.display(Display.AUTO);
        // 设置默认显示比例
        ijk.ratio(16,9);
        // 使用硬解码器解码
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 1);
        // 自动旋转视频画面
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", 1);
        // 处理分辨率变化
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", 1);
        // 设置最大缓冲区大小（默认是0，表示无限制）
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size",  1024*1024*5);
        // 设置最小缓冲帧数
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", 60);
        // 设置最大缓存时长
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max_cached_duration", 5000);
        // 设置启动时的探测时间（毫秒）
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", 400);
        // 设置分析最大时长（毫秒）
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", 100);
        // 强制刷新数据包
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "flush_packets", 1L);
        // 禁用数据包缓冲
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", 0L);
        // 设置帧率为30
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "fps", 120);
        // 设置超时时间
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "timeout", 10000);
        // 启用无限缓冲模式
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "infbuf", 0);
        // 启用帧丢弃
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1);
        // 跳过环路过滤器（Loop Filter），提高解码性能
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", 48);
        // 禁用 HTTP 资源范围检测
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "http-detect-range-support", 1);
        // 启用精确的 seek（定位）
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", 1);
        // 清除DNS缓存（为了提高域名解析的效率）
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "dns_cache_clear", 1);
        // 自动重新连接
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect", 1);
        // 调用prepareAsync()方法后是否自动开始播放
        ijk.option(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1);
    }
}
