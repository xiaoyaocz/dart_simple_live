package com.bgylde.live.core;

import androidx.annotation.NonNull;

import java.io.IOException;
import java.util.Map;

import lombok.Getter;
import okhttp3.HttpUrl;
import okhttp3.Interceptor;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.logging.HttpLoggingInterceptor;

/**
 * Created by wangyan on 2024/12/21
 */
public class OkHttpManager implements Interceptor {

    private static volatile OkHttpManager manager;

    @Getter
    private final OkHttpClient okHttpClient;
    private Map<String, String> headerMap;

    private OkHttpManager() {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        HttpLoggingInterceptor loggingInterceptor = new HttpLoggingInterceptor(new HttpLoggingInterceptor.Logger() {
            @Override
            public void log(@NonNull String s) {
                LogUtils.w("OkHttp", s);
            }
        });
        loggingInterceptor.setLevel(HttpLoggingInterceptor.Level.HEADERS);
        builder.addInterceptor(loggingInterceptor);
        builder.addInterceptor(this)
                .followRedirects(false);
        okHttpClient = builder.build();
    }

    public static OkHttpManager getInstance() {
        if (manager == null) {
            synchronized (OkHttpManager.class) {
                if (manager == null) {
                    manager = new OkHttpManager();
                }
            }
        }

        return manager;
    }

    public void resetRequestHeader(Map<String, String> headerMap) {
        this.headerMap = headerMap;
    }

    @NonNull
    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();

        Request.Builder builder = request.newBuilder();
        if (headerMap != null && !headerMap.isEmpty()) {
            for (String key: headerMap.keySet()) {
                String value = headerMap.get(key);
                if (value != null) {
                    builder.addHeader(key, value);
                }
            }
        }

        Response response =  chain.proceed(builder.build());
        if (response.code() != 302) {
            return response;
        }

        // 获取重定向的目标URL
        String newUrl = response.header("Location");
        if (newUrl == null || newUrl.isEmpty()) {
            return response;
        }

        HttpUrl httpUrl = HttpUrl.parse(newUrl);
        LogUtils.w("OkHttp", "httpUrl=>" + httpUrl);
        if (httpUrl == null) {
            return response;
        }

        if (httpUrl.scheme().equals("https") && httpUrl.host().contains("_")) {
            httpUrl = httpUrl.newBuilder().scheme("http").build();
            builder.url(httpUrl);
        }

        response.close();
        return chain.proceed(builder.build());
    }
}
