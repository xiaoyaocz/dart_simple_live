package com.xycz.simple_live_tv.activity;

import android.os.Build;
import android.widget.RelativeLayout;

import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.HttpDataSource;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.core.BaseActivity;
import com.xycz.simple_live_tv.core.FlutterManager;
import com.xycz.simple_live_tv.core.LogUtils;
import com.xycz.simple_live_tv.core.OkHttpManager;
import com.xycz.simple_live_tv.player.ExoPlayerView;

public class ExoLiveActivity extends BaseActivity implements Player.Listener {

    private static final String TAG = "ExoLiveActivity";
    private ExoPlayer exoPlayer;
    private ExoPlayerView playerView;

    @Override
    protected void initViews() {
        super.initViews();
        playerView = new ExoPlayerView(this);
        playerView.setUseController(false);
        playerView.setId(R.id.player_view);
        playerView.setFocusable(false);
        playerView.setClickable(false);
        player = playerView;
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(
                RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        playerLayout.addView(playerView, 0, layoutParams);
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (Build.VERSION.SDK_INT >= 24) {
            prepareToPlay();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        playerView.onResume();
        if (Build.VERSION.SDK_INT < 24) {
            prepareToPlay();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        playerView.onPause();
        if (Build.VERSION.SDK_INT < 24) {
            exoPlayer.release();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (Build.VERSION.SDK_INT >= 24) {
            exoPlayer.release();
        }
    }

    @Override
    protected void initExoPlayer() {
        OkHttpDataSource.Factory okHttpDataSource = new OkHttpDataSource.Factory(OkHttpManager.getInstance().getOkHttpClient());
        DefaultDataSource.Factory dataSourceFactory = new DefaultDataSource.Factory(this, okHttpDataSource);
        exoPlayer = new ExoPlayer.Builder(this)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(this).setDataSourceFactory(dataSourceFactory))
                .build();
        // 关联ExoPlayer与PlayerView
        playerView.setPlayer(exoPlayer);

        // 添加事件监听器
        exoPlayer.addListener(this);

        // 自动开始播放
        exoPlayer.setPlayWhenReady(true);

        // 注册播放停止函数
        FlutterManager.getInstance().registerMethod("stopPlay");
    }

    @Override
    public void prepareToPlay() {
        super.prepareToPlay();
        String videoUrl = "";
        if (liveModel != null && !liveModel.isPlayEmpty()) {
            videoUrl = liveModel.getLine();
        }
        MediaItem mediaItem = MediaItem.fromUri(videoUrl);
        exoPlayer.setMediaItem(mediaItem);
        // 准备播放
        exoPlayer.prepare();
        exoPlayer.play();
    }

    @Override
    public void onIsPlayingChanged(boolean isPlaying) {
        this.isPlaying = isPlaying;
        if (!isPlaying) {
            // 播放结束后的处理，比如自动播放下一集（如果有）等
            FlutterManager.getInstance().invokerFlutterMethod("mediaEnd", null);
        }
    }

    @Override
    public void onPlayerError(PlaybackException error) {
        // 详细的错误处理，根据不同错误类型提示用户或者记录日志等
        String errorMessage = error.getMessage();
        Throwable cause = error.getCause();
        if (cause instanceof HttpDataSource.HttpDataSourceException) {
            // An HTTP error occurred.
            HttpDataSource.HttpDataSourceException httpError = (HttpDataSource.HttpDataSourceException) cause;
            // It's possible to find out more about the error both by casting and by querying
            // the cause.
            if (httpError instanceof HttpDataSource.InvalidResponseCodeException) {
                // Cast to InvalidResponseCodeException and retrieve the response code, message
                // and headers.
                HttpDataSource.InvalidResponseCodeException invalidResponseCodeException = (HttpDataSource.InvalidResponseCodeException)httpError;
                errorMessage = invalidResponseCodeException.getMessage();
                if (invalidResponseCodeException.responseCode == 302) {
                    return;
                }
            } else {
                // Try calling httpError.getCause() to retrieve the underlying cause, although
                // note that it may be null.
                errorMessage = httpError.getCause() == null ? "" : httpError.getCause().getMessage();
            }
        }
        LogUtils.e(TAG, errorMessage, error);
        FlutterManager.getInstance().invokerFlutterMethod("mediaError", errorMessage);
    }

    @Override
    public void onVideoSizeChanged(VideoSize videoSize) {
        LogUtils.i(TAG, videoSize.width + "x" + videoSize.height);
    }
}
