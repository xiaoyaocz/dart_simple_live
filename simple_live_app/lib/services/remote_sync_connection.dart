import 'dart:async';
import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 仅为远程同步读取系统代理并支持直连回退，不改变直播请求或全局 HTTP 配置。
class RemoteSyncConnection {
  final String? Function(Uri) proxyResolver;

  RemoteSyncConnection({String? Function(Uri)? proxyResolver})
      : proxyResolver = proxyResolver ?? _windowsProxy;

  static bool _isLoopback(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'localhost') return true;
    return InternetAddress.tryParse(host)?.isLoopback == true;
  }

  Future<WebSocket> connect(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse(url);
    final proxy = (Platform.isWindows && _isLoopback(uri))
        ? 'DIRECT'
        : proxyResolver(uri);
    if (proxy != null && proxy != 'DIRECT') {
      final elapsed = Stopwatch()..start();
      try {
        // 给直连回退保留时间，整个连接过程不超过原来的超时上限。
        return await _connect(url, proxy,
            Duration(microseconds: timeout.inMicroseconds * 2 ~/ 3));
      } catch (_) {
        final remaining = timeout - elapsed.elapsed;
        if (remaining <= Duration.zero) rethrow;
        return _connect(url, 'DIRECT', remaining);
      }
    }
    return _connect(url, proxy, timeout);
  }

  Future<WebSocket> _connect(
      String url, String? proxy, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    // 有明确代理指令时覆盖全局 HttpOverrides，否则沿用当前平台默认路由。
    if (proxy != null) client.findProxy = (_) => proxy;
    var timedOut = false;
    try {
      final pending =
          WebSocket.connect(url, customClient: client).then((socket) {
        if (timedOut) unawaited(socket.close());
        return socket;
      });
      return await pending.timeout(timeout, onTimeout: () {
        timedOut = true;
        throw TimeoutException('远程同步连接超时', timeout);
      });
    } finally {
      // 握手成功的 WebSocket 已脱离 HttpClient；失败则关闭待连接套接字。
      client.close(force: true);
    }
  }

  static String? _windowsProxy(Uri uri) {
    if (!Platform.isWindows) return null;
    if (_isLoopback(uri)) return 'DIRECT';
    try {
      final key = Registry.openPath(RegistryHive.currentUser,
          path: r'Software\Microsoft\Windows\CurrentVersion\Internet Settings');
      try {
        return proxyDirective(uri,
            enabled: key.getIntValue('ProxyEnable') == 1,
            server: key.getStringValue('ProxyServer') ?? '',
            bypass: key.getStringValue('ProxyOverride') ?? '');
      } finally {
        key.close();
      }
    } catch (_) {
      return null;
    }
  }

  static String? proxyDirective(Uri uri,
      {required bool enabled, required String server, String bypass = ''}) {
    if (!enabled) return null;
    for (final item in bypass.split(';')) {
      final pattern = item.trim();
      if (pattern.isEmpty) continue;
      if (pattern.toLowerCase() == '<local>') {
        if (!uri.host.contains('.')) return 'DIRECT';
        continue;
      }
      final expression =
          RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
      if (RegExp('^$expression\$', caseSensitive: false).hasMatch(uri.host)) {
        return 'DIRECT';
      }
    }
    var address = server.trim();
    if (address.contains('=')) {
      final scheme =
          uri.scheme == 'wss' || uri.scheme == 'https' ? 'https' : 'http';
      address = '';
      for (final item in server.split(';')) {
        final separator = item.indexOf('=');
        if (separator < 0) continue;
        if (item.substring(0, separator).trim().toLowerCase() == scheme) {
          address = item.substring(separator + 1).trim();
          break;
        }
      }
    }
    if (address.isEmpty || RegExp(r'\s').hasMatch(address)) return null;
    try {
      final proxy =
          Uri.parse(address.contains('://') ? address : 'http://$address');
      if (proxy.scheme != 'http' ||
          proxy.host.isEmpty ||
          !proxy.hasPort ||
          proxy.port <= 0 ||
          proxy.port > 65535 ||
          proxy.userInfo.isNotEmpty ||
          (proxy.path.isNotEmpty && proxy.path != '/') ||
          proxy.hasQuery ||
          proxy.hasFragment) {
        return null;
      }
      final host = proxy.host.contains(':') ? '[${proxy.host}]' : proxy.host;
      return 'PROXY $host:${proxy.port}';
    } on FormatException {
      return null;
    }
  }
}
