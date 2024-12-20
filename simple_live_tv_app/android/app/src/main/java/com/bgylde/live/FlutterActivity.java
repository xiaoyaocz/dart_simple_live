package com.bgylde.live;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.MethodCallModel;
import com.bgylde.live.model.LiveModel;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bgylde.live.MessageManager.DEFAULT_CMD;
import static com.bgylde.live.MessageManager.FLUTTER_TO_JAVA_CMD;

public class FlutterActivity extends io.flutter.embedding.android.FlutterActivity implements Handler.Callback {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        MessageManager.getInstance().registerCallback(this);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        FlutterManager.getInstance().initFlutter(flutterEngine);
        FlutterManager.getInstance().registerMethod("parseLiveUrl");
        FlutterManager.getInstance().registerMethod("danmaku");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        MessageManager.getInstance().unRegisterCallback(this);
    }

    @Override
    public boolean handleMessage(@NonNull Message message) {
        if (message.what != FLUTTER_TO_JAVA_CMD) {
            return false;
        }

        MethodCallModel model = (MethodCallModel)message.obj;
        if (message.arg1 == "parseLiveUrl".hashCode()) {
            parseLiveUrl(model.getMethodCall(), model.getResult());
        } else if (message.arg1 == "danmaku".hashCode()) {
            String type = model.getMethodCall().argument("type");
            String info = model.getMethodCall().argument("message");
            String color = model.getMethodCall().argument("color");
            Message msg = Message.obtain();
            msg.what = DEFAULT_CMD;
            Bundle bundle = new Bundle();
            bundle.putString("type", type);
            bundle.putString("message", info);
            bundle.putString("color", color);
            msg.setData(bundle);
            MessageManager.getInstance().sendMessage(msg);
        }

        return false;
    }

    private void parseLiveUrl(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LiveModel liveModel = new LiveModel(
                call.argument("id"),
                call.argument("roomId"),
                call.argument("name"),
                call.argument("logo"),
                call.argument("index"),
                call.argument("liveUrl")
        );

        if (liveModel.getPlayUrls() != null && !liveModel.getPlayUrls().isEmpty()) {
            Intent intent = new Intent(this, HomeActivity.class);
            Bundle bundle = new Bundle();
            bundle.putParcelable("liveModel", liveModel);
            intent.putExtra("bundle", bundle);
            startActivity(intent);
            result.success(true);
            return;
        }

        result.success(false);
    }
}
