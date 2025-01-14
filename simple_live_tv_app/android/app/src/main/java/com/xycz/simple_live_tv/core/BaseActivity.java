package com.xycz.simple_live_tv.core;

import android.animation.ObjectAnimator;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.CallSuper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.adapter.SelectAdapter;
import com.xycz.simple_live_tv.core.setting.ButtonDelegate;
import com.xycz.simple_live_tv.core.setting.LineDelegate;
import com.xycz.simple_live_tv.core.setting.SelectDelegate;
import com.xycz.simple_live_tv.danmaku.DanmakuRender;
import com.xycz.simple_live_tv.model.LiveModel;
import com.xycz.simple_live_tv.multitype.MultiTypeAdapter;
import com.google.gson.Gson;
import com.kuaishou.akdanmaku.DanmakuConfig;
import com.kuaishou.akdanmaku.data.DanmakuItem;
import com.kuaishou.akdanmaku.data.DanmakuItemData;
import com.kuaishou.akdanmaku.data.DataSource;
import com.kuaishou.akdanmaku.ui.DanmakuPlayer;
import com.kuaishou.akdanmaku.ui.DanmakuView;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.xycz.simple_live_tv.core.MessageManager.FLUTTER_TO_JAVA_CMD;

/**
 * Created by wangyan on 2024/12/19
 */
public abstract class BaseActivity extends AppCompatActivity implements View.OnClickListener, Handler.Callback, Runnable {

    protected LiveModel liveModel;
    protected IVideoPlayer player;

    protected RelativeLayout playerLayout;
    protected TextView liveTitle;
    protected View topControlLayout;
    protected RecyclerView settingRecycler;
    protected final MultiTypeAdapter multiTypeAdapter = new MultiTypeAdapter();

    protected long lastRequestFocusTime;
    protected boolean isPlaying = false;
    protected boolean danmakuSwitch = true;
    protected volatile boolean isShowControl = true;
    protected final Gson gson = new Gson();
    protected final Handler handler = new Handler(Looper.getMainLooper());
    protected DanmakuPlayer danmakuPlayer;
    protected DataSource dataSource;

    // 弹幕文本大小
    protected int danmakuTextSize = 40;
    // 弹幕描边宽度
    protected int danmakuStrokeWidth = 0;
    // 弹幕透明度 (1-10代表10%到100%)
    protected int danmakuOpacity = 10;
    // 弹幕是否播放
    protected boolean danmakuPlaying = true;
    // 弹幕显示方式
    protected boolean danmakuRollStyle = true;
    // 弹幕绘制类
    protected DanmakuRender danmakuRender = new DanmakuRender();
    // 双击退出页面
    protected long lastBackTime = 0;

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
        settingRecycler.post(this);
    }

    @Override
    protected void onPause() {
        super.onPause();
        danmakuPlayer.pause();
        FlutterManager.getInstance().invokerFlutterMethod("onPause", null);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除进度更新任务
        MessageManager.getInstance().unRegisterCallback(this);
        FlutterManager.getInstance().invokerFlutterMethod("onDestroy", null);
        handler.removeCallbacksAndMessages(null);
        if (danmakuPlayer != null) {
            danmakuPlayer.release();
            danmakuPlayer = null;
        }
    }

    @Override
    public void onBackPressed() {
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastBackTime < 3000) {
            super.onBackPressed();
        } else {
            Toast.makeText(this, "再按一次退出", Toast.LENGTH_SHORT).show();
            lastBackTime = currentTime;
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        lastRequestFocusTime = System.currentTimeMillis();
        return super.onTouchEvent(event);
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
            switch (keyCode) {
                case KeyEvent.KEYCODE_BACK:
                    if (isShowControl) {
                        hideControlView();
                        return true;
                    }
                    break;
                case KeyEvent.KEYCODE_DPAD_CENTER:
                    if (isShowControl) {
                        break;
                    }

                    if (danmakuPlaying) {
                        danmakuPlaying = false;
                        danmakuPlayer.pause();
                    } else {
                        danmakuPlaying = true;
                        danmakuPlayer.start(danmakuPlayer.getConfig());
                    }
                    return true;
                case KeyEvent.KEYCODE_DPAD_RIGHT:
                case KeyEvent.KEYCODE_DPAD_LEFT:
                    showControlView();
                    return true;
            }
        }

        return super.dispatchKeyEvent(event);
    }

    @CallSuper
    protected void initViews() {
        hideSystemUI(false);
        playerLayout = findViewById(R.id.player_layout);
        liveTitle = findViewById(R.id.tv_video_title);
        topControlLayout = findViewById(R.id.top_control_bar);
        settingRecycler = findViewById(R.id.setting_recyclerview);
        multiTypeAdapter.register(SelectDelegate.SelectModel.class, new SelectDelegate());
        multiTypeAdapter.register(Boolean.class, new LineDelegate());
        multiTypeAdapter.register(ButtonDelegate.ButtonModel.class, new ButtonDelegate());
        this.settingRecycler.setLayoutManager(new LinearLayoutManager(this));
        this.settingRecycler.setAdapter(multiTypeAdapter);
        danmakuTextSize = getResources().getDimensionPixelSize(R.dimen.ds40);
        DanmakuView danmakuView = findViewById(R.id.container);
        danmakuView.setLayerType(View.LAYER_TYPE_NONE, null);
        dataSource = new DataSource();
        danmakuPlayer = new DanmakuPlayer(danmakuRender, dataSource);
        danmakuPlayer.bindView(danmakuView);
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

        this.multiTypeAdapter.setItems(buildSettingData());
        this.multiTypeAdapter.notifyDataSetChanged();
        if (liveModel.getRoomTitle() != null) {
            liveTitle.setText(liveModel.getRoomTitle());
        } else {
            liveTitle.setText(liveModel.getName());
        }

        DanmakuConfig danmakuConfig = danmakuPlayer.getConfig() == null ?
                new DanmakuConfig() : danmakuPlayer.getConfig();
        danmakuConfig.setAllowOverlap(false);
        danmakuConfig.setVisibility(true);
        danmakuConfig.setBold(true);
        danmakuConfig.setDurationMs(2000);
        danmakuConfig.setRollingDurationMs(4000);
        danmakuPlayer.start(danmakuConfig);
    }

    @CallSuper
    protected void setButtonClickListeners() {
        findViewById(R.id.back_layout).setOnClickListener(this);
        findViewById(R.id.more_layout).setOnClickListener(this);
        findViewById(R.id.container).setOnClickListener(this);
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
                if (!danmakuSwitch) {
                    return true;
                }

                String info = model.getMethodCall().argument("message");
                String color = model.getMethodCall().argument("color");
                if (info == null) {
                    return true;
                }

                int style = danmakuRollStyle ?
                        DanmakuItemData.DANMAKU_MODE_ROLLING :
                        (System.currentTimeMillis() % 2 == 0 ?
                                DanmakuItemData.DANMAKU_MODE_CENTER_TOP :
                                DanmakuItemData.DANMAKU_MODE_CENTER_BOTTOM);
                        // 发送弹幕
                DanmakuItemData data = new DanmakuItemData(
                        danmakuPlayer.getCurrentTimeMs(), danmakuPlayer.getCurrentTimeMs(), info,
                        style, danmakuTextSize, getColor(color),
                        1, DanmakuItemData.DANMAKU_STYLE_NONE, 1,
                        100L, DanmakuItemData.MERGED_TYPE_NORMAL);
                DanmakuItem danmakuItem = danmakuPlayer.obtainItem(data);
                danmakuRender.setStrokeWidth(danmakuStrokeWidth);
                danmakuPlayer.send(danmakuItem);
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
        if (viewId == R.id.back_layout) {
            onBackPressed();
        } else if (viewId == R.id.more_layout) {
            // 这里可以弹出更多功能菜单，比如画质切换等功能
            Toast.makeText(this, "更多功能待完善", Toast.LENGTH_SHORT).show();
        } else if (viewId == R.id.container) {
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
            result.success(true);
            prepareToPlay();
            return;
        }

        result.success(false);
    }

    protected void showControlView() {
        if (isShowControl) {
            return;
        }

        isShowControl = true;
        ObjectAnimator topAnimator = ObjectAnimator.ofFloat(topControlLayout, "translationY", -topControlLayout.getHeight(), 0);
        topAnimator.setDuration(400); // 动画时长
        topAnimator.start();

        ObjectAnimator recyclerViewAnimator = ObjectAnimator.ofFloat(settingRecycler, "translationX", settingRecycler.getWidth(), 0);
        recyclerViewAnimator.setDuration(400); // 动画时长
        recyclerViewAnimator.start();

        handler.removeCallbacks(this);
        handler.postDelayed(this, 3000);
    }

    protected void hideControlView() {
        if (!isShowControl) {
            return;
        }

        isShowControl = false;
        ObjectAnimator topAnimator = ObjectAnimator.ofFloat(topControlLayout, "translationY", 0, -topControlLayout.getHeight());
        topAnimator.setDuration(400); // 动画时长
        topAnimator.start();

        ObjectAnimator recyclerViewAnimator = ObjectAnimator.ofFloat(settingRecycler, "translationX", 0, settingRecycler.getWidth());
        recyclerViewAnimator.setDuration(400); // 动画时长
        recyclerViewAnimator.start();
    }

    private List<Object> buildSettingData() {
        ButtonDelegate.ButtonModel settingTitle = new ButtonDelegate.ButtonModel("设置", new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                FlutterManager.getInstance().invokerFlutterMethod("refresh", null);
            }
        });

        LinkedHashMap<Boolean, String> followMap = new LinkedHashMap<>();
        followMap.put(true, "是");
        followMap.put(false, "否");
        SelectDelegate.SelectModel<Boolean> followSetting = new SelectDelegate.SelectModel<Boolean>("关注用户", followMap, liveModel.isFollowed(), new SelectAdapter.ISelectDialog<Boolean>() {
            @Override
            public void click(Boolean key, String value) {
                boolean result = key;
                if (result == liveModel.isFollowed()) {
                    return;
                }

                FlutterManager.getInstance().invokerFlutterMethod("followUser", null, new FlutterManager.Result() {
                    @Override
                    public void success(@Nullable Object result) {
                        if (result == null) {
                            return;
                        }

                        boolean followed = (boolean) result;
                        liveModel.setFollowed(followed);
                        Toast.makeText(BaseActivity.this, followed ? "关注成功!" : "取消关注成功!", Toast.LENGTH_SHORT).show();
                    }
                });
            }
        });

        SelectDelegate.SelectModel<Void> clarityAndLine = new SelectDelegate.SelectModel<Void>("清晰度与线路", null, null, null);
        LinkedHashMap<Integer, String> clarityMap = new LinkedHashMap<>();
        for (int index = 0; index < liveModel.getQualites().size(); index++) {
            String quality = liveModel.getQualites().get(index);
            clarityMap.put(index, quality);
        }
        SelectDelegate.SelectModel<Integer> claritySelect = new SelectDelegate.SelectModel<Integer>(getResources().getString(R.string.clarity), clarityMap, liveModel.getCurrentQuality(), new SelectAdapter.ISelectDialog<Integer>() {
            @Override
            public void click(Integer key, String value) {
                liveModel.setCurrentQuality(key);
                FlutterManager.getInstance().invokerFlutterMethod("changeQuality", key);
            }
        });

        LinkedHashMap<Integer, String> lineMap = new LinkedHashMap<>();
        for (int index = 0; index < liveModel.getPlayUrls().size(); index++) {
            lineMap.put(index, "线路" + (index + 1));
        }

        SelectDelegate.SelectModel<Integer> lineSelect = new SelectDelegate.SelectModel<>("线路", lineMap, liveModel.getCurrentLineIndex(), new SelectAdapter.ISelectDialog<Integer>() {
            @Override
            public void click(Integer key, String value) {
                liveModel.setCurrentLineIndex(key);
                FlutterManager.getInstance().invokerFlutterMethod("changeLine", key);
            }
        });

        SelectDelegate.SelectModel<Void> danmaku = new SelectDelegate.SelectModel<Void>("弹幕", null, null, null);
        LinkedHashMap<Boolean, String> danmakuMap = new LinkedHashMap<>();
        danmakuMap.put(true, "开");
        danmakuMap.put(false, "关");
        SelectDelegate.SelectModel<Boolean> danmakuStatus = new SelectDelegate.SelectModel<>("弹幕开关", danmakuMap, danmakuSwitch, new SelectAdapter.ISelectDialog<Boolean>() {
            @Override
            public void click(Boolean key, String value) {
                danmakuSwitch = key;
            }
        });

        LinkedHashMap<Integer, String> danmakuSizeMap = new LinkedHashMap<>();
        danmakuSizeMap.put(24, "24");
        danmakuSizeMap.put(32, "32");
        danmakuSizeMap.put(40, "40");
        danmakuSizeMap.put(48, "48");
        danmakuSizeMap.put(56, "56");
        danmakuSizeMap.put(64, "64");
        danmakuSizeMap.put(72, "72");
        SelectDelegate.SelectModel<Integer> danmakuSizeModel = new SelectDelegate.SelectModel<>("弹幕大小", danmakuSizeMap, danmakuTextSize, new SelectAdapter.ISelectDialog<Integer>() {
            @Override
            public void click(Integer key, String value) {
                danmakuTextSize = key;
            }
        });

        LinkedHashMap<Integer, String> opacityMap = new LinkedHashMap<>();
        opacityMap.put(10, "10%");
        opacityMap.put(20, "20%");
        opacityMap.put(30, "30%");
        opacityMap.put(40, "40%");
        opacityMap.put(50, "50%");
        opacityMap.put(60, "60%");
        opacityMap.put(70, "70%");
        opacityMap.put(80, "80%");
        opacityMap.put(90, "90%");
        opacityMap.put(100, "100%");
        SelectDelegate.SelectModel<Integer> danmakuOpacitySetting = new SelectDelegate.SelectModel<>("不透明度", opacityMap, danmakuOpacity, new SelectAdapter.ISelectDialog<Integer>() {
            @Override
            public void click(Integer key, String value) {
                danmakuOpacity = key;
            }
        });

        LinkedHashMap<Integer, String> strokeMap = new LinkedHashMap<>();
        strokeMap.put(0, "0");
        strokeMap.put(2, "2");
        strokeMap.put(4, "4");
        strokeMap.put(6, "6");
        strokeMap.put(8, "8");
        strokeMap.put(10, "10");
        strokeMap.put(12, "12");
        strokeMap.put(14, "14");
        strokeMap.put(16, "16");
        SelectDelegate.SelectModel<Integer> danmakuStroke = new SelectDelegate.SelectModel<>("描边宽度", strokeMap, danmakuStrokeWidth, new SelectAdapter.ISelectDialog<Integer>() {
            @Override
            public void click(Integer key, String value) {
                danmakuStrokeWidth = key;
            }
        });

        LinkedHashMap<Boolean, String> danmakuStyleMap = new LinkedHashMap<>(Map.of(false, "固定", true, "滚动"));
        danmakuStyleMap.put(true, "滚动");
        danmakuStyleMap.put(false, "固定");
        SelectDelegate.SelectModel<Boolean> danmakuStyleSetting = new SelectDelegate.SelectModel<>("显示方式", danmakuStyleMap, danmakuRollStyle, new SelectAdapter.ISelectDialog<Boolean>() {
            @Override
            public void click(Boolean key, String value) {
                danmakuRollStyle = key;
            }
        });

        return List.of(settingTitle, true, followSetting, true, clarityAndLine, claritySelect, lineSelect, true, danmaku, danmakuStatus, danmakuSizeModel, danmakuOpacitySetting, danmakuStroke, danmakuStyleSetting);
    }

    private int getColor(String colorStr) {
        int color = 0xFFFFFFFF;
        try {
            color = Color.parseColor(colorStr);
        } catch (Exception ignore) {}

        int opacity = (int) (0xFF * (danmakuOpacity * 1.0f / 10)) << 24 | 0x00FFFFFF;
        color = color & opacity;

        return color;
    }
}
