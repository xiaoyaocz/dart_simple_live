import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/services/search_web_session.dart';

typedef SearchLoginView = ({
  InAppWebViewController view,
  bool Function() isCurrent
});

/// Only per-origin website credentials, in memory, never merged across profiles.
class SearchDanmakuCredentials {
  SearchDanmakuCredentials(
      {required this.siteId,
      this.existingView,
      this.isExistingViewCurrent,
      this.resolveView});
  final String siteId;
  final InAppWebViewController? existingView;
  final bool Function()? isExistingViewCurrent;
  final SearchLoginView? Function()? resolveView;
  Future<WebViewEnvironment>? _environment;
  bool _closed = false;
  bool? _direct;
  bool? _preferred;
  bool _bound = false;
  Future<void> _reads = Future.value();

  Future<Map<String, String>> read(Uri uri) async {
    // Warmup and explicit Send may overlap; serialize binding, not message sends.
    final pending = _reads.then((_) => _read(uri));
    _reads = pending.then<void>((_) {}).catchError((Object _) {});
    return pending;
  }

  Future<Map<String, String>> _read(Uri uri) async {
    if (_closed) throw StateError('Credentials closed');
    final allowed = switch (siteId) {
      'bilibili' => uri.host == 'api.live.bilibili.com',
      'douyu' => uri.host == 'www.douyu.com',
      'douyin' => uri.host == 'live.douyin.com',
      _ => false,
    };
    if (!allowed || uri.scheme != 'https')
      throw StateError('Unexpected credential origin');
    final active = resolveView?.call();
    final view = active?.view ?? existingView;
    final isCurrent = active?.isCurrent ?? isExistingViewCurrent;
    if (view != null && isCurrent?.call() == true) {
      // Once a visible account (including its logout) is authoritative, closing
      // that page must not silently restore an older alternate-profile account.
      await _releaseEnvironment();
      _preferred = SearchWebSession.usesDirect(siteId);
      _direct = _preferred;
      _bound = true;
      final value = await view.callDevToolsProtocolMethod(
          methodName: 'Network.getCookies',
          parameters: {
            'urls': [uri.toString()]
          });
      if (_closed) throw StateError('Credentials closed');
      if (isCurrent?.call() != true) throw StateError('Login page changed');
      return {
        for (final c in (value?['cookies'] as List? ?? []))
          if (c is Map && c['name'] is String && c['value'] is String)
            c['name'] as String: c['value'] as String
      };
    }
    final direct = SearchWebSession.usesDirect(siteId);
    if (_preferred != direct) {
      await _releaseEnvironment();
      _preferred = direct;
      _direct = direct;
      _bound = false;
    }
    var cookies = await _readProfile(uri);
    if (!_bound && !_hasLogin(cookies)) {
      // A networking retry used a second directory but did not move the login.
      // Select the WHOLE authenticated profile, never splice two accounts' cookies.
      await _releaseEnvironment();
      _direct = !direct;
      final other = await _readProfile(uri);
      if (_hasLogin(other)) {
        cookies = other;
      } else {
        await _releaseEnvironment();
        _direct = direct;
      }
    }
    _bound = true;
    return cookies;
  }

  bool _hasLogin(Map<String, String> cookies) => switch (siteId) {
        'bilibili' => cookies['SESSDATA']?.isNotEmpty == true &&
            cookies['bili_jct']?.isNotEmpty == true,
        'douyin' => ['sessionid', 'sessionid_ss', 'sid_guard']
            .any((k) => cookies[k]?.isNotEmpty == true),
        'douyu' => cookies['acf_username']?.isNotEmpty == true &&
            ['acf_auth_wl', 'acf_dmjwt_token']
                .any((k) => cookies[k]?.isNotEmpty == true),
        _ => false,
      };

  Future<Map<String, String>> _readProfile(Uri uri) async {
    if (_closed) throw StateError('Credentials closed');
    // Creates an environment/cookie manager only. No room URL is loaded.
    final pending = _environment ??= SearchWebSession.create(direct: _direct);
    late final WebViewEnvironment env;
    try {
      env = await pending;
    } catch (_) {
      if (identical(_environment, pending)) _environment = null;
      rethrow;
    }
    if (_closed) throw StateError('Credentials closed');
    final cookies = await CookieManager.instance(webViewEnvironment: env)
        .getCookies(url: WebUri(uri.toString()));
    if (_closed) throw StateError('Credentials closed');
    return {for (final c in cookies) c.name: '${c.value}'};
  }

  Future<void> _releaseEnvironment() async {
    final pending = _environment;
    _environment = null;
    try {
      await (await pending)?.dispose();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _closed = true;
    await _releaseEnvironment();
  }
}
