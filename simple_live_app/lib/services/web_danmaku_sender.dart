import 'dart:async';
import 'package:simple_live_app/services/danmaku_sender.dart';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/services/danmaku_web_scripts.dart';
import 'package:simple_live_app/services/search_web_session.dart';

export 'danmaku_sender.dart';

/// One lazy browser per active room. Only explicit user actions call send().
class WebDanmakuSender implements DanmakuSender {
  WebDanmakuSender(
      {required this.siteId,
      required this.roomUri,
      InAppWebViewController? existingView,
      bool Function()? isExistingViewCurrent,
      Future<WebViewEnvironment> Function()? environmentFactory})
      : _existingView = existingView,
        _isExistingViewCurrent = isExistingViewCurrent,
        _environmentFactory = environmentFactory;
  final InAppWebViewController? _existingView;
  final bool Function()? _isExistingViewCurrent;
  static int _nextInputHandler = 0;
  final Future<WebViewEnvironment> Function()? _environmentFactory;
  final String siteId;
  final Uri roomUri;
  HeadlessInAppWebView? _browser;
  InAppWebViewController? _view;
  WebViewEnvironment? _environment;
  Future<void>? _initialization;
  Completer<void>? _created;
  bool _closed = false;
  bool _busy = false;

  // Start loading while the user types, without submitting any message.
  @override
  void prepare() {
    if (_closed) return;
    final pending = _ensureInitialized();
    unawaited(pending.catchError((Object _) {}));
  }

  Future<void> _ensureInitialized() => _initialization ??=
          _initialize().catchError((Object error, StackTrace stack) async {
        final code = error is PlatformException && RegExp(r'^[\w.-]{1,40}$').hasMatch(error.code)
            ? error.code : 'none';
        Log.writeLog('[Danmaku] site=$siteId source=${_existingView == null ? 'profile' : 'original'} '
            'initialization_error=${error.runtimeType} code=$code');
        await _releaseBrowser();
        _initialization = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _initialize() async {
    if (_existingView != null) {
      if (_isExistingViewCurrent?.call() == false) throw StateError('Original page changed');
      _view = _existingView;
      // SearchPage installed the transport at document start and never suspends
      // its Windows view. Do not resume/make visible or reinject the active page.
      return;
    }
    final startup = Stopwatch()..start();
    Duration remaining() {
      final left = const Duration(seconds: 10) - startup.elapsed;
      if (left <= Duration.zero) throw TimeoutException('Browser startup');
      return left;
    }

    final created = Completer<void>();
    _created = created;
    final creation =
        _environmentFactory?.call() ?? SearchWebSession.create(siteId: siteId);
    late final WebViewEnvironment environment;
    try {
      environment = await creation.timeout(remaining());
    } on TimeoutException {
      unawaited(
          creation.then((value) => value.dispose()).catchError((Object _) {}));
      rethrow;
    }
    _environment = environment;
    if (_closed) return;
    late final HeadlessInAppWebView browser;
    browser = HeadlessInAppWebView(
      // Physical pixels are divided by Windows DPI in WebView2. 1280px at
      // 125% leaves ~1010 CSS pixels, below these desktop room layouts.
      initialSize: const Size(1920, 1080),
      webViewEnvironment: environment,
      initialSettings:
          InAppWebViewSettings(mediaPlaybackRequiresUserGesture: true),
      initialUrlRequest: URLRequest(url: WebUri(roomUri.toString())),
      initialUserScripts: UnmodifiableListView([
        UserScript(
            source: DanmakuWebScripts.transport,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
        UserScript(
            source: DanmakuWebScripts.silence,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
      ]),
      onWebViewCreated: (view) {
        if (!_closed && identical(_browser, browser)) {
          _view = view;
          if (!created.isCompleted) created.complete();
        }
      },
    );
    _browser = browser;
    final running = browser.run();
    try {
      await running.timeout(remaining());
    } on TimeoutException {
      // Creation is not cancellable; close a late native view when it arrives.
      unawaited(
          running.then((_) => browser.dispose()).catchError((Object _) {}));
      rethrow;
    }
    // Ads/images may keep window.load pending after chat is fully usable.
    await created.future.timeout(remaining());
  }

  @override
  Future<DanmakuSendResult> send(String text) async {
    if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
    if (_existingView != null && _isExistingViewCurrent?.call() == false) {
      return const DanmakuSendResult('closed', '原直播网页已切换，请重新打开该直播间');
    }
    if (_busy) return const DanmakuSendResult('busy', '上一条弹幕仍在发送');
    if (text.trim().isEmpty) {
      return const DanmakuSendResult('rejected', '请输入弹幕');
    }
    _busy = true;
    final watch = Stopwatch()..start();
    void stage(String value) => Log.writeLog(
        '[Danmaku] site=$siteId stage=$value elapsedMs=${watch.elapsedMilliseconds}');
    stage('start');
    try {
      try {
        await _ensureInitialized();
      } catch (_) {
        return const DanmakuSendResult(
            'initialization_error', '网页启动失败或超时，本次未发送，可点击发送重试');
      }
      if (_closed || _view == null) {
        return const DanmakuSendResult('closed', '直播间已切换');
      }
      stage('browser_created');
      final readiness = Stopwatch()..start();
      DanmakuSendResult? lastReadiness;
      // Navigation can destroy the JS context. Retry only a read-only check;
      // once submitting the message, never retry even on an uncertain result.
      while (readiness.elapsed < const Duration(seconds: 8)) {
        if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
        try {
          final response = await _view!.callAsyncJavaScript(
            functionBody: DanmakuWebScripts.send,
            arguments: {'site': siteId, 'text': text, 'prepareOnly': true},
          ).timeout(const Duration(seconds: 2));
          final result = DanmakuSendResult.fromValue(response?.value);
          lastReadiness = result;
          if (result.status == 'ready') {
            if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
            // This call may click Send, so its failure is not retryable.
            stage('editor_ready');
            final sent = await _submit(text);
            stage(sent.sent ? 'confirmed' : 'unconfirmed_or_rejected');
            return sent;
          }
          // Guest/disabled markup can precede the logged-in account hydration.
          // Keep checking without submitting, rather than rejecting its first frame.
        } on TimeoutException {
          // Still loading; no send operation was invoked.
        } catch (_) {
          // A navigation may have replaced the document during the check.
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (lastReadiness?.status == 'login') return lastReadiness!;
      return const DanmakuSendResult(
          'not_ready', '网页发送区暂未就绪，本次未发送；请在搜索网页中检查登录或稍后重试');
    } on TimeoutException {
      return const DanmakuSendResult('unknown', '网页响应超时，发送结果未确认，请先查看聊天');
    } catch (_) {
      // Do not log credentials, script arguments or message text.
      return const DanmakuSendResult('error', '网页发送失败，请在搜索网页中检查账号后重试');
    } finally {
      stage('finished');
      _busy = false;
    }
  }

  Future<DanmakuSendResult> _submit(String text) async {
    final view = _view!;
    final handler = 'simpleLiveNativeInput${++_nextInputHandler}';
    var nativePhase = 0;
    view.addJavaScriptHandler(handlerName: handler, callback: (arguments) async {
      if (_closed || _isExistingViewCurrent?.call() == false || arguments.length != 1 || arguments.single is! Map) return false;
      final data = arguments.single as Map;
      try {
        if (data['action'] == 'edit' && nativePhase == 0) {
          nativePhase = 1;
          // CDP emits real browser input events; DOM setters are not native typing.
          await view.callDevToolsProtocolMethod(methodName: 'Input.insertText', parameters: {'text':text});
          return true;
        }
        if (data['action'] == 'submit' && data['enter'] == true && nativePhase == 1) {
          nativePhase = 2; // Never click twice, including after a native failure.
          for (final type in ['keyDown','keyUp']) {
            await view.callDevToolsProtocolMethod(methodName: 'Input.dispatchKeyEvent', parameters: {
              'type':type,'key':'Enter','code':'Enter','windowsVirtualKeyCode':13,'nativeVirtualKeyCode':13,
            });
          }
          return true;
        }
      } catch (_) { return false; }
      return false;
    });
    try {
      final response = await view.callAsyncJavaScript(
        functionBody: DanmakuWebScripts.send,
        arguments: {'site': siteId, 'text': text, 'prepareOnly': false, 'nativeInputHandler':handler},
      ).timeout(const Duration(seconds: 10));
      final value = response?.value;
      if (value is Map) {
        Log.writeLog(
            '[Danmaku] site=$siteId submitted=${value['submitted'] == true} '
            'status=${DanmakuSendResult.fromValue(value).status} nativePhase=$nativePhase '
            'ackElapsedMs=${value['elapsedMs'] is num ? value['elapsedMs'] : -1}');
      }
      return DanmakuSendResult.fromValue(response?.value);
    } catch (_) {
      Log.writeLog('[Danmaku] site=$siteId nativePhase=$nativePhase result=script_timeout_or_error');
      return const DanmakuSendResult('unknown', '发送结果未确认，请先查看聊天，避免重复发送');
    } finally {
      view.removeJavaScriptHandler(handlerName: handler);
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    final created = _created;
    if (created != null && !created.isCompleted) created.complete();
    try {
      await _initialization;
    } catch (_) {}
    await _releaseBrowser();
  }

  Future<void> _releaseBrowser() async {
    final browser = _browser;
    final environment = _environment;
    _browser = null;
    _environment = null;
    _view = null;
    await browser?.dispose();
    await environment?.dispose();
  }
}
