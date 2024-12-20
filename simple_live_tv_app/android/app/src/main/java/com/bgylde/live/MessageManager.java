package com.bgylde.live;

import android.os.Handler;
import android.os.Looper;
import android.os.Message;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


/**
 * 消息中心，订阅消息包括与flutter之间的交互
 * Created by wangyan on 2024/12/20
 */
public class MessageManager implements Handler.Callback {

    private static volatile MessageManager manager;

    private final Handler handler = new Handler(Looper.getMainLooper(), this);
    private final List<Handler.Callback> registerCallbacks = new ArrayList<>();
    private final Map<String, Handler.Callback> registerCallbackMap = new HashMap<>();

    private MessageManager() {
    }

    public static MessageManager getInstance() {
        if (manager == null) {
            synchronized (MessageManager.class) {
                if (manager == null) {
                    manager = new MessageManager();
                }
            }
        }

        return manager;
    }

    @Override
    public boolean handleMessage(@NonNull Message message) {
        for (Handler.Callback callback : registerCallbacks) {
            if (callback.handleMessage(message)) {
                return true;
            }
        }

        return false;
    }

    public void sendMessage(Message message) {
        this.handler.sendMessage(message);
    }

    public void registerCallback(Handler.Callback callback) {
        this.registerCallbacks.add(callback);
    }

    public void registerCallback(String tag, Handler.Callback callback) {
        this.registerCallbacks.add(callback);
        this.registerCallbackMap.put(tag, callback);
    }

    public void unRegisterCallback(Handler.Callback callback) {
        this.registerCallbacks.remove(callback);
    }

    public void unRegisterCallback(String tag) {
        Handler.Callback callback = this.registerCallbackMap.get(tag);
        if (callback != null) {
            this.registerCallbacks.remove(callback);
        }
    }
}
