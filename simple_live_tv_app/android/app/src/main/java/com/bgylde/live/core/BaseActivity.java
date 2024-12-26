package com.bgylde.live.core;

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

import com.bgylde.live.R;
import com.bgylde.live.adapter.SelectDialogAdapter;
import com.bgylde.live.core.setting.ButtonDelegate;
import com.bgylde.live.core.setting.LineDelegate;
import com.bgylde.live.core.setting.SelectDelegate;
import com.bgylde.live.danmaku.model.BaseDanmaku;
import com.bgylde.live.danmaku.model.IDisplayer;
import com.bgylde.live.danmaku.model.android.DanmakuContext;
import com.bgylde.live.danmaku.model.android.SimpleTextCacheStuffer;
import com.bgylde.live.danmaku.widget.DanmakuView;
import com.bgylde.live.model.LiveModel;
import com.bgylde.live.multitype.MultiTypeAdapter;
import com.google.gson.Gson;

import java.util.HashMap;
import java.util.List;
import java.util.Locale;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

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
    protected DanmakuView danmakuView;
    protected DanmakuContext danmakuContext;
    // 弹幕文本大小
    protected int danmakuTextSize = 40;
    // 弹幕透明度 (1-10代表10%到100%)
    protected int danmakuOpacity = 10;

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
        FlutterManager.getInstance().invokerFlutterMethod("onPause", null);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除进度更新任务
        MessageManager.getInstance().unRegisterCallback(this);
        FlutterManager.getInstance().invokerFlutterMethod("onDestroy", null);
        handler.removeCallbacksAndMessages(null);
        if (danmakuView != null) {
            danmakuView.release();
            danmakuView = null;
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
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                if (isShowControl) {
                    hideControlView();
                    return true;
                }
            } else {
                showControlView();
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
        danmakuView = findViewById(R.id.container);
        settingRecycler = findViewById(R.id.setting_recyclerview);
        multiTypeAdapter.register(SelectDelegate.SelectModel.class, new SelectDelegate());
        multiTypeAdapter.register(Boolean.class, new LineDelegate());
        multiTypeAdapter.register(ButtonDelegate.ButtonModel.class, new ButtonDelegate());
        this.settingRecycler.setLayoutManager(new LinearLayoutManager(this));
        this.settingRecycler.setAdapter(multiTypeAdapter);

        // 设置最大显示行数
        HashMap<Integer, Integer> maxLinesPair = new HashMap<>();
        // 滚动弹幕最大显示10行
        maxLinesPair.put(BaseDanmaku.TYPE_SCROLL_RL, 10);
        // 设置是否禁止重叠
        HashMap<Integer, Boolean> overlappingEnablePair = new HashMap<>();
        overlappingEnablePair.put(BaseDanmaku.TYPE_SCROLL_RL, true);
        overlappingEnablePair.put(BaseDanmaku.TYPE_FIX_TOP, true);

        danmakuContext = DanmakuContext.create();
        danmakuContext.setDanmakuStyle(IDisplayer.DANMAKU_STYLE_STROKEN, 3)
                .setDuplicateMergingEnabled(false)
                .setScrollSpeedFactor(1.2f)
                .setScaleTextSize(1.2f)
                .setDuplicateMergingEnabled(false)
                .setCacheStuffer(new SimpleTextCacheStuffer(), null)
                .setMaximumLines(maxLinesPair)
                .preventOverlapping(overlappingEnablePair);
        DanmakuInstance danmakuInstance = new DanmakuInstance(danmakuView);
        danmakuView.setCallback(danmakuInstance);
        danmakuView.prepare(danmakuInstance, danmakuContext);
        danmakuView.showFPS(false);
        danmakuView.enableDanmakuDrawingCache(true);
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
    }

    @CallSuper
    protected void setButtonClickListeners() {
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
                if (!danmakuSwitch) {
                    return true;
                }

                String info = model.getMethodCall().argument("message");
                String color = model.getMethodCall().argument("color");
                // 发送弹幕
                BaseDanmaku danmaku = danmakuContext.mDanmakuFactory.createDanmaku(BaseDanmaku.TYPE_SCROLL_RL, danmakuContext);
                danmaku.text = info;
                danmaku.padding = 5;
                danmaku.priority = 1;  // 0 表示可能会被各种过滤器过滤并隐藏显示 //1 表示一定会显示, 一般用于本机发送的弹幕
                danmaku.isLive = true; // 是否是直播弹幕
                danmaku.time = danmakuView.getCurrentTime(); // 显示时间
                danmaku.textSize = danmakuTextSize;
                danmaku.textColor = getColor(color);
                danmaku.textShadowColor = Color.BLACK; // 阴影/描边颜色
                danmaku.borderColor = 0; // 边框颜色，0表示无边框
                danmakuView.addDanmaku(danmaku);
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
        ButtonDelegate.ButtonModel settingTitle = new ButtonDelegate.ButtonModel("设置", "刷新", new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                FlutterManager.getInstance().invokerFlutterMethod("refresh", null);
            }
        });
        SelectDelegate.SelectModel followSetting = new SelectDelegate.SelectModel("关注用户", List.of("是", "否"), liveModel.isFollowed() ? 0 : 1, new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                boolean result = pos == 0;
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

            @Override
            public String getDisplay(String val) {
                return val;
            }
        });

        SelectDelegate.SelectModel clarityAndLine = new SelectDelegate.SelectModel("清晰度与线路", null, -1, null);
        SelectDelegate.SelectModel claritySelect = new SelectDelegate.SelectModel("清晰度", liveModel.getQualites(), liveModel.getCurrentQuality(), new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                liveModel.setCurrentQuality(pos);
                FlutterManager.getInstance().invokerFlutterMethod("changeQuality", pos);
            }

            @Override
            public String getDisplay(String val) {
                return val;
            }
        });

        SelectDelegate.SelectModel lineSelect = new SelectDelegate.SelectModel("线路", liveModel.getPlayUrls(), liveModel.getCurrentLineIndex(), new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                liveModel.setCurrentLineIndex(pos);
                FlutterManager.getInstance().invokerFlutterMethod("changeLine", pos);
                prepareToPlay();
            }

            @Override
            public String getDisplay(String val) {
                return "线路" + (liveModel.getPlayUrls().indexOf(val) + 1);
            }
        });

        SelectDelegate.SelectModel danmaku = new SelectDelegate.SelectModel("弹幕", null, -1, null);
        SelectDelegate.SelectModel danmakuStatus = new SelectDelegate.SelectModel("弹幕开关", List.of("开", "关"), danmakuSwitch ? 0 : 1, new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                danmakuSwitch = (pos == 0);
            }

            @Override
            public String getDisplay(String val) {
                return val;
            }
        });

        List<String> dataList = List.of("20", "30", "40", "50", "60", "70", "80");
        SelectDelegate.SelectModel danmakuSize = new SelectDelegate.SelectModel("弹幕大小", dataList, dataList.indexOf(String.valueOf(danmakuTextSize)), new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                danmakuTextSize = Integer.parseInt(dataList.get(pos));
            }

            @Override
            public String getDisplay(String val) {
                return val;
            }
        });

        List<String> opacityList = List.of("10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%");
        SelectDelegate.SelectModel danmakuOpacitySetting = new SelectDelegate.SelectModel("不透明度", opacityList, danmakuOpacity - 1, new SelectDialogAdapter.SelectDialogInterface<String>() {
            @Override
            public void click(String value, int pos) {
                danmakuOpacity = pos + 1;
            }

            @Override
            public String getDisplay(String val) {
                return val;
            }
        });

        return List.of(settingTitle, true, followSetting, true, clarityAndLine, claritySelect, lineSelect, true, danmaku, danmakuStatus, danmakuSize, danmakuOpacitySetting);
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
