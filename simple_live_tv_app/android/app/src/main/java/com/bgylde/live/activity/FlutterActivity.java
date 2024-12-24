package com.bgylde.live.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;

import com.bgylde.live.core.LogUtils;
import com.bgylde.live.core.MessageManager;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.core.MethodCallModel;
import com.bgylde.live.core.OkHttpManager;

import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Objects;

import io.flutter.embedding.engine.FlutterEngine;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.Request;
import okhttp3.Response;

import static com.bgylde.live.core.MessageManager.FLUTTER_TO_JAVA_CMD;

public class FlutterActivity extends io.flutter.embedding.android.FlutterActivity implements Handler.Callback {

    private static final String TAG = "FlutterActivity";
    private static final String TEST_APK_URL = "http://192.168.100.1:12321/test.apk";
    private File tempApk;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        tempApk = new File(getExternalCacheDir(), "test.apk");
        MessageManager.getInstance().registerCallback(this);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        FlutterManager.getInstance().initFlutter(flutterEngine);
        FlutterManager.getInstance().registerMethod("openLivePage");
        FlutterManager.getInstance().registerMethod("checkTestUpdate");
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
        if (message.arg1 == "openLivePage".hashCode()) {
            Integer playerMode = model.getMethodCall().arguments();
            Intent intent;
            if (playerMode == null || playerMode == 0) {
                intent = new Intent(this, ExoLiveActivity.class);
            } else {
                intent = new Intent(this, IjkLiveActivity.class);
            }
            startActivity(intent);
        } else if (message.arg1 == "checkTestUpdate".hashCode()) {
            downloadApk();
        } else {
            return false;
        }

        return true;
    }

    private void installAPK() {
        if (!tempApk.exists()) {
            LogUtils.w("Test", "tempApk not exist: " + tempApk.getAbsolutePath());
            return;
        }

        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);         // 安装完成后打开新版本
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION); // 给目标应用一个临时授权
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {   // 判断版本大于等于7.0
                // 如果SDK版本>=24，即：Build.VERSION.SDK_INT >= 24，使用FileProvider兼容安装apk
                String packageName = this.getApplicationContext().getPackageName();
                String authority = packageName + ".fileprovider";
                Uri apkUri = FileProvider.getUriForFile(this, authority, tempApk);
                intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
            } else {
                intent.setDataAndType(Uri.fromFile(tempApk), "application/vnd.android.package-archive");
            }

            this.startActivity(intent);
        } catch (Exception e) {
            LogUtils.e(TAG, "install failed", e);
        }
    }

    private void downloadApk() {
        if (tempApk.exists() && tempApk.delete()) {
            LogUtils.w(TAG, "Delete exist apk!");
        }

        Request request = new Request.Builder()
                .get()
                .url(FlutterActivity.TEST_APK_URL)
                .build();
        Call call = OkHttpManager.getInstance().getOkHttpClient().newCall(request);
        call.enqueue(new Callback() {
            @Override
            public void onFailure(@NotNull Call call, @NotNull IOException e) {
                LogUtils.e(TAG, "http error", e);
                if (tempApk.exists() && tempApk.delete()) {
                    LogUtils.e(TAG, "delete apk", e);
                }
            }

            @Override
            public void onResponse(@NotNull Call call, @NotNull Response response) throws IOException {
                if (!response.isSuccessful()) {
                    return;
                }

                InputStream inputStream = Objects.requireNonNull(response.body()).byteStream();
                FileOutputStream fileOutputStream = new FileOutputStream(tempApk);
                try {
                    byte[] buffer = new byte[2048];
                    int len;
                    while ((len = inputStream.read(buffer)) != -1) {
                        fileOutputStream.write(buffer, 0, len);
                    }
                    fileOutputStream.flush();
                    installAPK();
                } catch (IOException e) {
                    LogUtils.e(TAG, "download error", e);
                } finally {
                    inputStream.close();
                    fileOutputStream.close();
                    response.close();
                }
            }
        });
    }
}
