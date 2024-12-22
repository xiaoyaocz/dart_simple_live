package com.bgylde.live.activity;

import android.net.Uri;
import android.text.TextUtils;
import android.widget.RelativeLayout;
import android.widget.Toast;
import androidx.ijk.widget.VideoHolder;
import com.bgylde.live.core.BaseActivity;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.LogUtils;
import com.bgylde.live.core.MessageManager;
import com.bgylde.live.player.IjkPlayerView;
import com.bgylde.live.player.VideoPlayerListener;
import tv.danmaku.ijk.media.player.IMediaPlayer;

public class IjkLiveActivity extends BaseActivity implements VideoPlayerListener {

    private IjkPlayerView playerView;

    @Override
    protected void initViews() {
        super.initViews();
        playerView = new IjkPlayerView(this);
        player = playerView;
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(
                RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        playerLayout.addView(playerView, 0, layoutParams);
    }

    @Override
    protected void onStop() {
        super.onStop();
        playerView.stop();
        playerView.release();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        playerView.destroy();
        // 移除进度更新任务
        MessageManager.getInstance().unRegisterCallback(this);
        FlutterManager.getInstance().invokerFlutterMethod("onDestroy", null);
    }

    @Override
    protected void initExoPlayer() {
        // 修改默认的显示方式
        // playerView.setDisplay(Display.AUTO);
        // 修改模式显示比例,注意：比例修改只适用Display.RATIO_WIDTH和Display.RATIO_HEIGHT
        // playerView.setRatio(Display.RATIO_WIDTH,16,9);
        // 视频控制ViewHolder
        VideoHolder holder = playerView.getVideoHolder();
        playerView.setOnIJKVideoListener(this);
        // 自定义全屏还是小屏幕显示，不设置就采用默认的逻辑；
        playerView.setOnVideoSwitchScreenListener(orientation -> {
            //TODO: 自定显示方式
        });

        // 注册播放停止函数
        FlutterManager.getInstance().registerMethod("stopPlay");
    }

    @Override
    public void prepareToPlay() {
        super.prepareToPlay();

        if (isPlaying) {
            playerView.showLoading();
            playerView.reset();
            playerView.setSurface(playerView.getSurface());
            playerView.stop();
        }

        // 播放视频
        String videoUrl = "";
        if (liveModel != null && !liveModel.isPlayEmpty()) {
            videoUrl = liveModel.getLine();
        }

        // 是否是直播源
        playerView.setLiveSource(true);
        // 开始播放
        String source = playerView.getDataSource();
        if (TextUtils.isEmpty(source)) {
            playerView.setDataSource(Uri.parse(videoUrl), liveModel.getHeaderMap());
            playerView.start();
        } else {
            playerView.reset();
            playerView.setDataSource(Uri.parse(videoUrl), liveModel.getHeaderMap());
            playerView.prepareAsync();
        }
    }

    @Override
    public void onVideoPrepared(IMediaPlayer var1) {
        isPlaying = true;
    }

    @Override
    public void onVideoCompletion(IMediaPlayer var1) {
        FlutterManager.getInstance().invokerFlutterMethod("mediaEnd", null);
        isPlaying = false;
    }

    @Override
    public void onVideoError(IMediaPlayer mp, int what, int extra) {
        Toast.makeText(this, "播放出错：" + what, Toast.LENGTH_LONG).show();
        LogUtils.w("Test", "what = " + what + " extra = " + extra);
        FlutterManager.getInstance().invokerFlutterMethod("mediaError", extra);
        isPlaying = false;
    }

    @Override
    public void onVideoSizeChanged(IMediaPlayer mp, int width, int height, int sar_num, int sar_den) {
        LogUtils.w("Test", "onVideoSizeChanged=> " + width + "x" + height);
    }
}
