package com.bgylde.live.danmaku.danmaku;

import android.content.Context;
import android.graphics.Color;
import android.util.TypedValue;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.bgylde.live.core.LogUtils;
import com.bgylde.live.danmaku.utils.ScreenUtil;

import java.lang.ref.WeakReference;

/**
 * 用法示例：
 * DanmakuManager dm = DanmakuManager.getInstance();
 * dm.init(getContext());
 * dm.show(new Danmaku("test"));
 * <p>
 * Created by LittleFogCat.
 */
@SuppressWarnings("unused")
public class DanmakuManager {
    private static final String TAG = DanmakuManager.class.getSimpleName();
    private static final int RESULT_OK = 0;
    private static final int RESULT_NULL_ROOT_VIEW = 1;
    private static final int RESULT_FULL_POOL = 2;
    private static final int TOO_MANY_DANMAKU = 2;

    private static DanmakuManager sInstance;

    /**
     * 弹幕容器
     */
    WeakReference<FrameLayout> mDanmakuContainer;
    /**
     * 弹幕池
     */
    private Pool<DanmakuView> mDanmakuViewPool;

    private Config mConfig;

    private DanmakuPositionCalculator mPositionCal;

    private DanmakuManager() {
    }

    public static DanmakuManager getInstance() {
        if (sInstance == null) {
            sInstance = new DanmakuManager();
        }
        return sInstance;
    }

    /**
     * 初始化。在使用之前必须调用该方法。
     */
    public void init(Context context, FrameLayout container) {
        if (mDanmakuViewPool == null) {
            mDanmakuViewPool = new CachedDanmakuViewPool(
                    60000, // 缓存存活时间：60秒
                    100, // 最大弹幕数：100
                    () -> DanmakuViewFactory.createDanmakuView(context, container));
        }
        setDanmakuContainer(container);
        ScreenUtil.init(context);

        mConfig = new Config();
        mPositionCal = new DanmakuPositionCalculator(this);
    }

    public Config getConfig() {
        if (mConfig == null) {
            mConfig = new Config();
        }
        return mConfig;
    }

    private DanmakuPositionCalculator getPositionCalculator() {
        if (mPositionCal == null) {
            mPositionCal = new DanmakuPositionCalculator(this);
        }
        return mPositionCal;
    }

    public void setDanmakuViewPool(Pool<DanmakuView> pool) {
        if (mDanmakuViewPool != null) {
            mDanmakuViewPool.release();
        }
        mDanmakuViewPool = pool;
    }

    /**
     * 设置允许同时出现最多的弹幕数，如果屏幕上显示的弹幕数超过该数量，那么新出现的弹幕将被丢弃，
     * 直到有旧的弹幕消失。
     *
     * @param max 同时出现的最多弹幕数，-1无限制
     */
    public void setMaxDanmakuSize(int max) {
        if (mDanmakuViewPool == null) {
            return;
        }
        mDanmakuViewPool.setMaxSize(max);
    }

    /**
     * 设置弹幕的容器，所有的弹幕都在这里面显示
     */
    public void setDanmakuContainer(final FrameLayout root) {
        if (root == null) {
            throw new NullPointerException("Danmaku container cannot be null!");
        }
        mDanmakuContainer = new WeakReference<>(root);
    }

    /**
     * 发送一条弹幕
     */
    public int send(Danmaku danmaku) {
        if (mDanmakuViewPool == null) {
            throw new NullPointerException("Danmaku view pool is null. Did you call init() first?");
        }

        DanmakuView view = mDanmakuViewPool.get();

        if (view == null) {
            LogUtils.w(TAG, "show: Too many danmaku, discard");
            return RESULT_FULL_POOL;
        }
        if (mDanmakuContainer == null || mDanmakuContainer.get() == null) {
            LogUtils.w(TAG, "show: Root view is null.");
            return RESULT_NULL_ROOT_VIEW;
        }

        view.setDanmaku(danmaku);

        // 字体大小
        int textSize = danmaku.size;
        view.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSize);

        // 字体颜色
        try {
            int color = Color.parseColor(danmaku.color);
            view.setTextColor(color);
        } catch (Exception e) {
            e.printStackTrace();
            view.setTextColor(Color.WHITE);
        }

        // 计算弹幕距离顶部的位置
        DanmakuPositionCalculator dpc = getPositionCalculator();
        int marginTop = dpc.getMarginTop(view);

        if (marginTop == -1) {
            // 屏幕放不下了
            LogUtils.d(TAG, "send: screen is full, too many danmaku [" + danmaku + "]");
            return TOO_MANY_DANMAKU;
        }
        FrameLayout.LayoutParams p = (FrameLayout.LayoutParams) view.getLayoutParams();
        if (p == null) {
            p = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        }
        p.topMargin = marginTop;
        view.setLayoutParams(p);
        view.setMinHeight((int) (getConfig().getLineHeight() * 1.35));
        view.show(mDanmakuContainer.get(), getDisplayDuration(danmaku));
        return RESULT_OK;
    }

    /**
     * @return 返回这个弹幕显示时长
     */
    int getDisplayDuration(Danmaku danmaku) {
        Config config = getConfig();
        int duration;
        switch (danmaku.mode) {
            case top:
                duration = config.getDurationTop();
                break;
            case bottom:
                duration = config.getDurationBottom();
                break;
            case scroll:
            default:
                duration = config.getDurationScroll();
                break;
        }
        return duration;
    }

    /**
     * 一些配置
     */
    public static class Config {

        /**
         * 行高，单位px
         */
        private int lineHeight;

        /**
         * 滚动弹幕显示时长
         */
        private int durationScroll;
        /**
         * 顶部弹幕显示时长
         */
        private int durationTop;
        /**
         * 底部弹幕的显示时长
         */
        private int durationBottom;

        /**
         * 滚动弹幕的最大行数
         */
        private int maxScrollLine;

        public int getLineHeight() {
            return lineHeight;
        }

        public void setLineHeight(int lineHeight) {
            this.lineHeight = lineHeight;
        }

        public int getMaxScrollLine() {
            return maxScrollLine;
        }

        public int getDurationScroll() {
            if (durationScroll == 0) {
                durationScroll = 10000;
            }
            return durationScroll;
        }

        public void setDurationScroll(int durationScroll) {
            this.durationScroll = durationScroll;
        }

        public int getDurationTop() {
            if (durationTop == 0) {
                durationTop = 5000;
            }
            return durationTop;
        }

        public void setDurationTop(int durationTop) {
            this.durationTop = durationTop;
        }

        public int getDurationBottom() {
            if (durationBottom == 0) {
                durationBottom = 5000;
            }
            return durationBottom;
        }

        public void setDurationBottom(int durationBottom) {
            this.durationBottom = durationBottom;
        }

        public int getMaxDanmakuLine() {
            if (maxScrollLine == 0) {
                maxScrollLine = 12;
            }
            return maxScrollLine;
        }

        public void setMaxScrollLine(int maxScrollLine) {
            this.maxScrollLine = maxScrollLine;
        }
    }

}
