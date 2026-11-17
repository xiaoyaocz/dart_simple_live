import 'dart:async';
import 'dart:io';


/// Windows 同步连接也直连，不读取系统代理。
class RemoteSyncConnection {
  final String? Function(Uri) proxyResolver;

  RemoteSyncConnection({String? Function(Uri)? proxyResolver})
      : proxyResolver = proxyResolver ?? ((_) => null);

  Future<WebSocket> connect(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final proxy = Platform.isWindows ? 'DIRECT' : proxyResolver(Uri.parse(url));
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
    // Windows 明确覆盖任何继承的解析器；其他平台保持原有行为。
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
