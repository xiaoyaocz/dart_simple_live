import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'core_error.dart';
import 'core_log.dart';
import 'platform_identity.dart';

enum DouyuQrStatus { waiting, scanned, expired, authorized }

/// 斗鱼 Passport 凭据工具：扫码登录与播放 Cookie 续期。
///
/// 参考来源（本文件大部分端点与流程由此二者验证可用）：
/// - safeAuth 续期（接口/参数/Set-Cookie 处理）：
///   SlotSun/dart_simple_live v1.8.13，douyu_utils.dart `refreshCookie`
///   （issue #182：ltp0 & dy_did 配置说明）
/// - 扫码登录流程（generateCode / japi/scan/auth 状态码 / 确认地址取凭据）：
///   fancerest-png/dart_simple_live PR #190 分支 `feat-douyu-qr-login`
///   （该 PR 未被 SlotSun 合并，实现经其 docs/douyu-qr-login.md 核对）
///
/// 设计要点：
/// - 扫码在 Passport 专用会话中完成，凭据（LTP0 / dy_did）由确认响应的
///   Set-Cookie 提供，不经过共享 HTTP 客户端与日志拦截器；
/// - 播放 Cookie 含 acf_jwt_token，过期时间在 JWT payload 的 exp（约 7 天），
///   过期后用 LTP0 + dy_did 调 safeAuth 换取新 Cookie，无需用户重新扫码；
/// - 平台撤销授权或续期凭据失效时需要重新扫码，本工具不承诺永久登录。
///
/// 即使请求被上层日志记录，App 的 Log 层也会对 cookie/ltp0 等字段统一打码。
class DouyuPassport {
  DouyuPassport({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  /// Passport 会话内的小型 Cookie 罐：按名字覆盖，仅用于扫码确认链路
  final Map<String, Cookie> _sessionCookies = {};
  CancelToken? _cancelToken;
  static final Uri _passportBase = Uri.parse('https://passport.douyu.com/');
  static const String _playUserAgent = PlatformIdentity.passportUserAgent;
  String _code = '';

  /// 本会话拿到的续期凭据（确认登录后可用）
  String get did => _sessionCookieValue('dy_did');
  String get ltp0 => _sessionCookieValue('LTP0');

  String _sessionCookieValue(String name) {
    return _sessionCookies[name.toLowerCase()]?.value ?? '';
  }

  /// 生成登录二维码，返回二维码内容（斗鱼 APP 扫码后确认）
  Future<String> generateQrCode() async {
    _sessionCookies.clear();
    _cancelToken = CancelToken();
    _code = '';
    // 官方页面生成二维码前先取设备号，失败则回退共享 did
    final device = await _passportRequest(
      _passportBase.resolve('/lapi/did/api/get'),
      query: const {'client_id': '1', 'callback': 'slive_did'},
    );
    final deviceId = device['data']?['did']?.toString() ?? '';
    _sessionCookies['dy_did'] = Cookie('dy_did', deviceId)
      ..domain = 'douyu.com'
      ..path = '/';
    final result = await _passportRequest(
      _passportBase.resolve('/scan/generateCode'),
      data: const {'client_id': '1', 'isMultiAccount': '0'},
    );
    if (result['error'] != 0 ||
        result['data']?['code'] == null ||
        result['data']?['url'] == null) {
      throw CoreError("斗鱼二维码生成失败，请刷新重试");
    }
    _code = result['data']['code'].toString();
    return result['data']['url'].toString();
  }

  /// 轮询扫码状态：waiting(未扫) / scanned(已扫待确认) / expired / authorized
  Future<DouyuQrStatus> poll() async {
    if (_code.isEmpty) {
      return DouyuQrStatus.expired;
    }
    final result = await _passportRequest(
      _passportBase.resolve('/japi/scan/auth'),
      query: {
        'code': _code,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    switch (result['error']) {
      case -2:
        return DouyuQrStatus.waiting;
      case 1:
        return DouyuQrStatus.scanned;
      case -1:
        return DouyuQrStatus.expired;
      case 0:
        // 确认登录后斗鱼返回一个设置持久化 Passport Cookie 的地址，
        // 访问后 Set-Cookie 里带上 HttpOnly 的 LTP0 与 dy_did
        final url = result['data']?['url']?.toString() ?? '';
        if (url.isEmpty) {
          throw CoreError("斗鱼未返回登录确认地址，请刷新二维码重试");
        }
        final confirmation = await _passportRequest(
          _passportBase.resolve(url),
          query: const {'callback': 'appClient_json_callback'},
        );
        if (confirmation['error'] != 0 || did.isEmpty || ltp0.isEmpty) {
          throw CoreError("斗鱼未返回续期凭据，请刷新二维码重试");
        }
        _code = '';
        return DouyuQrStatus.authorized;
      default:
        throw CoreError("斗鱼暂时无法确认登录，请刷新重试");
    }
  }

  void close() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _sessionCookies.clear();
    _code = '';
  }

  Future<Map<String, dynamic>> _passportRequest(
    Uri uri, {
    Map<String, String>? query,
    Map<String, String>? data,
  }) async {
    if (query != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    // 手动跟随跳转：凭据经 Set-Cookie 下发，自动跳转会丢响应头
    for (var redirects = 0; redirects < 5; redirects++) {
      if (uri.scheme != 'https' ||
          !(uri.host == 'douyu.com' || uri.host.endsWith('.douyu.com'))) {
        throw CoreError("斗鱼登录地址无效");
      }
      final response = await _dio.requestUri<String>(
        uri,
        data: data,
        cancelToken: _cancelToken,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
          headers: {
            'Referer': _passportBase.toString(),
            'Origin': 'https://passport.douyu.com',
            'User-Agent': _playUserAgent,
            'Cookie': _sessionCookies.entries
                .map((e) => '${e.key}=${e.value.value}')
                .join('; '),
          },
        ),
      );
      _absorbSetCookies(response.headers['set-cookie'], uri.host);
      final status = response.statusCode ?? 200;
      if (status >= 300) {
        final location = response.headers.value('location');
        if (location == null) {
          throw CoreError("斗鱼登录跳转失败");
        }
        uri = uri.resolve(location);
        data = null;
        continue;
      }
      var text = (response.data ?? '').trim();
      if (!text.startsWith('{')) {
        // JSONP 包裹（axiosJsonpCallback 等）时解包
        final callback =
            RegExp(r'^[\w.$]+\s*\(([\s\S]*)\)\s*;?$').firstMatch(text);
        if (callback == null) {
          throw CoreError("斗鱼登录响应无效");
        }
        text = callback.group(1)!;
      }
      return jsonDecode(text) as Map<String, dynamic>;
    }
    throw CoreError("斗鱼登录跳转次数过多");
  }

  void _absorbSetCookies(List<String>? rawList, String host) {
    for (final raw in rawList ?? const <String>[]) {
      try {
        final cookie = Cookie.fromSetCookieValue(raw);
        if (cookie.maxAge == 0 ||
            (cookie.expires != null &&
                !cookie.expires!.isAfter(DateTime.now()))) {
          _sessionCookies.remove(cookie.name.toLowerCase());
          continue;
        }
        // 按名字小写归一存储，dy_did/LTP0 大小写差异不影响取值
        _sessionCookies[cookie.name.toLowerCase()] = cookie;
      } catch (_) {
        // 单条 Set-Cookie 异常不中断登录流程
      }
    }
  }

  static const String _safeAuthUrl =
      'https://passport.douyu.com/lapi/passport/iframe/safeAuth';

  /// safeAuth 换票链的最大跳数
  static const int _renewMaxHops = 6;

  /// 用续期凭据换取新的播放 Cookie。
  ///
  /// safeAuth 不是"一次请求就下发 Cookie"：第一跳返回 302，Location 指向
  /// `www.douyu.com/api/passport/login?...&loginType=safeAuth` 的一次性登录地址，
  /// **真正的 acf_* 全套登录 Cookie 在第二跳（www 域）下发**，safeAuth 本身不重发 LTP0。
  /// 因此这里手动逐跳跟随 302，并把每一跳的 Set-Cookie 累积起来（只跟 302，不跟 200 页面）。
  ///
  /// [dio] 仅供单测注入；为空时内部自建（不经过 App 的日志拦截器）。
  static Future<String> refreshPlayCookie({
    required String dyDid,
    required String ltp0,
    Dio? dio,
  }) async {
    if (dyDid.isEmpty || ltp0.isEmpty) {
      throw CoreError("斗鱼续期凭据缺失，请重新扫码登录");
    }
    final ownsClient = dio == null;
    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      var uri = Uri.parse(_safeAuthUrl).replace(queryParameters: {
        'client_id': '1',
        't': now,
        '_': now,
        'callback': 'axiosJsonpCallback',
      });
      final fields = <String, String>{};
      var hops = 0;
      var finalStatus = 0;
      while (hops < _renewMaxHops) {
        hops++;
        final response = await client.get<String>(
          uri.toString(),
          options: Options(
            responseType: ResponseType.plain,
            // 手动跟随时序：302 必须作为正常响应返回，交给下面的 location 逻辑处理
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
            headers: {
              'User-Agent': _playUserAgent,
              'Referer': 'https://www.douyu.com/',
              'Origin': 'https://www.douyu.com',
              'Accept': '*/*',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              // 每一跳都带上原始凭据：换票链后段靠 LTP0 认人
              'Cookie': 'dy_did=$dyDid; LTP0=$ltp0',
            },
          ),
        );
        _collectSetCookieFields(response.headers['set-cookie'], fields);
        finalStatus = response.statusCode ?? 0;
        if (finalStatus >= 300 && finalStatus < 400) {
          final location = response.headers.value('location');
          if (location == null || location.isEmpty) {
            break;
          }
          uri = _resolveRenewRedirect(uri, location);
          continue;
        }
        break;
      }
      final cookie = _joinCookieFields(fields);
      if (!_isRenewedCookieUsable(cookie)) {
        CoreLog.d(
          "斗鱼 safeAuth 未换到可用 Cookie：hops=$hops status=$finalStatus "
          "fields=${fields.keys.join(',')}",
        );
        throw CoreError("斗鱼续期失败，请重新扫码登录");
      }
      return cookie;
    } on DioException catch (e) {
      throw CoreError("斗鱼续期请求失败：${e.message ?? '网络异常'}");
    } finally {
      if (ownsClient) {
        client.close(force: true);
      }
    }
  }

  /// 累积每一跳的 Set-Cookie：空值 / Max-Age=0 视为删除，其余按名字大小写不敏感覆盖
  static void _collectSetCookieFields(
    List<String>? rawList,
    Map<String, String> fields,
  ) {
    for (final raw in rawList ?? const <String>[]) {
      Cookie cookie;
      try {
        cookie = Cookie.fromSetCookieValue(raw);
      } catch (_) {
        continue;
      }
      final lowerName = cookie.name.toLowerCase();
      fields.removeWhere((key, _) => key.toLowerCase() == lowerName);
      final cleared = cookie.maxAge == 0 ||
          (cookie.expires != null &&
              !cookie.expires!.isAfter(DateTime.now()));
      if (cleared || cookie.value.isEmpty) {
        continue;
      }
      fields[cookie.name] = cookie.value;
    }
  }

  static String _joinCookieFields(Map<String, String> fields) {
    return fields.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 换票结果是否可用：优先用 acf_jwt_token 的 exp 判定；
  /// 换票链也可能只下发 acf_* 基础登录字段，此时以 acf_uid + acf_auth 齐全为准。
  static bool _isRenewedCookieUsable(String cookie) {
    if (cookie.isEmpty) {
      return false;
    }
    if (cookieValue(cookie, 'acf_jwt_token').isNotEmpty) {
      return !isCookieExpired(cookie);
    }
    return cookieValue(cookie, 'acf_uid').isNotEmpty &&
        cookieValue(cookie, 'acf_auth').isNotEmpty;
  }

  /// 解析（可能为 `//host` 或相对形式的）Location，并限制在斗鱼域名内
  static Uri _resolveRenewRedirect(Uri base, String location) {
    var raw = location.trim();
    if (raw.startsWith('//')) {
      raw = '${base.scheme}:$raw';
    }
    final next = base.resolve(raw);
    if (next.scheme != 'https' ||
        !(next.host == 'douyu.com' || next.host.endsWith('.douyu.com'))) {
      throw CoreError("斗鱼登录地址无效");
    }
    return next;
  }

  /// 从 Set-Cookie 响应头列表提取"名=值"播放 Cookie 串
  static String cookiesFromSetCookie(List<String>? rawList) {
    return (rawList ?? const <String>[])
        .map((raw) => raw.split(';').first.trim())
        .where((pair) => pair.isNotEmpty && pair.contains('='))
        .join('; ');
  }

  /// 播放 Cookie 是否已过期：以 acf_jwt_token 的 JWT exp 为准
  static bool isCookieExpired(String cookie) {
    final jwt = cookieValue(cookie, 'acf_jwt_token');
    if (jwt.isEmpty) {
      return true;
    }
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) {
        return true;
      }
      final normalized = base64Url.normalize(parts[1].replaceAll('=', ''));
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'];
      if (exp is! int) {
        return true;
      }
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return true;
    }
  }

  /// 从 Cookie 串中解析指定键的值（缺失返回空串）
  static String cookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final pair = part.trim();
      final idx = pair.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      if (pair.substring(0, idx).trim().toLowerCase() == name.toLowerCase()) {
        return pair.substring(idx + 1).trim();
      }
    }
    return '';
  }
}
