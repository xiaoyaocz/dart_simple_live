
package com.bgylde.live.danmaku.model.android;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;

import com.bgylde.live.danmaku.jni.NativeBitmapFactory;

public class DrawingCacheHolder {

    public Canvas canvas;

    public Bitmap bitmap;
    
    public Bitmap[][] bitmapArray;

    public Object extra;

    public int width;

    public int height;

    public boolean drawn;

    private int mDensity;

    public DrawingCacheHolder() {

    }

    public DrawingCacheHolder(int w, int h) {
        buildCache(w, h, 0, true);
    }
    
    public DrawingCacheHolder(int w, int h, int density) {
        mDensity = density;
        buildCache(w, h, density, true);
    }

    public void buildCache(int w, int h, int density, boolean checkSizeEquals) {
        boolean reuse = checkSizeEquals ? (w == width && h == height) : (w <= width && h <= height);
        if (reuse && bitmap != null) {
//            canvas.drawColor(Color.TRANSPARENT);
//            canvas.setBitmap(null);
            bitmap.eraseColor(Color.TRANSPARENT);
            canvas.setBitmap(bitmap);
            recycleBitmapArray();
            return;
        }
        if (bitmap != null) {
            recycle();
        }
        width = w;
        height = h;
        bitmap = NativeBitmapFactory.createBitmap(w, h, Bitmap.Config.ARGB_8888);
        if (density > 0) {
            mDensity = density;
            bitmap.setDensity(density);
        }
        if (canvas == null){
            canvas = new Canvas(bitmap);
            canvas.setDensity(density);
        }else
            canvas.setBitmap(bitmap);
    }

    public void erase() {
        eraseBitmap(bitmap);
        eraseBitmapArray();
    }

    public synchronized void recycle() {
        Bitmap bitmapReserve = bitmap;
        bitmap = null;
        width = height = 0;
        if (bitmapReserve != null) {
            bitmapReserve.recycle();
        }
        recycleBitmapArray();
        extra = null;
    }

    @SuppressLint("NewApi")
    public void splitWith(int dispWidth, int dispHeight, int maximumCacheWidth, int maximumCacheHeight) {
        recycleBitmapArray();
        if (width <= 0 || height <= 0 || bitmap == null) {
            return;
        }
        if (width <= maximumCacheWidth && height <= maximumCacheHeight) {
            return;
        }
        maximumCacheWidth = Math.min(maximumCacheWidth, dispWidth);
        maximumCacheHeight = Math.min(maximumCacheHeight, dispHeight);
        int xCount = width / maximumCacheWidth + (width % maximumCacheWidth == 0 ? 0 : 1);
        int yCount = height / maximumCacheHeight + (height % maximumCacheHeight == 0 ? 0 : 1);
        int averageWidth = width / xCount;
        int averageHeight = height / yCount;
        final Bitmap[][] bmpArray = new Bitmap[yCount][xCount];
        if (canvas == null){
            canvas = new Canvas();
            if (mDensity > 0) {
                canvas.setDensity(mDensity);
            }
        }
        Rect rectSrc = new Rect();
        Rect rectDst = new Rect();
        for (int yIndex = 0; yIndex < yCount; yIndex++) {
            for (int xIndex = 0; xIndex < xCount; xIndex++) {
                Bitmap bmp = bmpArray[yIndex][xIndex] = NativeBitmapFactory.createBitmap(
                        averageWidth, averageHeight, Bitmap.Config.ARGB_8888);
                if (mDensity > 0) {
                    bmp.setDensity(mDensity);
                }
                canvas.setBitmap(bmp);
                int left = xIndex * averageWidth, top = yIndex * averageHeight;
                rectSrc.set(left, top, left + averageWidth, top + averageHeight);
                rectDst.set(0, 0, bmp.getWidth(), bmp.getHeight());
                canvas.drawBitmap(bitmap, rectSrc, rectDst, null);
            }
        }
        canvas.setBitmap(bitmap);
        bitmapArray = bmpArray;
    }

    private void eraseBitmap(Bitmap bmp) {
        if (bmp != null) {
            bmp.eraseColor(Color.TRANSPARENT);
        }
    }

    private void eraseBitmapArray() {
        if (bitmapArray != null) {
            for (int i = 0; i < bitmapArray.length; i++) {
                for (int j = 0; j < bitmapArray[i].length; j++) {
                    eraseBitmap(bitmapArray[i][j]);
                }
            }
        }
    }

    private void recycleBitmapArray() {
        Bitmap[][] bitmapArrayReserve = bitmapArray;
        bitmapArray = null;
        if (bitmapArrayReserve != null) {
            for (int i = 0; i < bitmapArrayReserve.length; i++) {
                for (int j = 0; j < bitmapArrayReserve[i].length; j++) {
                    if (bitmapArrayReserve[i][j] != null) {
                        bitmapArrayReserve[i][j].recycle();
                        bitmapArrayReserve[i][j] = null;
                    }
                }
            }
        }
    }

    public final synchronized boolean draw(Canvas canvas, float left, float top, Paint paint) {
        if (bitmapArray != null) {
            for (int i = 0; i < bitmapArray.length; i++) {
                for (int j = 0; j < bitmapArray[i].length; j++) {
                    Bitmap bmp = bitmapArray[i][j];
                    if (bmp != null) {
                        float dleft = left + j * bmp.getWidth();
                        if (dleft > canvas.getWidth() || dleft + bmp.getWidth() < 0) {
                            continue;
                        }
                        float dtop = top + i * bmp.getHeight();
                        if (dtop > canvas.getHeight() || dtop + bmp.getHeight() < 0) {
                            continue;
                        }
                        canvas.drawBitmap(bmp, dleft, dtop, paint);
                    }
                }
            }
            return true;
        } else if (bitmap != null) {
            canvas.drawBitmap(bitmap, left, top, paint);
            return true;
        }
        return false;
    }

}
