package com.bgylde.live;

import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.model.LiveModel;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.PlaybackException;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.source.BaseMediaSource;
import com.google.android.exoplayer2.source.ProgressiveMediaSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.ui.PlayerView;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.HttpDataSource;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import top.littlefogcat.danmakulib.danmaku.Danmaku;
import top.littlefogcat.danmakulib.danmaku.DanmakuManager;

public class HomeActivity extends AppCompatActivity implements Player.Listener, Handler.Callback {

    private SimpleExoPlayer player;
    private PlayerView playerView;
    private ImageButton playPauseButton;
    private SeekBar seekBar;
    private TextView tvCurrentTime;
    private TextView tvTotalTime;
    private ImageButton btnVolume;
    private ImageButton btnFullscreen;
    private ImageButton btnBack;
    private ImageButton btnMore;
    private boolean isPlaying = false;
    private boolean isFullscreen = false;
    private final Handler handler = new Handler();
    private Runnable updateProgressRunnable;

    private DanmakuManager danmakuManager;
    private LiveModel liveModel;

    // java调用flutter
    BinaryMessenger binaryMessenger = FlutterManager.getInstance().getFlutterEngine().getDartExecutor().getBinaryMessenger();
    MethodChannel methodChannel = new MethodChannel(binaryMessenger, "flutterInvoker");

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

        // 开始更新播放进度
        startProgressUpdate();
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
        playPauseButton = findViewById(R.id.btn_play_pause);
        seekBar = findViewById(R.id.seek_bar);
        tvCurrentTime = findViewById(R.id.tv_current_time);
        tvTotalTime = findViewById(R.id.tv_total_time);
        btnVolume = findViewById(R.id.btn_volume);
        btnFullscreen = findViewById(R.id.btn_fullscreen);
        btnBack = findViewById(R.id.btn_back);
        btnMore = findViewById(R.id.btn_more);

        // 初始隐藏控制栏，通过触摸等交互显示
        findViewById(R.id.top_control_bar).setVisibility(View.GONE);
        findViewById(R.id.bottom_control_bar).setVisibility(View.GONE);

        // 进度条相关设置
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser) {
                    long newPosition = (long) (progress * (double) player.getDuration() / 100);
                    player.seekTo(newPosition);
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        });

        // 获得DanmakuManager单例
        danmakuManager = DanmakuManager.getInstance();

        // 设置一个FrameLayout为弹幕容器
        FrameLayout container = findViewById(R.id.container);
        danmakuManager.init(this, container);
        danmakuManager.getConfig().setLineHeight(50);
        danmakuManager.getConfig().setMaxScrollLine(100);
    }

    private void initExoPlayer() {
        // 创建默认的数据源工厂，用于获取视频数据，这里设置用户代理为应用包名
        HttpDataSource.Factory factory = new DefaultHttpDataSource.Factory().setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43");
        factory.setDefaultRequestProperties(liveModel.getRequestHeader());
        // http://pull-l3.douyincdn.com/stage/stream-404639878568214610_sd.m3u8?auth_key=1735241248-0-0-85b22a5b6742156b84d5f894bfc4c5e1&major_anchor_level=common
        // 创建媒体源，对于HTTP-FLV格式使用ProgressiveMediaSource
        String videoUrl = "";
        if (liveModel != null && !liveModel.isPlayEmpty()) {
            videoUrl = liveModel.getPlayUrls().get(liveModel.getPlayUrls().size() - 1);
        }
        
        MediaItem mediaItem = MediaItem.fromUri(videoUrl);
        BaseMediaSource mediaSource;
        if (videoUrl.contains(".m3u8")) {
            mediaSource = new HlsMediaSource.Factory(factory).createMediaSource(mediaItem);
        } else {
            mediaSource = new ProgressiveMediaSource.Factory(factory).createMediaSource(mediaItem);
        }

        // 创建ExoPlayer实例
        player = new SimpleExoPlayer.Builder(this).build();

        // 设置媒体源到ExoPlayer
        player.setMediaSource(mediaSource);

        // 关联ExoPlayer与PlayerView
        playerView.setPlayer(player);

        // 添加事件监听器
        player.addListener(this);

        // 准备播放
        player.prepare();

        // 自动开始播放
        player.setPlayWhenReady(true);
    }

    private void setButtonClickListeners() {
        playPauseButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (isPlaying) {
                    player.pause();
                    playPauseButton.setImageResource(R.drawable.launch_background);
                } else {
                    player.play();
                    playPauseButton.setImageResource(R.drawable.launch_background);
                }
                isPlaying =!isPlaying;
            }
        });

        btnFullscreen.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (!isFullscreen) {
                    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
                    isFullscreen = true;
                    btnFullscreen.setImageResource(R.drawable.launch_background);
                } else {
                    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                    isFullscreen = false;
                    btnFullscreen.setImageResource(R.drawable.launch_background);
                }
            }
        });

        btnVolume.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // 这里可以添加具体的音量调节逻辑，比如弹出音量调节对话框等
                Toast.makeText(HomeActivity.this, "音量调节功能待完善", Toast.LENGTH_SHORT).show();
            }
        });

        btnBack.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                onBackPressed();
            }
        });

        btnMore.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // 这里可以弹出更多功能菜单，比如画质切换等功能
                Toast.makeText(HomeActivity.this, "更多功能待完善", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void startProgressUpdate() {
        updateProgressRunnable = new Runnable() {
            @Override
            public void run() {
                if (player!= null && player.getDuration() > 0) {
                    long currentPosition = player.getCurrentPosition();
                    long totalDuration = player.getDuration();
                    int progress = (int) (currentPosition * 100 / totalDuration);
                    seekBar.setProgress(progress);
                    tvCurrentTime.setText(formatTime(currentPosition));
                    tvTotalTime.setText(formatTime(totalDuration));
                }
                handler.postDelayed(this, 1000);
            }
        };
        handler.post(updateProgressRunnable);
    }

    private String formatTime(long millis) {
        return String.format(Locale.CHINA, "%02d:%02d",
                TimeUnit.MILLISECONDS.toMinutes(millis),
                TimeUnit.MILLISECONDS.toSeconds(millis) - TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(millis)));
    }

    @Override
    public void onPlayerStateChanged(boolean playWhenReady, int playbackState) {
        if (playbackState == Player.STATE_READY) {
            if (playWhenReady) {
                isPlaying = true;
                playPauseButton.setImageResource(R.drawable.launch_background);
            } else {
                isPlaying = false;
                playPauseButton.setImageResource(R.drawable.launch_background);
            }
        } else if (playbackState == Player.STATE_BUFFERING) {
            // 显示缓冲提示，比如加载动画等
            Toast.makeText(this, "视频正在缓冲，请稍后...", Toast.LENGTH_SHORT).show();
        } else if (playbackState == Player.STATE_ENDED) {
            // 播放结束后的处理，比如自动播放下一集（如果有）等
            Toast.makeText(this, "视频播放完毕", Toast.LENGTH_SHORT).show();
            isPlaying = false;
            playPauseButton.setImageResource(R.drawable.launch_background);
        }
    }

    @Override
    public void onPlayerError(PlaybackException error) {
        // 详细的错误处理，根据不同错误类型提示用户或者记录日志等
        Toast.makeText(this, "播放出错：" + error.getMessage(), Toast.LENGTH_LONG).show();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除进度更新任务
        handler.removeCallbacks(updateProgressRunnable);
        MessageManager.getInstance().unRegisterCallback(this);
        methodChannel.invokeMethod("onDestroy", null);
        // 释放ExoPlayer资源
        if (player!= null) {
            player.release();
        }
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
        Bundle bundle = message.getData();
        if (bundle == null) {
            return false;
        }

        String type = bundle.getString("type");
        String msg = bundle.getString("message");
        Log.w("Test", "onDanmaku: [" + type + "] " + msg);
        if (type == null || msg == null) {
            return false;
        }

        // 发送弹幕
        Danmaku danmaku = new Danmaku();
        danmaku.text = msg;
        danmaku.size = 42;
        danmakuManager.send(danmaku);

        return true;
    }

    @Override
    protected void onResume() {
        super.onResume();
        methodChannel.invokeMethod("onResume", null);
    }

    @Override
    protected void onPause() {
        super.onPause();
        methodChannel.invokeMethod("onPause", null);
    }
}
