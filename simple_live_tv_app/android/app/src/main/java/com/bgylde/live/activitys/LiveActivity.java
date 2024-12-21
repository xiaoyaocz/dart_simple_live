package com.bgylde.live.activitys;

import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.HttpDataSource;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.ui.PlayerView;

import com.bgylde.live.adapter.SelectDialogAdapter;
import com.bgylde.live.core.MessageManager;
import com.bgylde.live.R;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.OkHttpUtil;
import com.bgylde.live.model.LiveModel;
import com.bgylde.live.widgets.SelectDialog;

import java.util.Locale;

import top.littlefogcat.danmakulib.danmaku.Danmaku;
import top.littlefogcat.danmakulib.danmaku.DanmakuManager;

import static com.bgylde.live.adapter.SelectDialogAdapter.stringDiff;
import static com.bgylde.live.core.MessageManager.DEFAULT_CMD;
import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

public class LiveActivity extends AppCompatActivity implements Player.Listener, Handler.Callback, View.OnClickListener {

    private ExoPlayer player;
    private PlayerView playerView;
    private TextView btnFullscreen;
    private TextView follow;
    private TextView clarity;
    private TextView line;
    private boolean isPlaying = false;
    private boolean isFullscreen = false;

    private DanmakuManager danmakuManager;
    private LiveModel liveModel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_layout);

        initData();

        // 初始化视图组件
        initViews();

        // 初始化ExoPlayer及相关配置
        initExoPlayer();

        // 设置播放控制按钮点击事件
        setButtonClickListeners();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        initData();
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
        FlutterManager.getInstance().invokerFlutterMethod("onResume", null);
        if (Build.VERSION.SDK_INT < 24) {
            prepareToPlay();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        playerView.onPause();
        FlutterManager.getInstance().invokerFlutterMethod("onPause", null);
        if (Build.VERSION.SDK_INT < 24) {
            if (player != null) {
                player.release();
            }
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (Build.VERSION.SDK_INT >= 24) {
            if (player != null) {
                player.release();
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除进度更新任务
        MessageManager.getInstance().unRegisterCallback(this);
        FlutterManager.getInstance().invokerFlutterMethod("onDestroy", null);
    }

    private void initData() {
        Bundle bundle = getIntent().getBundleExtra("bundle");
        if (bundle != null) {
            liveModel = bundle.getParcelable("liveModel");
        }

        MessageManager.getInstance().registerCallback(this);
    }

    private void initViews() {
        hideSystemUI(false);
        playerView = findViewById(R.id.player_view);
        btnFullscreen = findViewById(R.id.btn_fullscreen);
        follow = findViewById(R.id.like);
        clarity = findViewById(R.id.clarity);
        line = findViewById(R.id.line);
        // 获得DanmakuManager单例
        danmakuManager = DanmakuManager.getInstance();

        // 设置一个FrameLayout为弹幕容器
        FrameLayout container = findViewById(R.id.container);
        danmakuManager.init(this, container);
        danmakuManager.getConfig().setLineHeight(50);
        danmakuManager.getConfig().setMaxScrollLine(100);
    }

    private void initExoPlayer() {
        playerView = findViewById(R.id.player_view);
        OkHttpDataSource.Factory okHttpDataSource = new OkHttpDataSource.Factory(OkHttpUtil.generateOkHttp());
        okHttpDataSource.setDefaultRequestProperties(liveModel.getRequestHeader());
        DefaultDataSource.Factory dataSourceFactory = new DefaultDataSource.Factory(this, okHttpDataSource);
        player = new ExoPlayer.Builder(this)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(this).setDataSourceFactory(dataSourceFactory))
                .build();
        // 关联ExoPlayer与PlayerView
        playerView.setPlayer(player);

        // 添加事件监听器
        player.addListener(this);

        // 自动开始播放
        player.setPlayWhenReady(true);

        // 注册播放停止函数
        FlutterManager.getInstance().registerMethod("stopPlay");
    }

    private void prepareToPlay() {
        line.setText(String.format(Locale.CHINA, "线路%d", liveModel.getCurrentLineIndex() + 1));
        clarity.setText(liveModel.getClarity());
        follow.setText(liveModel.isFollowed() ? R.string.followed : R.string.unfollowed);

        if (isPlaying) {
            player.stop();
        }

        String videoUrl = "";
        if (liveModel != null && !liveModel.isPlayEmpty()) {
            videoUrl = liveModel.getLine();
        }

        MediaItem mediaItem = MediaItem.fromUri(videoUrl);
        player.setMediaItem(mediaItem);
        // 准备播放
        player.prepare();
        player.play();
    }

    private void setButtonClickListeners() {
        findViewById(R.id.like_layout).setOnClickListener(this);
        findViewById(R.id.clarity_layout).setOnClickListener(this);
        findViewById(R.id.line_layout).setOnClickListener(this);
        findViewById(R.id.ratio_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_size_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_speed_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_area_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_opacity_layout).setOnClickListener(this);
        findViewById(R.id.danmaku_stroke_layout).setOnClickListener(this);
        findViewById(R.id.fullscreen_layout).setOnClickListener(this);
        findViewById(R.id.btn_back).setOnClickListener(this);
        findViewById(R.id.btn_more).setOnClickListener(this);
    }

    @Override
    public void onPlaybackStateChanged(int playbackState) {
        switch (playbackState) {
            case Player.STATE_IDLE:
                break;
            case Player.STATE_BUFFERING:
                // 显示缓冲提示，比如加载动画等
                break;
            case Player.STATE_READY:
                break;
            case Player.STATE_ENDED:
                break;
        }
    }

    @Override
    public void onPlayWhenReadyChanged(boolean playWhenReady, int reason) {
        if (playWhenReady) {
            isPlaying = true;
        }
    }

    @Override
    public void onIsPlayingChanged(boolean isPlaying) {
        this.isPlaying = isPlaying;
        if (!isPlaying) {
            // 播放结束后的处理，比如自动播放下一集（如果有）等
            Toast.makeText(this, "视频播放完毕", Toast.LENGTH_SHORT).show();
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
            } else {
                // Try calling httpError.getCause() to retrieve the underlying cause, although
                // note that it may be null.
                errorMessage = httpError.getCause() == null ? "" : httpError.getCause().getMessage();
            }
        }
        Toast.makeText(this, "播放出错：" + errorMessage, Toast.LENGTH_LONG).show();
        FlutterManager.getInstance().invokerFlutterMethod("mediaError", error.getMessage());
    }

    private void hideSystemUI(boolean shownavbar) {
        int uiVisibility = getWindow().getDecorView().getSystemUiVisibility();
        uiVisibility |= View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
        uiVisibility |= View.SYSTEM_UI_FLAG_LOW_PROFILE;
        uiVisibility |= View.SYSTEM_UI_FLAG_FULLSCREEN;
        uiVisibility |= View.SYSTEM_UI_FLAG_IMMERSIVE;
        uiVisibility |= View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
        if (!shownavbar) {
            uiVisibility |= View.SYSTEM_UI_FLAG_HIDE_NAVIGATION;
            uiVisibility |= View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
        }
        getWindow().getDecorView().setSystemUiVisibility(uiVisibility);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    @Override
    public boolean handleMessage(@NonNull Message message) {
        if (message.what == FLUTTER_TO_JAVA_CMD) {
            if (message.arg1 == "stopPlay".hashCode()) {
                player.stop();
            }

            return true;
        } else if (message.what == DEFAULT_CMD) {
            Bundle bundle = message.getData();
            if (bundle == null) {
                return false;
            }

            String type = bundle.getString("type");
            String msg = bundle.getString("message");
            String color = bundle.getString("color");
            if (type == null || msg == null) {
                return false;
            }

            // 发送弹幕
            Danmaku danmaku = new Danmaku();
            danmaku.text = msg;
            danmaku.size = 42;
            danmaku.color = color;
            danmakuManager.send(danmaku);

            return true;
        } else {
            return false;
        }
    }

    @Override
    public void onClick(View view) {
        int viewId = view.getId();
        if (viewId == R.id.like_layout) {
            FlutterManager.getInstance().invokerFlutterMethod("followUser", null, new FlutterManager.Result() {
                @Override
                public void success(@Nullable Object result) {
                    if (result == null) {
                        return;
                    }

                    boolean followed = (boolean) result;
                    liveModel.setFollowed(followed);
                    follow.setText(liveModel.isFollowed() ? R.string.followed : R.string.unfollowed);
                }
            });
        } else if (viewId == R.id.clarity_layout) {
            SelectDialog<String> dialog = new SelectDialog<>(this);
            dialog.setTip(getString(R.string.clarity));
            dialog.setAdapter(null, new SelectDialogAdapter.SelectDialogInterface<String>() {
                @Override
                public void click(String value, int pos) {
                    try {
                        dialog.cancel();
                        liveModel.setCurrentQuality(pos);
                        FlutterManager.getInstance().invokerFlutterMethod("changeQuality", pos);
                    } catch (Exception ignore) {}
                }

                @Override
                public String getDisplay(String val) {
                    return val;
                }
            }, stringDiff, liveModel.getQualites(), liveModel.getCurrentQuality());
            dialog.show();
        } else if (viewId == R.id.line_layout) {

        } else if (viewId == R.id.ratio_layout) {

        } else if (viewId == R.id.danmaku_layout) {

        } else if (viewId == R.id.danmaku_size_layout) {

        } else if (viewId == R.id.danmaku_speed_layout) {

        } else if (viewId == R.id.danmaku_area_layout) {

        } else if (viewId == R.id.danmaku_opacity_layout) {

        } else if (viewId == R.id.danmaku_stroke_layout) {

        } else if (viewId == R.id.fullscreen_layout) {
            if (!isFullscreen) {
                setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
                isFullscreen = true;
                btnFullscreen.setText(R.string.landscape);
            } else {
                setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                isFullscreen = false;
                btnFullscreen.setText(R.string.portrait);
            }
        } else if (viewId == R.id.btn_back) {
            onBackPressed();
        } else if (viewId == R.id.btn_more) {
            // 这里可以弹出更多功能菜单，比如画质切换等功能
            Toast.makeText(LiveActivity.this, "更多功能待完善", Toast.LENGTH_SHORT).show();
        }
    }
}
