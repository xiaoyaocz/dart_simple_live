package com.bgylde.live.danmaku.danmaku;

import android.content.Context;
import android.widget.FrameLayout;

import com.bgylde.live.core.LogUtils;

import java.lang.ref.WeakReference;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * DanmakuView池。
 * Created by LittleFogCat.
 *
 * @deprecated use {@link CachedDanmakuViewPool} instead
 */
@Deprecated
public class DanmakuViewPool implements Pool<DanmakuView> {

    private static final String TAG = "DanmakuViewPool";
    private Context mContext;
    private int mInUseSize = 0;// 正在使用中的View
    private int mCoreSize;// 弹幕池核心数
    private int mMaxSize;// 弹幕池最大容量
    private int mKeepAliveTime = 60000;// todo 回收
    private BlockingQueue<DanmakuView> mDanmakuQueue;// 空闲队列
    private WeakReference<FrameLayout> mContainer;

    public DanmakuViewPool(Context context) {
        this(context, 0, 100, new LinkedBlockingQueue<>(100));
    }

    public DanmakuViewPool(Context context, int coreSize, int maxSize, BlockingQueue<DanmakuView> workQueue) {
        mContext = context;
        mCoreSize = coreSize;
        mMaxSize = maxSize;
        mDanmakuQueue = workQueue;
    }

    @Override
    public void setMaxSize(int maxSize) {
        int max = maxSize == -1 || maxSize > 1000 ? 1000 : maxSize;// FIXME: 2019/3/28 无限制？这里强制小于1000
        if (max != mMaxSize) {
            mMaxSize = max;
            mDanmakuQueue = new LinkedBlockingQueue<>(max);
            System.gc();
        }
    }

    /**
     * set the danmaku container.
     *
     * @param container A FrameLayout on which all danmaku show.
     */
    public void setContainer(FrameLayout container) {
        mContainer = new WeakReference<>(container);
    }

    /**
     * 获取一个DanmakuView。
     */
    @Override
    public DanmakuView get() {
        DanmakuView view;
        if (count() < mCoreSize) {
            // 如果总弹幕量小于弹幕池核心数，直接新建
            LogUtils.i(TAG, "get: 1. 总弹幕量小于弹幕池核心数，直接新建");
            view = createView();
            mInUseSize++;
        } else if (count() <= mMaxSize) {
            // 如果总弹幕量大于弹幕池核心数，但小于最大值，那么尝试从空闲队列中取，取不到则新建
            view = mDanmakuQueue.poll();
            if (view == null) {
                LogUtils.i(TAG, "get: 2. 总弹幕量大于弹幕池核心数，空闲队列中取不到，新建；当前剩余空闲数=" + mDanmakuQueue.size());
                view = createView();
            } else {
                view.restore();
                LogUtils.i(TAG, "get: 3. 总弹幕量大于弹幕池核心数，从空闲队列取；当前剩余空闲数=" + mDanmakuQueue.size());
            }
            mInUseSize++;
        } else {
            // 如果总弹幕量超过了最大值，那么就丢弃请求，返回Null
            LogUtils.i(TAG, "get: 4. 总弹幕量超过了最大值，那么就丢弃请求，返回Null");
            return null;
        }
        view.addOnExitListener(this::recycle);
        return view;
    }

    private DanmakuView createView() {
        return mContainer == null ? DanmakuViewFactory.createDanmakuView(mContext)
                : DanmakuViewFactory.createDanmakuView(mContext, mContainer.get());
    }

    @Override
    public void release() {
        while (mDanmakuQueue.poll() != null) {
            LogUtils.i(TAG, "release: remain " + mDanmakuQueue.size());
        }
    }

    @Override
    public int count() {
        return mInUseSize + mDanmakuQueue.size();
    }

    /**
     * 当一个view显示完毕，把他回收到空闲队列中。
     *
     * @param view 显示完毕的view
     */
    private void recycle(DanmakuView view) {
        view.restore();
        mDanmakuQueue.offer(view);
        mInUseSize--;
    }
}
