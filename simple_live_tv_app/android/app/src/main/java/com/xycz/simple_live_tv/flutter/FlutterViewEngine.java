package com.xycz.simple_live_tv.flutter;

import android.app.Activity;

import androidx.activity.ComponentActivity;
import androidx.annotation.NonNull;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleObserver;
import androidx.lifecycle.OnLifecycleEvent;

import io.flutter.embedding.android.ExclusiveAppComponent;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.platform.PlatformPlugin;

/**
 * Created by wangyan on 2024/12/30
 */
public class FlutterViewEngine implements LifecycleObserver, ExclusiveAppComponent<Activity> {

    private FlutterView flutterView;
    private ComponentActivity activity;
    private PlatformPlugin platformPlugin;
    private final FlutterEngine engine;

    public FlutterViewEngine(FlutterEngine engine) {
        this.engine = engine;
    }

    private void hookActivityAndView() {
        if (activity == null) {
            return;
        }

        if (flutterView == null) {
            return;
        }

        platformPlugin = new PlatformPlugin(activity, engine.getPlatformChannel());
        engine.getActivityControlSurface().attachToActivity(this, activity.getLifecycle());
        flutterView.attachToFlutterEngine(engine);
        activity.getLifecycle().addObserver(this);
    }

    private void unHookActivityAndView() {
        if (activity != null) {
            activity.getLifecycle().removeObserver(this);
        }

        engine.getActivityControlSurface().detachFromActivity();
        if (platformPlugin != null) {
            platformPlugin.destroy();
            platformPlugin = null;
        }

        engine.getLifecycleChannel().appIsDetached();
        if (flutterView != null) {
            flutterView.detachFromFlutterEngine();
        }
    }

    public void attachToActivity(ComponentActivity activity) {
        this.activity = activity;
        if (flutterView != null) {
            hookActivityAndView();
        }
    }

    public void detachActivity() {
        if (flutterView != null) {
            unHookActivityAndView();
        }

        activity = null;
    }

    public void attachFlutterView(FlutterView flutterView) {
        this.flutterView = flutterView;
        if (activity != null) {
            hookActivityAndView();
        }
    }

    public void detachFlutterView() {
        unHookActivityAndView();
        flutterView = null;
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    private void resumeActivity() {
        if (activity != null) {
            engine.getLifecycleChannel().appIsResumed();
        }

        if (platformPlugin != null) {
            platformPlugin.updateSystemUiOverlays();
        }
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    private void pauseActivity() {
        if (activity != null) {
            engine.getLifecycleChannel().appIsInactive();
        }
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    private void stopActivity() {
        if (activity != null) {
            engine.getLifecycleChannel().appIsPaused();
        }
    }

    @Override
    public void detachFromFlutterEngine() {

    }

    @NonNull
    @Override
    public Activity getAppComponent() {
        return activity;
    }
}
