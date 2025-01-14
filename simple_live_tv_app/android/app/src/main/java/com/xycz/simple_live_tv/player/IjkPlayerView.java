package com.xycz.simple_live_tv.player;

import android.content.Context;
import android.util.AttributeSet;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.ijk.widget.VideoView;

import com.xycz.simple_live_tv.core.IVideoPlayer;

/**
 * Created by wangyan on 2024/12/22
 */
public class IjkPlayerView extends VideoView implements IVideoPlayer {

    public IjkPlayerView(@NonNull Context context) {
        super(context);
    }

    public IjkPlayerView(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public IjkPlayerView(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    public void prepare() {
        this.prepareAsync();
    }
}
