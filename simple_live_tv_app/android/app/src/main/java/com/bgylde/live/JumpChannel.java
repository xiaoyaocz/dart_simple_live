package com.bgylde.live;

import android.content.Intent;
import android.os.Bundle;
import android.os.Message;
import android.util.Log;

import androidx.annotation.NonNull;

import com.bgylde.live.model.LiveModel;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Created by wangyan on 2024/12/19
 */
public class JumpChannel implements MethodChannel.MethodCallHandler {

    private static final String batteryChannelName = "samples.flutter.jumpto.android";
    private final MethodChannel channel;
    private final FlutterActivity mActivity;

    public JumpChannel(BinaryMessenger flutterEngine, FlutterActivity activity) {
        this.channel = new MethodChannel(flutterEngine, batteryChannelName);
        this.mActivity = activity;
        this.channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "parseLiveUrl":
                parseLiveUrl(call, result);
                break;
            case "danmaku":
                String type = call.argument("type");
                String message = call.argument("message");
                Log.w("Test", "type [" + type + "]: " + message);
                Message msg = Message.obtain();
                Bundle bundle = new Bundle();
                bundle.putString("type", type);
                bundle.putString("message", message);
                msg.setData(bundle);
                MessageManager.getInstance().sendMessage(msg);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void parseLiveUrl(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Log.w("Test", "parseLiveUrl = " + call.arguments);
        LiveModel liveModel = new LiveModel(
                call.argument("id"),
                call.argument("roomId"),
                call.argument("name"),
                call.argument("logo"),
                call.argument("index"),
                call.argument("liveUrl")
        );
        Log.w("Test", "liveModel = " + liveModel);

        if (liveModel.getPlayUrls() != null && !liveModel.getPlayUrls().isEmpty()) {
            Intent intent = new Intent(mActivity, HomeActivity.class);
            Bundle bundle = new Bundle();
            bundle.putParcelable("liveModel", liveModel);
            intent.putExtra("bundle", bundle);
            mActivity.startActivity(intent);
            result.success(true);
        }

        result.success(false);
    }
}
