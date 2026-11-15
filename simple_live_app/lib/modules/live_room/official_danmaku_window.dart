import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/services/search_web_session.dart';

/// The actual official room UI. This widget has no message-sending API.
class OfficialDanmakuWindow extends StatefulWidget {
  const OfficialDanmakuWindow({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.roomUri,
    this.searchEnvironment,
  });

  final String siteId, siteName;
  final Uri roomUri;
  // Borrow the active search profile instead of guessing which account to use.
  final Future<WebViewEnvironment?>? searchEnvironment;

  @override
  State<OfficialDanmakuWindow> createState() => _OfficialDanmakuWindowState();
}

class _OfficialDanmakuWindowState extends State<OfficialDanmakuWindow> {
  late Future<WebViewEnvironment?> _environment;
  WebViewEnvironment? _ownedEnvironment;
  InAppWebViewController? _view;
  Widget? _browser;
  Completer<WebViewEnvironment>? _startup;
  Timer? _startupTimer;
  bool _loadingEnvironment = false;
  bool _useSearchEnvironment = true;
  bool _wide = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _environment = _createEnvironment();
  }

  Future<WebViewEnvironment?> _createEnvironment() async {
    _loadingEnvironment = true;
    try {
      final borrowed = _useSearchEnvironment ? widget.searchEnvironment : null;
      if (borrowed != null) {
        try {
          return await borrowed;
        } catch (_) {
          // A failed Future cannot be retried. Next attempt opens the same
          // remembered profile independently, without disposing the search view.
          _useSearchEnvironment = false;
          rethrow;
        }
      }
      final ready = Completer<WebViewEnvironment>();
      _startup = ready;
      _startupTimer = Timer(const Duration(seconds: 15), () {
        if (!ready.isCompleted) {
          ready.completeError(TimeoutException('WebView startup'));
        }
      });
      unawaited(SearchWebSession.create(siteId: widget.siteId)
          .then((environment) async {
        if (!mounted || ready.isCompleted) {
          await environment.dispose();
        } else {
          ready.complete(environment);
        }
      }).catchError((Object error, StackTrace stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      }));
      final environment = await ready.future;
      if (!mounted) {
        await environment.dispose();
        throw StateError('Window closed');
      }
      _ownedEnvironment = environment;
      return environment;
    } finally {
      _loadingEnvironment = false;
      _startupTimer?.cancel();
      _startupTimer = null;
      _startup = null;
    }
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    if (_startup?.isCompleted == false) {
      _startup!.completeError(StateError('Window closed'));
    }
    // Dispose only environments owned by this window, never the search page's.
    final owned = _ownedEnvironment;
    if (owned != null) {
      unawaited(
          Future<void>.microtask(owned.dispose).catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final view = _view;
    if (view != null) {
      setState(() => _error = null);
      try {
        await view.reload();
      } catch (_) {
        if (mounted) setState(() => _error = '网页刷新失败，请关闭后重新打开');
      }
    } else if (!_loadingEnvironment && _browser == null) {
      final pending = _createEnvironment();
      setState(() {
        _environment = pending;
      });
    }
  }

  // Muting is the only injected behavior. No transport interception, selectors,
  // input setters, credential export or programmatic submit/click occurs.
  static const _muteMedia = r'''
(() => {
  const mute = e => { if (e instanceof HTMLMediaElement && !e.muted) e.muted = true; };
  document.addEventListener('play', e => mute(e.target), true);
  document.addEventListener('volumechange', e => mute(e.target), true);
  const start = () => {
    const update = () => document.querySelectorAll('video,audio').forEach(mute);
    update();
    new MutationObserver(update).observe(document.documentElement, {childList:true,subtree:true});
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
''';

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final availableWidth = math.max(0.0, screen.width - 24);
    final availableHeight = math.max(0.0, screen.height - 24);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _wide ? availableWidth : math.min(980, availableWidth),
        height: _wide ? availableHeight : math.min(720, availableHeight),
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Row(children: [
              const SizedBox(width: 12),
              Expanded(
                  child: Text('官方弹幕 · ${widget.siteName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                  tooltip: '刷新官方网页',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh)),
              IconButton(
                  tooltip: _wide ? '缩小网页窗口' : '展开完整网页',
                  onPressed: () => setState(() => _wide = !_wide),
                  icon: Icon(_wide ? Icons.fullscreen_exit : Icons.fullscreen)),
              IconButton(
                  tooltip: '关闭官方弹幕',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('直接在网页输入框发送文字或表情；账号、验证和发送结果以网页为准。',
                style: TextStyle(fontSize: 12)),
          ),
          Expanded(
              child: FutureBuilder<WebViewEnvironment?>(
            future: _environment,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: _reload,
                        child: const Text('网页组件启动失败，点击重试')));
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: Text('正在打开官方网页…'));
              }
              return Column(children: [
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(8), child: Text(_error!)),
                Expanded(
                    key: const ValueKey('official-browser'),
                    child: _browser ??= InAppWebView(
                      webViewEnvironment: snapshot.data,
                      initialUrlRequest:
                          URLRequest(url: WebUri(widget.roomUri.toString())),
                      initialSettings: InAppWebViewSettings(
                        javaScriptCanOpenWindowsAutomatically: true,
                        supportMultipleWindows: true,
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: true,
                      ),
                      initialUserScripts: UnmodifiableListView([
                        UserScript(
                            source: _muteMedia,
                            injectionTime:
                                UserScriptInjectionTime.AT_DOCUMENT_START),
                      ]),
                      onWebViewCreated: (view) {
                        if (mounted) _view = view;
                      },
                      onLoadStart: (_, __) {
                        if (mounted && _error != null) {
                          setState(() => _error = null);
                        }
                      },
                      onReceivedError: (_, request, error) {
                        if (!mounted ||
                            request.isForMainFrame != true ||
                            error.type == WebResourceErrorType.CANCELLED) {
                          return;
                        }
                        setState(() => _error = '官方网页加载失败，请点击刷新重试');
                      },
                      shouldOverrideUrlLoading: (_, action) async {
                        final scheme = action.request.url?.scheme;
                        return scheme == 'https' ||
                                scheme == 'http' ||
                                scheme == 'about'
                            ? NavigationActionPolicy.ALLOW
                            : NavigationActionPolicy.CANCEL;
                      },
                      // WebView2's default false handler opens the requested popup
                      // in this visible view, matching the existing search browser.
                      onCreateWindow: (_, __) async => false,
                    )),
              ]);
            },
          )),
        ]),
      ),
    );
  }
}

Future<void> showOfficialDanmakuWindow(
  BuildContext context, {
  required String siteId,
  required String siteName,
  required Uri roomUri,
  Future<WebViewEnvironment?>? searchEnvironment,
  required ValueChanged<Route<void>> onRoute,
}) async {
  final route = RawDialogRoute<void>(
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: '关闭官方弹幕',
    pageBuilder: (_, __, ___) => OfficialDanmakuWindow(
      siteId: siteId,
      siteName: siteName,
      roomUri: roomUri,
      searchEnvironment: searchEnvironment,
    ),
  );
  onRoute(route);
  await Navigator.of(context, rootNavigator: true).push(route);
}
