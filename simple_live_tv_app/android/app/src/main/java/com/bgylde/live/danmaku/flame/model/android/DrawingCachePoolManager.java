
package com.bgylde.live.danmaku.flame.model.android;

import com.bgylde.live.danmaku.flame.model.objectpool.PoolableManager;

public class DrawingCachePoolManager implements PoolableManager<DrawingCache> {

    @Override
    public DrawingCache newInstance() {
        return null;
    }

    @Override
    public void onAcquired(DrawingCache element) {

    }

    @Override
    public void onReleased(DrawingCache element) {

    }

}
