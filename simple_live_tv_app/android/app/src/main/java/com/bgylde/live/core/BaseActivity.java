package com.bgylde.live.core;

import android.animation.ObjectAnimator;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.CallSuper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.bgylde.live.R;
import com.bgylde.live.adapter.SelectDialogAdapter;
import com.bgylde.live.model.LiveModel;
import com.bgylde.live.widgets.SelectDialog;
import com.google.gson.Gson;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import top.littlefogcat.danmakulib.danmaku.Danmaku;
import top.littlefogcat.danmakulib.danmaku.DanmakuManager;

import static com.bgylde.live.adapter.SelectDialogAdapter.integerDiff;
import static com.bgylde.live.adapter.SelectDialogAdapter.stringDiff;
import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

/**
 * Created by wangyan on 2024/12/19
 */
public abstract class BaseActivity extends AppCompatActivity implements View.OnClickListener, Handler.Callback, Runnable {

    protected LiveModel liveModel;
    protected DanmakuManager danmakuManager;
    protected IVideoPlayer player;

    protected RelativeLayout playerLayout;
    protected TextView btnFullscreen;
    protected TextView follow;
    protected TextView clarity;
    protected TextView line;
    protected TextView liveTitle;
    protected View topControlLayout;
    protected View bottomControlLayout;

    protected long lastRequestFocusTime;
    protected boolean isPlaying = false;
    protected boolean isShowControl = false;
    protected final Gson gson = new Gson();
    protected final Handler handler = new Handler(Looper.getMainLooper());

    protected abstract void initExoPlayer();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_live);
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
    protected void onResume() {
        super.onResume();
        FlutterManager.getInstance().invokerFlutterMethod("onResume", null);
        bottomControlLayout.post(this);
    }

    @Override
    protected void onPause() {
        super.onPause();
        FlutterManager.getInstance().invokerFlutterMethod("onPause", null);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除进度更新任务
        MessageManager.getInstance().unRegisterCallback(this);
        FlutterManager.getInstance().invokerFlutterMethod("onDestroy", null);
        handler.removeCallbacksAndMessages(null);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event == null) {
            return super.dispatchKeyEvent(null);
        }

        int keyCode = event.getKeyCode();
        int action = event.getAction();
        lastRequestFocusTime = System.currentTimeMillis();
        if (action == KeyEvent.ACTION_UP) {
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                if (isShowControl) {
                    hideControlView();
                    return true;
                }
            } else {
                if (!isShowControl) {
                    showControlView();
                }
            }
        }

        return super.dispatchKeyEvent(event);
    }

    @CallSuper
    protected void initViews() {
        hideSystemUI(false);
        playerLayout = findViewById(R.id.player_layout);
        btnFullscreen = findViewById(R.id.btn_fullscreen);
        follow = findViewById(R.id.like);
        clarity = findViewById(R.id.clarity);
        line = findViewById(R.id.line);
        liveTitle = findViewById(R.id.tv_video_title);
        topControlLayout = findViewById(R.id.top_control_bar);
        bottomControlLayout = findViewById(R.id.bottom_control_bar);
        findViewById(R.id.back_layout).requestFocus();

        // 获得DanmakuManager单例
        danmakuManager = DanmakuManager.getInstance();

        // 设置一个FrameLayout为弹幕容器
        FrameLayout container = findViewById(R.id.container);
        danmakuManager.init(this, container);
        danmakuManager.getConfig().setLineHeight(50);
        danmakuManager.getConfig().setMaxScrollLine(100);
    }

    @CallSuper
    protected void initData() {
        MessageManager.getInstance().registerCallback(this);
        FlutterManager.getInstance().registerMethod("parseLiveUrl");
        FlutterManager.getInstance().registerMethod("stopPlay");
        FlutterManager.getInstance().registerMethod("danmaku");
        FlutterManager.getInstance().invokerFlutterMethod("onCreate", null);
    }

    @CallSuper
    public void prepareToPlay() {
        if (liveModel == null) {
            return;
        }

        line.setText(String.format(Locale.CHINA, "线路%d", liveModel.getCurrentLineIndex() + 1));
        clarity.setText(liveModel.getClarity());
        follow.setText(liveModel.isFollowed() ? R.string.followed : R.string.unfollowed);
        if (liveModel.getRoomTitle() != null) {
            liveTitle.setText(liveModel.getRoomTitle());
        } else {
            liveTitle.setText(liveModel.getName());
        }
    }

    @CallSuper
    protected void setButtonClickListeners() {
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
        findViewById(R.id.back_layout).setOnClickListener(this);
        findViewById(R.id.more_layout).setOnClickListener(this);
        findViewById(R.id.player_view).setOnClickListener(this);
    }

    @Override
    public boolean handleMessage(@NonNull Message message) {
        if (message.what == FLUTTER_TO_JAVA_CMD) {
            MethodCallModel model = (MethodCallModel)message.obj;
            if (message.arg1 == "stopPlay".hashCode()) {
                player.stop();
            } else if (message.arg1 == "parseLiveUrl".hashCode()) {
                parseLiveUrl(model.getMethodCall(), model.getResult());
            } else if (message.arg1 == "danmaku".hashCode()) {
                String type = model.getMethodCall().argument("type");
                String info = model.getMethodCall().argument("message");
                String color = model.getMethodCall().argument("color");
                // 发送弹幕
                Danmaku danmaku = new Danmaku();
                danmaku.text = info;
                danmaku.size = 42;
                danmaku.color = color;
                danmakuManager.send(danmaku);
            } else {
                return false;
            }

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
            SelectDialog<Integer> dialog = new SelectDialog<>(this);
            dialog.setTip(getString(R.string.line));
            List<Integer> dataList = new ArrayList<>(liveModel.getPlayUrls().size());
            for (int index = 1; index <= liveModel.getPlayUrls().size(); index++) {
                dataList.add(index);
            }

            dialog.setAdapter(null, new SelectDialogAdapter.SelectDialogInterface<Integer>() {
                @Override
                public void click(Integer value, int pos) {
                    try {
                        dialog.cancel();
                        liveModel.setCurrentLineIndex(pos);
                        FlutterManager.getInstance().invokerFlutterMethod("changeLine", pos);
                        prepareToPlay();
                    } catch (Exception ignore) {}
                }

                @Override
                public String getDisplay(Integer val) {
                    return "线路" + val;
                }
            }, integerDiff, dataList, liveModel.getCurrentLineIndex());
            dialog.show();
        } else if (viewId == R.id.ratio_layout) {

        } else if (viewId == R.id.danmaku_layout) {

        } else if (viewId == R.id.danmaku_size_layout) {

        } else if (viewId == R.id.danmaku_speed_layout) {

        } else if (viewId == R.id.danmaku_area_layout) {

        } else if (viewId == R.id.danmaku_opacity_layout) {

        } else if (viewId == R.id.danmaku_stroke_layout) {

        } else if (viewId == R.id.fullscreen_layout) {

        } else if (viewId == R.id.back_layout) {
            onBackPressed();
        } else if (viewId == R.id.more_layout) {
            // 这里可以弹出更多功能菜单，比如画质切换等功能
            Toast.makeText(this, "更多功能待完善", Toast.LENGTH_SHORT).show();
        } else if (viewId == R.id.player_view) {
            if (!isShowControl) {
                showControlView();
            } else {
                hideControlView();
            }
        }
    }

    @Override
    public void run() {
        if (System.currentTimeMillis() - lastRequestFocusTime > 3000) {
            hideControlView();
        } else {
            handler.postDelayed(this, 3000);
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

    protected void parseLiveUrl(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        liveModel = gson.fromJson((String) call.arguments, LiveModel.class);
        OkHttpManager.getInstance().resetRequestHeader(liveModel.getHeaderMap());
        if (liveModel.getPlayUrls() != null && !liveModel.getPlayUrls().isEmpty()) {
            prepareToPlay();
            result.success(true);
            return;
        }

        result.success(false);
    }

    protected void showControlView() {
        ObjectAnimator topAnimator = ObjectAnimator.ofFloat(topControlLayout, "translationY", -topControlLayout.getHeight(), 0);
        topAnimator.setDuration(400); // 动画时长
        topAnimator.start();

        ObjectAnimator bottomAnimator = ObjectAnimator.ofFloat(bottomControlLayout, "translationY", bottomControlLayout.getHeight(), 0);
        bottomAnimator.setDuration(400); // 动画时长
        bottomAnimator.start();
        isShowControl = true;
        handler.removeCallbacks(this);
        handler.postDelayed(this, 3000);
    }

    protected void hideControlView() {
        ObjectAnimator topAnimator = ObjectAnimator.ofFloat(topControlLayout, "translationY", 0, -topControlLayout.getHeight());
        topAnimator.setDuration(400); // 动画时长
        topAnimator.start();

        ObjectAnimator bottomAnimator = ObjectAnimator.ofFloat(bottomControlLayout, "translationY", 0, bottomControlLayout.getHeight());
        bottomAnimator.setDuration(400); // 动画时长
        bottomAnimator.start();
        isShowControl = false;
    }
}
