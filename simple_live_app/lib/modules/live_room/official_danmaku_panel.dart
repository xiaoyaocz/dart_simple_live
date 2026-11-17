import 'dart:async';
import 'dart:collection';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:simple_live_app/services/official_danmaku_layout.dart';
import 'package:simple_live_app/services/official_danmaku_session.dart';
import 'package:simple_live_app/services/official_composer_transport.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/search_web_session.dart';

/// Official protocol host, optionally bound to the shared Flutter composer.
class OfficialDanmakuPanel extends StatefulWidget {
  const OfficialDanmakuPanel({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.roomUri,
    this.searchEnvironment,
    required this.expanded,
    required this.focusRequest,
    required this.onExpandedChanged,
    required this.onFocusedChanged,
    this.onEmojiChanged,
    this.onSelfNameDetected,
    this.onMessageSent,
    this.allowedRoomIds = const [],
    this.confirmationRoomIds = const [],
    this.composerTransport,
    this.onIdentityDetected,
    this.onConnectionMessage,
  });

  final bool expanded;
  final ValueChanged<String>? onConnectionMessage;
  final OfficialComposerTransport? composerTransport;
  final void Function(String? userId,String? userName)? onIdentityDetected;
  final Iterable<String> allowedRoomIds;
  final Iterable<String> confirmationRoomIds;
  final int focusRequest;
  final ValueChanged<bool> onExpandedChanged, onFocusedChanged;
  final ValueChanged<bool>? onEmojiChanged;
  final ValueChanged<String>? onSelfNameDetected;
  final ValueChanged<String>? onMessageSent;
  final String siteId, siteName;
  final Uri roomUri;
  // Borrow the active search profile instead of guessing which account to use.
  final Future<WebViewEnvironment?>? searchEnvironment;

  @override
  State<OfficialDanmakuPanel> createState() => _OfficialDanmakuPanelState();
}

class _OfficialDanmakuPanelState extends State<OfficialDanmakuPanel> {
  late Future<WebViewEnvironment?> _environment;
  WebViewEnvironment? _ownedEnvironment;
  InAppWebViewController? _view;
  Widget? _browser;
  Completer<WebViewEnvironment>? _startup;
  Timer? _startupTimer;
  bool _loadingEnvironment = false;
  bool _useSearchEnvironment = true;
  String _layoutStatus = 'loading';
  Timer? _layoutDeadline;
  bool _recoveringRoom = false;
  List<String> get _allowedRooms =>
      {...widget.allowedRoomIds, ...widget.roomUri.pathSegments}.toList();
  String? _error;
  String _sendStatus = 'idle';
  String _sendMessage = '由平台官方登录态发送';
  int? _sendingId;
  String? _sendingDocument;
  Completer<DanmakuSendResult>? _composerPending;
  final _uncertainDrafts = <String>{};
  static int _nextComposerHandler = 0;

  Future<DanmakuSendResult> _sendFromComposer(String text) async {
    if (_composerPending != null) return const DanmakuSendResult('busy','上一条弹幕仍在发送');
    final view = _view;
    if (mounted && view == null && _error != null) {
      final error=_error!;
      unawaited(_reload()); // No live page exists; recover startup, not a send.
      return DanmakuSendResult('not_ready','$error；正在重新连接，本次未提交');
    }
    if (!mounted || view == null) {
      return DanmakuSendResult('not_ready',_error ?? '平台发送连接正在启动，请稍后发送');
    }
    // Flutter's loading/error mirror can lag behind the live document (including
    // after the UI deadline). The submit bridge verifies current editor AND
    // protocol readiness before touching the draft. Never reload on Send:
    // doing so can tear down a slow connection just as it becomes usable.
    if (_uncertainDrafts.contains(text) || _uncertainDrafts.length >= 100) {
      return const DanmakuSendResult('unknown','此弹幕结果未确认，请先查看聊天，避免重复发送');
    }
    final pending = _composerPending = Completer<DanmakuSendResult>();
    final handler = 'simpleLiveComposer${++_nextComposerHandler}';
    var edited = false, submitted = false;
    view.addJavaScriptHandler(handlerName:handler, callback:(args) async {
      if (!mounted || !identical(view,_view) || !identical(pending,_composerPending) || args.length != 1 || args.single is! Map) return false;
      final data=args.single as Map;
      try {
        if (data['action']=='edit' && !edited) {
          edited=true;
          await view.callDevToolsProtocolMethod(methodName:'Input.insertText',parameters:{'text':text});
          return true;
        }
        if (data['action']=='submit' && edited && !submitted) {
          submitted=true; // Submission may happen before a native error is returned.
          if(data['enter']==true) {
            for(final type in ['keyDown','keyUp']) {
              await view.callDevToolsProtocolMethod(methodName:'Input.dispatchKeyEvent',parameters:{'type':type,'key':'Enter','code':'Enter','windowsVirtualKeyCode':13});
            }
          } else {
            final x=data['x'],y=data['y'];
            if(x is! num || y is! num || !x.isFinite || !y.isFinite || x<0 || y<0 || x>10000 || y>10000) return false;
            for(final type in ['mousePressed','mouseReleased']) {
              await view.callDevToolsProtocolMethod(methodName:'Input.dispatchMouseEvent',parameters:{'type':type,'x':x,'y':y,'button':'left','clickCount':1});
            }
          }
          return true;
        }
      } catch (_) { return false; }
      return false;
    });
    try {
      final operation = await view.callAsyncJavaScript(functionBody:OfficialComposerTransport.submit,
        arguments:{'text':text,'handler':handler}).timeout(const Duration(seconds:18));
      final value=operation?.value;
      final result = value is Map && value['status']=='submitted'
        ? await pending.future.timeout(const Duration(seconds:12),onTimeout:()=>const DanmakuSendResult('unknown','平台未确认发送，请先查看聊天'))
        : value is Map && value['status'] is String && value['message'] is String
          ? DanmakuSendResult(value['status'] as String,value['message'] as String)
          : const DanmakuSendResult('unknown','发送结果未确认，请先查看聊天');
      if(result.status=='unknown') _uncertainDrafts.add(text);
      return result;
    } catch (_) {
      if(submitted) _uncertainDrafts.add(text);
      return DanmakuSendResult(submitted?'unknown':'not_ready',submitted?'发送结果未确认，请先查看聊天':'平台输入连接中断，本次未提交');
    } finally {
      view.removeJavaScriptHandler(handlerName:handler);
      if(identical(_composerPending,pending)) _composerPending=null;
    }
  }

  void _acceptSend(dynamic value) {
    if (!mounted || value is! Map || value['message'] is! String) return;
    final status = value['status'];
    if(status=='identity') {
      widget.onIdentityDetected?.call(value['userId'] is String ? value['userId'] as String : null,
        value['userName'] is String ? value['userName'] as String : null);
      return;
    }
    if (!const {'sending', 'busy', 'sent', 'rejected', 'login', 'unknown', 'unsupported'}
        .contains(status)) {
      return;
    }
    final id = value['id'];
    if (status == 'sending') {
      if (id is! int || _sendingId != null || value['documentId'] is! String) return;
      _sendingId = id;
      _sendingDocument = value['documentId'] as String;
    } else if (id != null) {
      // An old document/attempt must not complete a newer room's send.
      if (id != _sendingId || value['documentId'] != _sendingDocument) return;
      _sendingId = null;
    }
    setState(() {
      _sendStatus = _sendingId == null ? status as String : 'sending';
      _sendMessage = value['message'] as String;
    });
    if (status == 'sent' && id != null && value['text'] is String) {
      widget.onMessageSent?.call(value['text'] as String);
    }
    if(status != 'sending' && status != 'busy' && _composerPending?.isCompleted == false) {
      _composerPending!.complete(DanmakuSendResult(status as String,value['message'] as String,
        userId:value['userId'] is String ? value['userId'] as String : null,
        userName:value['userName'] is String ? value['userName'] as String : null));
    }
  }

  // The native surface includes the emoji overlay even while it is clipped.
  // Loading/retry controls must stay in its always-visible bottom 56px.
  Widget _statusBar(Widget child) => Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(height: 56, child: Center(child: child)));

  void _watchLayout() {
    _layoutDeadline?.cancel();
    _layoutDeadline = Timer(const Duration(seconds: 20), () {
      if (mounted && _layoutStatus != 'ready') {
        setState(() => _error = '输入区尚未就绪，请重试或在搜索网页检查登录、验证');
        widget.onConnectionMessage?.call(_error!);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.composerTransport?.bind(this,_sendFromComposer);
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
    } catch (error, stack) {
      // FutureBuilder renders errors without reporting them to Flutter's global
      // handler. Keep the native failure for diagnosis instead of swallowing it.
      if (mounted) {
        Log.e('官方弹幕网页环境启动失败（${widget.siteId}）：$error', stack);
        _error = _startupErrorText(error);
        widget.onConnectionMessage?.call(_error!);
      }
      rethrow;
    } finally {
      _loadingEnvironment = false;
      _startupTimer?.cancel();
      _startupTimer = null;
      _startup = null;
    }
  }

  String _startupErrorText(Object? error) {
    if (error is TimeoutException) return '网页组件启动超时，重试不会清除登录状态';
    if (error is MissingPluginException) return '网页组件未加载，请完整安装并重启软件';
    if (error is PlatformException) {
      final code = int.tryParse(error.code);
      if (code != null) {
        return '启动错误：0x${code.toUnsigned(32).toRadixString(16).padLeft(8, '0')}';
      }
    }
    return '启动异常：${error.runtimeType}，具体原因已记录到日志';
  }

  @override
  void dispose() {
    widget.composerTransport?.unbind(this);
    if(_composerPending?.isCompleted==false) _composerPending!.complete(const DanmakuSendResult('closed','直播间已切换'));
    _view = null;
    _layoutDeadline?.cancel();
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
      setState(() { _error = null; _layoutStatus = 'loading'; });
      _watchLayout();
      try {
        await view.reload();
      } catch (_) {
        if (mounted) setState(() => _error = '网页刷新失败，请关闭后重新打开');
      }
    } else if (!_loadingEnvironment && _browser == null) {
      final pending = _createEnvironment();
      setState(() {
        _error = null;
        _environment = pending;
      });
    }
  }

  @override
  void didUpdateWidget(covariant OfficialDanmakuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      unawaited(_setMode());
    }
    if (widget.focusRequest > oldWidget.focusRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_focusEditor());
      });
    }
  }

  Future<void> _setMode() async {
    try {
      await _view?.evaluateJavascript(
          source:
              'window.__simpleLiveOfficialEditor?.setExpanded(${widget.expanded});');
    } catch (_) {/* Navigation replaces the old JavaScript context. */}
  }

  void _accept(dynamic value) {
    if (!mounted || value is! Map) return;
    if (value['emojiOpen'] is bool) {
      widget.onEmojiChanged?.call(value['emojiOpen'] as bool);
    }
    if (value['selfName'] is String) {
      final name = (value['selfName'] as String).trim();
      if (name.isNotEmpty) widget.onSelfNameDetected?.call(name);
    }
    if (value['status'] == 'wrong_room') {
      unawaited(_recoverRoom());
      return;
    }
    if (value['focused'] is bool)
      widget.onFocusedChanged(value['focused'] as bool);
    if (value['status'] == 'needs_page' || value['status'] == 'requires_login') {
      Log.w('官方发言栏需要在搜索网页完成登录或验证');
      widget.onConnectionMessage?.call('请在搜索网页完成当前平台的登录或验证');
    }
    final status = value['status'];
    if (status == 'loading' && _layoutStatus == 'ready') {
      _watchLayout();
      setState(() {
        _layoutStatus = 'loading';
        _error = '输入区已更新，可展开检查登录或验证';
      });
    }
    if(status == 'loading' && value['protocolStatus'] is String) {
      const phases={'runtime':'正在加载平台官方运行时…','module':'正在加载平台发送组件…','sdk':'正在等待平台官方连接就绪…'};
      final message=phases[value['protocolStatus']];
      if(message!=null) widget.onConnectionMessage?.call(message);
    }
    if (status == 'ready') {
      _layoutDeadline?.cancel();
      if (_layoutStatus != 'ready') {
        setState(() {
          _layoutStatus = 'ready';
          _error = null;
        });
        widget.onConnectionMessage?.call('平台发送区已就绪');
      }
    }
  }

  Future<void> _install() async {
    final view = _view;
    if (view == null || !mounted) return;
    try {
      final result = await view.callAsyncJavaScript(
          functionBody: OfficialDanmakuLayout.install,
          arguments: {
            'site': widget.siteId,
            'expectedRoomIds': _allowedRooms
          }).timeout(const Duration(seconds: 3));
      if (!mounted || !identical(view, _view)) return;
      _accept(result?.value);
      await _setMode();
      if (widget.focusRequest > 0) await _focusEditor();
    } catch (_) {
      if (mounted) setState(() => _error = '输入区未就绪，可展开网页登录或验证');
    }
  }

  Future<void> _focusEditor() async {
    final view = _view;
    if (view == null || !mounted) return;
    DefaultTabController.maybeOf(context)?.animateTo(0);
    try {
      // DOM focus alone does not move Windows keyboard focus from Flutter.
      final native = view.platform;
      if (native is WindowsInAppWebViewController) await native.requestFocus();
      await view.evaluateJavascript(
          source: 'window.__simpleLiveOfficialEditor?.focus();');
    } catch (_) {
      if (mounted) setState(() => _error = '点击官方输入框即可输入');
    }
  }

  bool _wrongRoom(Uri? uri) {
    if (uri == null) return false;
    final id = SearchRoomUrl.roomIdFor(widget.siteId, uri);
    return id != null &&
        !{
          ...widget.allowedRoomIds,
          ...widget.roomUri.pathSegments,
        }.contains(id);
  }

  Future<void> _recoverRoom() async {
    if (!mounted || _view == null || _recoveringRoom) return;
    _recoveringRoom = true;
    widget.onFocusedChanged(false);
    setState(() => _error = '正在返回播放器对应的直播间…');
    try {
      await _view!.loadUrl(
          urlRequest: URLRequest(url: WebUri(widget.roomUri.toString())));
    } catch (_) {
      _recoveringRoom = false;
      if (mounted) setState(() => _error = '请刷新以返回当前直播间');
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(children: [
          Expanded(
              child: FutureBuilder<WebViewEnvironment?>(
            future: _environment,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                if (!widget.expanded) {
                  return _statusBar(Tooltip(
                      message: _startupErrorText(snapshot.error),
                      child: TextButton(onPressed: _reload,
                          child: const Text('启动失败，点击重试'))));
                }
                return Center(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                        onPressed: _reload,
                        child: const Text('网页组件启动失败，点击重试')),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(_startupErrorText(snapshot.error),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11))),
                  ],
                ));
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return _statusBar(
                    const Text('正在加载官方输入区…', style: TextStyle(fontSize: 12)));
              }
              final browser = _browser ??= InAppWebView(
                webViewEnvironment: snapshot.data,
                initialUrlRequest:
                    URLRequest(url: WebUri(widget.roomUri.toString())),
                initialSettings: InAppWebViewSettings(
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: true),
                initialUserScripts: UnmodifiableListView([
                  UserScript(
                    source: '(function(site, expectedRoomIds) {${OfficialDanmakuSession.install}})(${jsonEncode(widget.siteId)}, ${jsonEncode({..._allowedRooms, ...widget.confirmationRoomIds}.toList())});',
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                  ),
                  UserScript(
                    source:
                        '(function(site, expectedRoomIds, install) {${OfficialDanmakuLayout.bootstrap}})(${jsonEncode(widget.siteId)}, ${jsonEncode(_allowedRooms)}, function(site, expectedRoomIds) {${OfficialDanmakuLayout.install}});',
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  )
                ]),
                onWebViewCreated: (view) {
                  if (!mounted) return;
                  _view = view;
                  view.addJavaScriptHandler(
                      handlerName: 'simpleLiveDanmakuState',
                      callback: (args) {
                        if (args.length == 1) _acceptSend(args.single);
                        return null;
                      });
                  // The initial navigation may start before callbacks attach.
                  // A skeleton/blocked room must still expose bounded retry UI.
                  _watchLayout();
                  view.addJavaScriptHandler(
                      handlerName: 'simpleLiveOfficialEditor',
                      callback: (args) {
                        if (args.length == 1) _accept(args.single);
                        return null;
                      });
                },
                onLoadStart: (_, __) {
                  if (!mounted) return;
                  if(_composerPending?.isCompleted==false) _composerPending!.complete(const DanmakuSendResult('unknown','平台网页已刷新，发送结果未确认'));
                  widget.onFocusedChanged(false);
                  setState(() {
                    _layoutStatus = 'loading';
                    _error = null;
                    _sendingId = null;
                    _sendingDocument = null;
                    _sendStatus = 'idle';
                    _sendMessage = '网页已刷新，发送状态已重置';
                  });
                  _watchLayout();
                },
                onLoadStop: (_, url) async {
                  if (_wrongRoom(url)) {
                    await _recoverRoom();
                    return;
                  }
                  _recoveringRoom = false;
                  await _install();
                },
                onProgressChanged: (_, progress) {
                  // This plugin emits 66 at DOMContentLoaded. Do not wait for
                  // NavigationCompleted/live ads before accepting layout state.
                  if (progress == 66) unawaited(_install());
                },
                onReceivedError: (_, request, error) {
                  if (!mounted ||
                      request.isForMainFrame != true ||
                      error.type == WebResourceErrorType.CANCELLED) return;
                  _layoutDeadline?.cancel();
                  setState(() => _error = '官方网页加载失败，请点击刷新重试');
                },
                shouldOverrideUrlLoading: (_, action) async {
                  if (action.isForMainFrame && _wrongRoom(action.request.url)) {
                    if (mounted)
                      setState(() => _error = '请在播放器中切换直播间，输入区保持当前房间');
                    return NavigationActionPolicy.CANCEL;
                  }
                  final scheme = action.request.url?.scheme;
                  return scheme == 'https' ||
                          scheme == 'http' ||
                          scheme == 'about'
                      ? NavigationActionPolicy.ALLOW
                      : NavigationActionPolicy.CANCEL;
                },
                onUpdateVisitedHistory: (view, url, _) async {
                  if (!mounted || !_wrongRoom(url)) return;
                  // SPA navigation cannot silently retarget this room's input.
                  await _recoverRoom();
                },
                onCreateWindow: (_, __) async => false,
              );
              return Stack(fit: StackFit.expand, children: [
                Padding(padding: const EdgeInsets.only(bottom: 24), child: browser),
                Positioned(left: 8, right: 8, bottom: 0, height: 24,
                  child: Semantics(liveRegion: true, child: Row(children: [
                    if (_sendStatus == 'sending') ...[
                      const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Tooltip(message: _sendMessage,
                      child: Text(_sendMessage, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11,
                          color: const {'rejected','login','unknown','unsupported'}.contains(_sendStatus)
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant)))),
                  ]))),
                if (!widget.expanded &&
                    _layoutStatus != 'ready')
                  ColoredBox(
                          key: const ValueKey('official-editor-loading-cover'),
                          color: Theme.of(context).colorScheme.surface.withAlpha(255),
                          child: _statusBar(TextButton(
                              onPressed: _reload,
                              child: Text(_error == null
                                  ? '正在加载发言栏…'
                                  : '发言栏未就绪，点击重试',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12))))),
              ]);
            },
          )),
        ]),
      );
}
