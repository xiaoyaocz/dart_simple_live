package com.bgylde.live.danmaku.danmaku;

import android.view.ViewGroup;

import java.util.ArrayList;
import java.util.List;

/**
 * 用于计算弹幕位置，来保证弹幕不重叠又不浪费空间。
 */
class DanmakuPositionCalculator {
    private static final String TAG = "DanPositionCalculator";
    private DanmakuManager mDanmakuManager;
    private List<DanmakuView> mLastDanmakus = new ArrayList<>();// 保存每一行最后一个弹幕消失的时间
    private boolean[] mTops;
    private boolean[] mBottoms;

    DanmakuPositionCalculator(DanmakuManager danmakuManager) {
        mDanmakuManager = danmakuManager;

        int maxLine = danmakuManager.getConfig().getMaxDanmakuLine();
        mTops = new boolean[maxLine];
        mBottoms = new boolean[maxLine];
    }

    private int getLineHeightWithPadding() {
        return (int) (1.35f * mDanmakuManager.getConfig().getLineHeight());
    }

    int getMarginTop(DanmakuView view) {
        switch (view.getDanmaku().mode) {
            case scroll:
                return getScrollY(view);
            case top:
                return getTopY(view);
            case bottom:
                return getBottomY(view);
        }
        return -1;
    }

    private int getScrollY(DanmakuView view) {
        if (mLastDanmakus.size() == 0) {
            mLastDanmakus.add(view);
            return 0;
        }

        int i;
        for (i = 0; i < mLastDanmakus.size(); i++) {
            DanmakuView last = mLastDanmakus.get(i);
            int timeDisappear = calTimeDisappear(last); // 最后一条弹幕还需多久消失
            int timeArrive = calTimeArrive(view); // 这条弹幕需要多久到达屏幕边缘
            boolean isFullyShown = isFullyShown(last);
//            EasyL.d(TAG, "getScrollY: 行: " + i + ", 消失时间: " + timeDisappear + ", 到达时间: " + timeArrive + ", 行高: " + lineHeight);
            if (timeDisappear <= timeArrive && isFullyShown) {
                // 如果最后一个弹幕在这个弹幕到达之前消失，并且最后一个字已经显示完毕，
                // 那么新的弹幕就可以在这一行显示
                mLastDanmakus.set(i, view);
                return i * getLineHeightWithPadding();
            }
        }
        int maxLine = mDanmakuManager.getConfig().getMaxDanmakuLine();
        if (maxLine == 0 || i < maxLine) {
            mLastDanmakus.add(view);
            return i * getLineHeightWithPadding();
        }

        return -1;
    }

    private int getTopY(DanmakuView view) {
        for (int i = 0; i < mTops.length; i++) {
            boolean isShowing = mTops[i];
            if (!isShowing) {
                final int finalI = i;
                mTops[finalI] = true;
                view.addOnExitListener(view1 -> mTops[finalI] = false);
                return i * getLineHeightWithPadding();
            }
        }
        return -1;
    }

    private int getBottomY(DanmakuView view) {
        for (int i = 0; i < mBottoms.length; i++) {
            boolean isShowing = mBottoms[i];
            if (!isShowing) {
                final int finalI = i;
                mBottoms[finalI] = true;
                view.addOnExitListener(view1 -> mBottoms[finalI] = false);
                return getParentHeight() - (i + 1) * getLineHeightWithPadding();
            }
        }
        return -1;
    }

    /**
     * 这条弹幕是否已经全部出来了。如果没有的话，
     * 后面的弹幕不能出来，否则就重叠了。
     */
    private boolean isFullyShown(DanmakuView view) {
        if (view == null) {
            return true;
        }
        int scrollX = view.getScrollX();
        int textLength = view.getTextLength();
        return textLength - scrollX < getParentWidth();
    }

    /**
     * 这条弹幕还有多少毫秒彻底消失。
     */
    private int calTimeDisappear(DanmakuView view) {
        if (view == null) {
            return 0;
        }
        float speed = calSpeed(view);
        int scrollX = view.getScrollX();
        int textLength = view.getTextLength();
        int wayToGo = textLength - scrollX;

        return (int) (wayToGo / speed);
    }

    /**
     * 这条弹幕还要多少毫秒抵达屏幕边缘。
     */
    private int calTimeArrive(DanmakuView view) {
        float speed = calSpeed(view);
        int wayToGo = getParentWidth();
        return (int) (wayToGo / speed);
    }

    /**
     * 这条弹幕的速度。单位：px/ms
     */
    private float calSpeed(DanmakuView view) {
        int textLength = view.getTextLength();
        int width = getParentWidth();
        float s = textLength + width + 0.0f;
        int t = mDanmakuManager.getDisplayDuration(view.getDanmaku());

        return s / t;
    }

    private int getParentHeight() {
        ViewGroup parent = mDanmakuManager.mDanmakuContainer.get();
        if (parent == null || parent.getHeight() == 0) {
            return 1080;
        }
        return parent.getHeight();
    }

    private int getParentWidth() {
        ViewGroup parent = mDanmakuManager.mDanmakuContainer.get();
        if (parent == null || parent.getWidth() == 0) {
            return 1920;
        }
        return parent.getWidth();
    }

}
