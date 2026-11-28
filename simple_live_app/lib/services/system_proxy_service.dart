import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/system_http_proxy.dart';

class SystemProxyService with WidgetsBindingObserver {
  static final instance = SystemProxyService();
  static const _channel = MethodChannel('simple_live/network');
  SystemHttpProxy? _proxy;
  int _revision = 0;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    _initialized = true;
    HttpOverrides.global = SystemProxyHttpOverrides(() => _proxy,
        previous: HttpOverrides.current);
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'proxyChanged') await refresh();
    });
    await refresh();
  }

  Future<void> refresh() async {
    final revision = ++_revision;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getSystemProxy')
          .timeout(const Duration(seconds: 2));
      if (revision != _revision) return;
      _proxy = SystemHttpProxy.fromPlatform(data);
      Log.d(_proxy == null ? 'Android 网络：直连' : 'Android 网络：已应用系统 HTTP 代理');
    } catch (error) {
      // Startup must remain usable on older native runners. Keep the last known
      // proxy on a transient channel failure; do not rewrite any device setting.
      Log.d('读取系统代理失败：${error.runtimeType}');
    }
  }

  String? playbackProxy(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? null : _proxy?.playbackUrl(uri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
