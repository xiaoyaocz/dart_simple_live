// Isolated native shutdown regression: no accounts, public rooms or messages.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await Directory.systemTemp.createTemp('simple-live-shutdown-');
  final environment = await WebViewEnvironment.create(
    settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
  );
  runApp(MaterialApp(home: Scaffold(body: InAppWebView(
    webViewEnvironment: environment,
    initialData: InAppWebViewInitialData(data: '<html><body>Local shutdown fixture</body></html>'),
    onLoadStop: (controller, url) async {
      // Keep the native view alive until the host destroys the Flutter engine.
      await const MethodChannel('simple_live/shutdown_fixture').invokeMethod('ready');
    },
  ))));
}
