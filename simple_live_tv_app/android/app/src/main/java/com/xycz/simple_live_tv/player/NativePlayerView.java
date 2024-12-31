package com.xycz.simple_live_tv.player;

import android.content.Context;
import android.os.Handler;
import android.os.Message;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.Player;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.VideoSize;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.HttpDataSource;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.analytics.AnalyticsListener;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.core.FlutterManager;
import com.xycz.simple_live_tv.core.LogUtils;
import com.xycz.simple_live_tv.core.MessageManager;
import com.xycz.simple_live_tv.core.MethodCallModel;
import com.xycz.simple_live_tv.core.OkHttpManager;

import java.util.Map;

import io.flutter.plugin.platform.PlatformView;

import static com.xycz.simple_live_tv.core.MessageManager.FLUTTER_TO_JAVA_CMD;

/**
 * Created by wangyan on 2024/12/29
 */
public class NativePlayerView extends ExoPlayerView implements PlatformView, Player.Listener, Handler.Callback, AnalyticsListener {

    private static final String TAG = "NativePlayerView";

    private final Context mContext;

    private ExoPlayer mExoPlayer;

    private boolean mIsPlaying;

    public NativePlayerView(Context context) {
        super(context);
        mContext = context;
        setUseController(false);
        setId(R.id.player_view);
        setFocusable(false);
        setClickable(false);
        initExoPlayer();
    }

    protected void initExoPlayer() {
        OkHttpDataSource.Factory okHttpDataSource = new OkHttpDataSource.Factory(OkHttpManager.getInstance().getOkHttpClient());
        DefaultDataSource.Factory dataSourceFactory = new DefaultDataSource.Factory(mContext, okHttpDataSource);
        mExoPlayer = new ExoPlayer.Builder(mContext)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(mContext).setDataSourceFactory(dataSourceFactory))
                .build();
        // 关联ExoPlayer与PlayerView
        setPlayer(mExoPlayer);

        // 添加事件监听器
        mExoPlayer.addListener(this);

        // 自动开始播放
        mExoPlayer.setPlayWhenReady(true);

        mExoPlayer.addAnalyticsListener(this);

        // 注册播放停止函数
        FlutterManager.getInstance().registerMethod("startPlay");
        FlutterManager.getInstance().registerMethod("stopPlay");
        MessageManager.getInstance().registerCallback(this);
    }

    public void startToPlay(String videoUrl, Map<String, String> header) {
        if (header != null) {
            OkHttpManager.getInstance().resetRequestHeader(header);
        }

        MediaItem mediaItem = MediaItem.fromUri(videoUrl);
        mExoPlayer.setMediaItem(mediaItem);
        // 准备播放
        mExoPlayer.prepare();
        mExoPlayer.play();
    }

    @Override
    public void onIsPlayingChanged(boolean isPlaying) {
        this.mIsPlaying = isPlaying;
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

    @Nullable
    @Override
    public View getView() {
        return this;
    }

    @Override
    public void dispose() {
        release();
        MessageManager.getInstance().unRegisterCallback(this);
    }

    @Override
    public boolean handleMessage(@NonNull Message message) {
        if (message.what == FLUTTER_TO_JAVA_CMD) {
            MethodCallModel model = (MethodCallModel)message.obj;
            if (message.arg1 == "startPlay".hashCode()) {
                String videoUrl = model.getMethodCall().argument("videoUrl");
                startToPlay(videoUrl, null);
            } else {
                return false;
            }

            return true;
        } else {
            return false;
        }
    }
}
