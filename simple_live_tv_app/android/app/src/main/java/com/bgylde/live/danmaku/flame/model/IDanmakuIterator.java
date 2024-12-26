package com.bgylde.live.danmaku.flame.model;

public interface IDanmakuIterator {

    public BaseDanmaku next();
    
    public boolean hasNext();
    
    public void reset();

    public void remove();
    
}
