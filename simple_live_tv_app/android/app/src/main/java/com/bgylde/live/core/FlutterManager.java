package com.bgylde.live.core;

import android.os.Message;

import androidx.annotation.NonNull;

import com.bgylde.live.MessageManager;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Created by wangyan on 2024/12/20
 */
public class FlutterManager implements MethodChannel.MethodCallHandler {
    private static volatile FlutterManager manager;

    private FlutterEngine flutterEngine;
    private static final String CHANNEL_NAME = "samples.flutter.jumpto.android";
    private MethodChannel channel;
    private final Map<String, Integer> methodMap = new HashMap<String, Integer>();

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

    public void initFlutter(FlutterEngine flutterEngine) {
        this.flutterEngine = flutterEngine;
        this.channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger()
                , CHANNEL_NAME);
        this.channel.setMethodCallHandler(this);
    }

    public void registerMethod(@NonNull String methodName) {
        methodMap.put(methodName, methodName.hashCode());
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Message message = Message.obtain();
        message.what = MessageManager.FLUTTER_TO_JAVA_CMD;
        message.arg1 = methodMap.get(call.method);
        message.obj = new MethodCallModel(call, result);
        MessageManager.getInstance().sendMessage(message);
    }

    public void invokerFlutterMethod(String methodName, Object arguments) {
        this.channel.invokeMethod(methodName, arguments);
    }

    public void invokerFlutterMethod(String methodName, Object arguments, MethodChannel.Result result) {
        this.channel.invokeMethod(methodName, arguments, result);
    }
}
