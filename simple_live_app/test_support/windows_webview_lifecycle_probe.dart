import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Real Windows/WebView2 regression probe; no platform-channel mocks.
late File logFile;
late int roundLimit;
late bool cancelNavigation;
void record(String message) =>
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || args.isEmpty) {
    stderr.writeln(
        'Usage: probe.exe absolute-log-path [rounds=20] [allow|cancel]');
    exit(64);
  }
  roundLimit = args.length > 1 ? int.parse(args[1]) : 20;
  cancelNavigation = args.length > 2 && args[2] == 'cancel';
  if (roundLimit < 1 || roundLimit > 500) exit(64);
  logFile = File(args.first);
  Timer(Duration(seconds: roundLimit * 3 + 30), () {
    record('FAIL timed out before all navigation callbacks completed');
    exit(1);
  });
  final profile =
      await Directory.systemTemp.createTemp('simple-live-webview-probe-');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(
        '<html><body><input id="search"><a href="/room">room</a></body></html>');
    await request.response.close();
  });
  final environment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
    userDataFolder: profile.path,
    additionalBrowserArguments: '--no-proxy-server',
  ));
  runApp(MaterialApp(
      home: _Probe(environment, 'http://127.0.0.1:${server.port}')));
}

class _Probe extends StatefulWidget {
  const _Probe(this.environment, this.url);
  final WebViewEnvironment environment;
  final String url;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int round = 0;
  bool visible = true;
  bool retiring = false;

  Future<void> retire() async {
    if (retiring) return;
    retiring = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (!mounted) return;
    setState(() => visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    record('retired round=$round');
    if (++round == roundLimit) {
      record('PASS $roundLimit create/navigate/dispose cycles');
      exit(0);
    }
    retiring = false;
    setState(() => visible = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: !visible
            ? const SizedBox()
            : InAppWebView(
                key: ValueKey(round),
                webViewEnvironment: widget.environment,
                initialUrlRequest:
                    URLRequest(url: WebUri('${widget.url}/start')),
                initialSettings:
                    InAppWebViewSettings(useShouldOverrideUrlLoading: true),
                onWebViewCreated: (controller) {
                  record('created round=$round');
                  controller.loadUrl(
                      urlRequest:
                          URLRequest(url: WebUri('${widget.url}/trigger')));
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  record('pending navigation round=$round');
                  unawaited(retire());
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                  record('returning delayed navigation round=$round');
                  return cancelNavigation
                      ? NavigationActionPolicy.CANCEL
                      : NavigationActionPolicy.ALLOW;
                },
              ),
      );
}
