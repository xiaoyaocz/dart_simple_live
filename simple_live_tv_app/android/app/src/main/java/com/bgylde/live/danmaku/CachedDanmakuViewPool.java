package com.bgylde.live.danmaku;

import com.bgylde.live.core.LogUtils;

import java.util.LinkedList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * 一个简化版的DanmakuViewPool
 */
public class CachedDanmakuViewPool implements Pool<DanmakuView> {
    private static final String TAG = "CachedDanmakuViewPool";

    /**
     * 缓存DanmakuView队列。显示已经完毕的DanmakuView会被添加到缓存中进行复用。
     * 在一定的时间{@link CachedDanmakuViewPool#mKeepAliveTime}过后，没有被访问到的DanmakuView会被回收。
     */
    private final LinkedList<DanmakuViewWithExpireTime> mCache = new LinkedList<>();

    /**
     * 缓存存活时间
     */
    private final long mKeepAliveTime;
    /**
     * 定时清理缓存
     */
    private final ScheduledExecutorService mChecker = Executors.newSingleThreadScheduledExecutor();
    /**
     * 创建新DanmakuView的Creator
     */
    private final ViewCreator<DanmakuView> mCreator;
    /**
     * 最大DanmakuView数量。
     * 这个数量包含了正在显示的DanmakuView和已经显示完毕进入缓存等待复用的DanmakuView之和。
     */
    private int mMaxSize;
    /**
     * 正在显示的弹幕数量。
     */
    private int mInUseSize;

    /**
     * @param creator 生成一个DanmakuView
     */
    CachedDanmakuViewPool(long keepAliveTime, int maxSize, ViewCreator<DanmakuView> creator) {
        mKeepAliveTime = keepAliveTime;
        mMaxSize = maxSize;
        mCreator = creator;
        mInUseSize = 0;

        scheduleCheckUnusedViews();
    }

    /**
     * 每隔一秒检查并清理掉空闲队列中超过一定时间没有被使用的DanmakuView
     */
    private void scheduleCheckUnusedViews() {
        mChecker.scheduleWithFixedDelay(() -> {
            long current = System.currentTimeMillis();
            while (!mCache.isEmpty()) {
                DanmakuViewWithExpireTime first = mCache.getFirst();
                if (current > first.expireTime) {
                    mCache.remove(first);
                } else {
                    break;
                }
            }
        }, 1000, 1000, TimeUnit.MILLISECONDS);
    }

    @Override
    public DanmakuView get() {
        DanmakuView view;

        if (mCache.isEmpty()) { // 缓存中没有View
            if (mInUseSize >= mMaxSize) {
                return null;
            }
            view = mCreator.create();
        } else { // 有可用的缓存，从缓存中取
            view = mCache.poll().danmakuView;
        }
        view.addOnExitListener(v -> {
            long expire = System.currentTimeMillis() + mKeepAliveTime;
            v.restore();
            DanmakuViewWithExpireTime item = new DanmakuViewWithExpireTime();
            item.danmakuView = v;
            item.expireTime = expire;
            mCache.offer(item);
            mInUseSize--;
        });
        mInUseSize++;

        return view;
    }

    @Override
    public void release() {
        mCache.clear();
    }

    /**
     * @return 使用中的DanmakuView和缓存中的DanmakuView数量之和
     */
    @Override
    public int count() {
        return mCache.size() + mInUseSize;
    }

    @Override
    public void setMaxSize(int max) {
        mMaxSize = max;
    }

    /**
     * 一个包裹类，保存一个DanmakuView和它的过期时间。
     */
    private static class DanmakuViewWithExpireTime {
        private DanmakuView danmakuView; // 缓存的DanmakuView
        private long expireTime; // 超过这个时间没有被访问的缓存将被丢弃
    }

    public interface ViewCreator<T> {
        T create();
    }

}
