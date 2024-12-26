package com.bgylde.live.danmaku;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.text.TextPaint;
import android.util.AttributeSet;
import android.view.Gravity;
import android.view.ViewGroup;
import android.view.animation.LinearInterpolator;
import android.widget.Scroller;

import androidx.appcompat.widget.AppCompatTextView;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * DanmakuView的基类，继承自TextView，一个弹幕对应一个DanmakuView。
 * 这里实现了一些通用的功能。
 * <p>
 * Created by LittleFogCat.
 */
@SuppressWarnings("unused")
public class DanmakuView extends AppCompatTextView {

    /**
     * 弹幕内容
     */
    private Danmaku mDanmaku;

    /**
     * 监听
     */
    private ListenerInfo mListenerInfo;

    private static class ListenerInfo {
        private ArrayList<OnEnterListener> mOnEnterListeners;

        private List<OnExitListener> mOnExitListener;
    }

    /**
     * 弹幕进场时的监听
     */
    public interface OnEnterListener {
        void onEnter(DanmakuView view);
    }

    /**
     * 弹幕离场后的监听
     */
    public interface OnExitListener {
        void onExit(DanmakuView view);
    }

    /**
     * 显示时长 ms
     */
    private int mDuration;

    public DanmakuView(Context context) {
        super(context);
    }

    public DanmakuView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public DanmakuView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    /**
     * 设置弹幕内容
     */
    public void setDanmaku(Danmaku danmaku) {
        mDanmaku = danmaku;
        setText(danmaku.text);
        switch (danmaku.mode) {
            case top:
            case bottom:
                setGravity(Gravity.CENTER);
                break;
            case scroll:
            default:
                setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
                break;
        }
    }

    public Danmaku getDanmaku() {
        return mDanmaku;
    }

    /**
     * 显示弹幕
     */
    public void show(final ViewGroup parent, int duration) {
        mDuration = duration;
        switch (mDanmaku.mode) {
            case top:
            case bottom:
                showFixedDanmaku(parent, duration);
                break;
            case scroll:
            default:
                showScrollDanmaku(parent, duration);
                break;
        }

        if (hasOnEnterListener()) {
            for (OnEnterListener listener : getListenerInfo().mOnEnterListeners) {
                listener.onEnter(this);
            }
        }
        postDelayed(() -> {
            setVisibility(GONE);
            if (hasOnExitListener()) {
                for (OnExitListener listener : getListenerInfo().mOnExitListener) {
                    listener.onExit(DanmakuView.this);
                }
            }
            parent.removeView(DanmakuView.this);
        }, duration);
    }

    private void showScrollDanmaku(ViewGroup parent, int duration) {
        int screenWidth = ScreenUtil.getScreenWidth();
        int textLength = getTextLength();
        scrollTo(-screenWidth, 0);
        parent.addView(this);
        smoothScrollTo(textLength, 0, duration);
    }

    private void showFixedDanmaku(ViewGroup parent, int duration) {
        setGravity(Gravity.CENTER);
        parent.addView(this);
    }

    private ListenerInfo getListenerInfo() {
        if (mListenerInfo == null) {
            mListenerInfo = new ListenerInfo();
        }
        return mListenerInfo;
    }

    public void addOnEnterListener(OnEnterListener l) {
        ListenerInfo li = getListenerInfo();
        if (li.mOnEnterListeners == null) {
            li.mOnEnterListeners = new ArrayList<>();
        }
        if (!li.mOnEnterListeners.contains(l)) {
            li.mOnEnterListeners.add(l);
        }
    }

    public void clearOnEnterListeners() {
        ListenerInfo li = getListenerInfo();
        if (li.mOnEnterListeners == null || li.mOnEnterListeners.isEmpty()) {
            return;
        }
        li.mOnEnterListeners.clear();
    }

    public void addOnExitListener(OnExitListener l) {
        ListenerInfo li = getListenerInfo();
        if (li.mOnExitListener == null) {
            li.mOnExitListener = new CopyOnWriteArrayList<>();
        }
        if (!li.mOnExitListener.contains(l)) {
            li.mOnExitListener.add(l);
        }
    }

    public void clearOnExitListeners() {
        ListenerInfo li = getListenerInfo();
        if (li.mOnExitListener == null || li.mOnExitListener.isEmpty()) {
            return;
        }
        li.mOnExitListener.clear();
    }

    public boolean hasOnEnterListener() {
        ListenerInfo li = getListenerInfo();
        return li.mOnEnterListeners != null && !li.mOnEnterListeners.isEmpty();
    }

    public boolean hasOnExitListener() {
        ListenerInfo li = getListenerInfo();
        return li.mOnExitListener != null && !li.mOnExitListener.isEmpty();
    }

    public int getTextLength() {
        return (int) getPaint().measureText(getText().toString());
    }

    public int getDuration() {
        return mDuration;
    }

    /**
     * 恢复初始状态
     */
    public void restore() {
        clearOnEnterListeners();
        clearOnExitListeners();
        setVisibility(VISIBLE);
        setScrollX(0);
        setScrollY(0);
    }

    private Scroller mScroller;

    public void smoothScrollTo(int x, int y, int duration) {
        if (mScroller == null) {
            mScroller = new Scroller(getContext(), new LinearInterpolator());
            setScroller(mScroller);
        }

        int sx = getScrollX();
        int sy = getScrollY();
        mScroller.startScroll(sx, sy, x - sx, y - sy, duration);
    }

    @Override
    public void computeScroll() {
        if (mScroller != null && mScroller.computeScrollOffset()) {
//            EasyL.v(TAG, "computeScroll: " + mScroller.getCurrX());
            scrollTo(mScroller.getCurrX(), mScroller.getCurrY());
            postInvalidate();
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        if (mDanmaku.strokeWidth <= 0) {
            super.onDraw(canvas);
            return;
        }

        TextPaint wkPaint = getLayout().getPaint();
        int preColor = wkPaint.getColor();
        Paint.Style prePaintStyle = wkPaint.getStyle();
        // apply stroke paint
        wkPaint.setColor(mDanmaku.strokeColor);
        wkPaint.setStrokeWidth(mDanmaku.strokeWidth);
        wkPaint.setStyle(Paint.Style.STROKE);
        // draw text outline
        getLayout().draw(canvas);

        // restore paint
        wkPaint.setColor(preColor);
        wkPaint.setStrokeWidth(0);
        wkPaint.setStyle(prePaintStyle);
        super.onDraw(canvas);
    }

    void callExitListener() {
        for (OnExitListener listener : getListenerInfo().mOnExitListener) {
            listener.onExit(this);
        }
    }
}
