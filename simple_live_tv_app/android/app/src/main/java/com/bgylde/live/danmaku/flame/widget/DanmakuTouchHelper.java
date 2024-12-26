package com.bgylde.live.danmaku.flame.widget;

import android.graphics.RectF;
import android.view.MotionEvent;

import com.bgylde.live.danmaku.flame.controller.IDanmakuView;
import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.IDanmakuIterator;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.model.android.Danmakus;

/**
 * Created by kmfish on 2015/1/25.
 */
public class DanmakuTouchHelper {

    private IDanmakuView danmakuView;
    private RectF mDanmakuBounds;

    private DanmakuTouchHelper(IDanmakuView danmakuView) {
        this.danmakuView = danmakuView;
        this.mDanmakuBounds = new RectF();
    }

    public static synchronized DanmakuTouchHelper instance(IDanmakuView danmakuView) {
        return new DanmakuTouchHelper(danmakuView);
    }

    public boolean onTouchEvent(MotionEvent event) {
        switch (event.getAction()) {
            case MotionEvent.ACTION_UP:
                IDanmakus clickDanmakus = touchHitDanmaku(event.getX(), event.getY());
                BaseDanmaku newestDanmaku = null;
                if (null != clickDanmakus && !clickDanmakus.isEmpty()) {
                    performClick(clickDanmakus);
                    newestDanmaku = fetchLatestOne(clickDanmakus);
                }

                if (null != newestDanmaku) {
                    performClickWithlatest(newestDanmaku);
                }
                break;
            default:
                break;
        }

        return false;
    }

    private void performClickWithlatest(BaseDanmaku newest) {
        if (danmakuView.getOnDanmakuClickListener() != null) {
            danmakuView.getOnDanmakuClickListener().onDanmakuClick(newest);
        }
    }

    private void performClick(IDanmakus danmakus) {
        if (danmakuView.getOnDanmakuClickListener() != null) {
            danmakuView.getOnDanmakuClickListener().onDanmakuClick(danmakus);
        }
    }

    private IDanmakus touchHitDanmaku(float x, float y) {
        IDanmakus hitDanmakus = new Danmakus();
        mDanmakuBounds.setEmpty();

        IDanmakus danmakus = danmakuView.getCurrentVisibleDanmakus();
        if (null != danmakus && !danmakus.isEmpty()) {
            IDanmakuIterator iterator = danmakus.iterator();
            while (iterator.hasNext()) {
                BaseDanmaku danmaku = iterator.next();
                if (null != danmaku) {
                    mDanmakuBounds.set(danmaku.getLeft(), danmaku.getTop(), danmaku.getRight(), danmaku.getBottom());
                    if (mDanmakuBounds.contains(x, y)) {
                        hitDanmakus.addItem(danmaku);
                    }
                }
            }
        }

        return hitDanmakus;
    }

    private BaseDanmaku fetchLatestOne(IDanmakus danmakus) {
        if (danmakus.isEmpty()) {
            return null;
        }

        return danmakus.last();
    }

}
