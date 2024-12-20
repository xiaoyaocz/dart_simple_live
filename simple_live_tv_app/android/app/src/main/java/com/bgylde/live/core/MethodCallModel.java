package com.bgylde.live.core;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Created by wangyan on 2024/12/20
 */
public class MethodCallModel {

    private final MethodCall methodCall;
    private final MethodChannel.Result result;

    public MethodCallModel(MethodCall methodCall, MethodChannel.Result result) {
        this.methodCall = methodCall;
        this.result = result;
    }

    public MethodCall getMethodCall() {
        return methodCall;
    }

    public MethodChannel.Result getResult() {
        return result;
    }
}
