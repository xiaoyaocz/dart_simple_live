
package com.bgylde.live.danmaku.flame.model;

public interface IDrawingCache<T> {

    public void build(int w, int h, int density, boolean checkSizeEquals);
    
    public void erase();

    public T get();

    public void destroy();

    public int size();
    
    public int width();
    
    public int height();
    
    public boolean hasReferences();
    
    public void increaseReference();
    
    public void decreaseReference();

}
