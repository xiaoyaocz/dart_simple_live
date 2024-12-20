package com.bgylde.live;

import androidx.annotation.NonNull;

import com.bgylde.live.core.FlutterManager;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;

public class FlutterActivity extends io.flutter.embedding.android.FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        FlutterManager.getInstance().setFlutterEngine(flutterEngine);
        BinaryMessenger binaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
        // flutter调用java
        new JumpChannel(binaryMessenger, this);
    }
}
