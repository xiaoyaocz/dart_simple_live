package com.bgylde.live.activity;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bgylde.live.core.MessageManager;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.MethodCallModel;

import io.flutter.embedding.engine.FlutterEngine;

import static com.bgylde.live.core.MessageManager.DEFAULT_CMD;
import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

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
//        FlutterManager.getInstance().registerMethod("parseLiveUrl");
        FlutterManager.getInstance().registerMethod("danmaku");
        FlutterManager.getInstance().registerMethod("openLivePage");
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
        if (message.arg1 == "danmaku".hashCode()) {
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
        } else if (message.arg1 == "openLivePage".hashCode()) {
            Integer playerMode = model.getMethodCall().arguments();
            Intent intent;
            if (playerMode == null || playerMode == 0) {
                intent = new Intent(this, ExoLiveActivity.class);
            } else {
                intent = new Intent(this, IjkLiveActivity.class);
            }
            startActivity(intent);
        } else {
            return false;
        }

        return true;
    }
}
