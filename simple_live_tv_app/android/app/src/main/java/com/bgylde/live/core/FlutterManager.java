package com.bgylde.live.core;

import io.flutter.embedding.engine.FlutterEngine;

/**
 * Created by wangyan on 2024/12/20
 */
public class FlutterManager {
    private static volatile FlutterManager manager;

    private FlutterEngine flutterEngine;

    private FlutterManager() {
    }

    public static FlutterManager getInstance() {
        if (manager == null) {
            synchronized (FlutterManager.class) {
                if (manager == null) {
                    manager = new FlutterManager();
                }
            }
        }

        return manager;
    }

    public void setFlutterEngine(FlutterEngine flutterEngine) {
        this.flutterEngine = flutterEngine;
    }

    public FlutterEngine getFlutterEngine() {
        return flutterEngine;
    }
}
