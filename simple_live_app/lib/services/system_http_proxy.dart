import 'dart:io';

/// Immutable snapshot of Android's current HTTP proxy; no fixed ports or bypasses.
class SystemHttpProxy {
  final String host;
  final int port;
  final List<String> exclusions;
  const SystemHttpProxy(this.host, this.port, this.exclusions);

  static SystemHttpProxy? fromPlatform(Map<dynamic, dynamic>? value) {
    if (value == null) return null;
    var host = value['host']?.toString().trim() ?? '';
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    final port = int.tryParse(value['port']?.toString() ?? '');
    if (host.isEmpty || port == null || port < 1 || port > 65535 ||
        RegExp(r'[\s/@;]').hasMatch(host)) return null;
    final list = value['exclusions'];
    return SystemHttpProxy(host, port,
        list is List ? list.map((e) => e.toString()).toList() : const []);
  }

  bool bypasses(Uri uri) {
    final target = uri.host.toLowerCase();
    for (final entry in exclusions) {
      final pattern = entry.trim().toLowerCase();
      if (pattern.isEmpty) continue;
      if (pattern == '<local>' && !target.contains('.') && !target.contains(':')) {
        return true;
      }
      if (pattern.startsWith('.') &&
          (target == pattern.substring(1) || target.endsWith(pattern))) return true;
      final expression = RegExp.escape(pattern).replaceAll(r'\*', '.*');
      if (RegExp('^$expression\$', caseSensitive: false).hasMatch(target)) return true;
    }
    return false;
  }

  String get _authority => '${host.contains(':') ? '[$host]' : host}:$port';
  String directive(Uri uri) => bypasses(uri) ? 'DIRECT' : 'PROXY $_authority';
  String? playbackUrl(Uri uri) => bypasses(uri) ? null : 'http://$_authority';
}

/// Covers Dio, image downloads and Dart WebSockets without global TLS bypasses.
class SystemProxyHttpOverrides extends HttpOverrides {
  final SystemHttpProxy? Function() currentProxy;
  final HttpOverrides? previous;
  SystemProxyHttpOverrides(this.currentProxy, {this.previous});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = previous?.createHttpClient(context) ?? super.createHttpClient(context);
    // Read the current snapshot at connection time, not at client construction:
    // pooled clients also follow proxy changes while the application is running.
    client.findProxy = (uri) => currentProxy()?.directive(uri) ??
        HttpClient.findProxyFromEnvironment(uri);
    return client;
  }
}
