package com.bgylde.live.activitys;

import android.content.pm.ActivityInfo;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.ijk.widget.VideoHolder;
import androidx.ijk.widget.VideoView;

import com.bgylde.live.R;
import com.bgylde.live.adapter.SelectDialogAdapter;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.MessageManager;
import com.bgylde.live.core.MethodCallModel;
import com.bgylde.live.model.LiveModel;
import com.bgylde.live.player.VideoPlayerListener;
import com.bgylde.live.widgets.SelectDialog;

import java.util.Locale;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import top.littlefogcat.danmakulib.danmaku.Danmaku;
import top.littlefogcat.danmakulib.danmaku.DanmakuManager;
import tv.danmaku.ijk.media.player.IMediaPlayer;

import static com.bgylde.live.adapter.SelectDialogAdapter.stringDiff;
import static com.bgylde.live.core.MessageManager.DEFAULT_CMD;
import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

public class IjkPlayerActivity extends AppCompatActivity implements View.OnClickListener, Handler.Callback, VideoPlayerListener {

    private TextView btnFullscreen;
    private TextView follow;
    private TextView clarity;
    private TextView line;
    private boolean isPlaying = false;
    private boolean isFullscreen = false;

    private DanmakuManager danmakuManager;
    private LiveModel liveModel;

    private VideoView playerView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_ijkplayer);
        // 先初始化数据
        initData();

        // 初始化视图组件
        initViews();

        // 初始化ExoPlayer及相关配置
        initExoPlayer();

        // 设置播放控制按钮点击事件
        setButtonClickListeners();
    }

    @Override
    protected void onStart() {
        super.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        FlutterManager.getInstance().invokerFlutterMethod("onResume", null);
    }

    @Override
    protected void onPause() {
        super.onPause();
        FlutterManager.getInstance().invokerFlutterMethod("onPause", null);
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

    private void initData() {
        MessageManager.getInstance().registerCallback(this);
        FlutterManager.getInstance().registerMethod("parseLiveUrl");
        FlutterManager.getInstance().invokerFlutterMethod("onCreate", null);
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

    private void prepareToPlay() {
        line.setText(String.format(Locale.CHINA, "线路%d", liveModel.getCurrentLineIndex() + 1));
        clarity.setText(liveModel.getClarity());
        follow.setText(liveModel.isFollowed() ? R.string.followed : R.string.unfollowed);

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
            playerView.setDataSource(Uri.parse(videoUrl), liveModel.getRequestHeader());
            playerView.start();
        } else {
            playerView.reset();
            playerView.setDataSource(Uri.parse(videoUrl), liveModel.getRequestHeader());
            playerView.prepareAsync();
        }
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
        FlutterManager.getInstance().invokerFlutterMethod("mediaError", extra);
        isPlaying = false;
    }

    @Override
    public void onVideoSizeChanged(IMediaPlayer mp, int width, int height, int sar_num, int sar_den) {
        Log.w("Test", "onVideoSizeChanged=> " + width + "x" + height);
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
            MethodCallModel model = (MethodCallModel)message.obj;
            if (message.arg1 == "stopPlay".hashCode()) {
                playerView.stop();
            } else if (message.arg1 == "parseLiveUrl".hashCode()) {
                parseLiveUrl(model.getMethodCall(), model.getResult());
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
            Toast.makeText(IjkPlayerActivity.this, "更多功能待完善", Toast.LENGTH_SHORT).show();
        }
    }

    private void parseLiveUrl(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        liveModel = new LiveModel(
                call.argument("id"),
                call.argument("roomId"),
                call.argument("name"),
                call.argument("logo"),
                call.argument("index"),
                call.argument("followed"),
                call.argument("liveUrl"),
                call.argument("qualites")
        );
        liveModel.setCurrentLineIndex(call.argument("currentLineIndex"))
                .setCurrentQuality(call.argument("currentQuality"));

        if (liveModel.getPlayUrls() != null && !liveModel.getPlayUrls().isEmpty()) {
            prepareToPlay();
            result.success(true);
            return;
        }

        result.success(false);
    }
}
