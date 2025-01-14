package com.xycz.simple_live_tv.player;

import android.content.Context;
import android.util.AttributeSet;

import androidx.annotation.Nullable;
import androidx.media3.ui.PlayerView;

import com.xycz.simple_live_tv.core.IVideoPlayer;

/**
 * Created by wangyan on 2024/12/22
 */
public class ExoPlayerView extends PlayerView implements IVideoPlayer {
    public ExoPlayerView(Context context) {
        super(context);
    }

    public ExoPlayerView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public ExoPlayerView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    public void prepare() {
        if (getPlayer() != null) {
            getPlayer().prepare();
        }
    }

    @Override
    public void start() {
        if (getPlayer() != null) {
            getPlayer().play();
        }
    }

    @Override
    public void stop() {
        if (getPlayer() != null) {
            getPlayer().stop();
        }
    }

    @Override
    public void release() {
        if (getPlayer() != null) {
            getPlayer().release();
        }
    }
}
