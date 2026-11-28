import 'dart:io';

/// Applied before any Windows HTTP client is created. Dio's IO adapter,
/// package:http and dart:io WebSockets all create their clients through this
/// factory. Native WebView2 and mpv have separate settings.
class WindowsDirectNetwork extends HttpOverrides {
  static void initialize() {
    if (Platform.isWindows) HttpOverrides.global = WindowsDirectNetwork();
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}
