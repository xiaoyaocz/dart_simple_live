import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';
import 'package:simple_live_core/simple_live_core.dart';

export 'danmaku_sender.dart';

/// Credential-only HTTP transport. Never creates/navigates an editor WebView.
class NativeDanmakuSender implements DanmakuSender {
  NativeDanmakuSender(
      {required this.siteId,
      required this.roomId,
      required DanmakuCredentials credentials,
      String? webRoomId,
      Dio? dio,
      String Function(String, String)? signDouyin})
      : _credentials = credentials,
        webRoomId = webRoomId ?? roomId,
        _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                sendTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 5),
                followRedirects: false)),
        _signDouyin = signDouyin ?? DouyinSign.getAbogusUrl;

  final String siteId, roomId, webRoomId;
  final DanmakuCredentials _credentials;
  final Dio _dio; // Deliberately no application's URL/body logging interceptor.
  final String Function(String, String) _signDouyin;
  final _cancel = CancelToken();
  bool _closed = false, _busy = false;
  Uri get _endpoint => Uri.parse(siteId == 'bilibili'
      ? 'https://api.live.bilibili.com/msg/send'
      : 'https://live.douyin.com/webcast/room/chat/');

  @override
  void prepare() {
    if (_closed) return;
    // Only warms credential access; current cookies are read again on send.
    unawaited(
        _credentials(_endpoint).then<void>((_) {}).catchError((Object _) {}));
  }

  @override
  Future<DanmakuSendResult> send(String text) async {
    if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
    if (_busy) return const DanmakuSendResult('busy', '上一条弹幕仍在发送');
    if (text.trim().isEmpty)
      return const DanmakuSendResult('rejected', '请输入弹幕');
    _busy = true;
    var submitted = false;
    final watch = Stopwatch()..start();
    try {
      final cookies =
          await _credentials(_endpoint).timeout(const Duration(seconds: 5));
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      final loggedIn = siteId == 'bilibili'
          ? (cookies['SESSDATA']?.isNotEmpty == true &&
              cookies['bili_jct']?.isNotEmpty == true)
          : ['sessionid', 'sessionid_ss', 'sid_guard']
              .any((k) => cookies[k]?.isNotEmpty == true);
      if (!loggedIn) return const DanmakuSendResult('login', '请在搜索网页中登录当前平台账号');
      final headers = <String, dynamic>{
        'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        'User-Agent': DouyinSite.kDefaultUserAgent,
        'Origin': siteId == 'bilibili'
            ? 'https://live.bilibili.com'
            : 'https://live.douyin.com',
        'Referer': siteId == 'bilibili'
            ? 'https://live.bilibili.com/$webRoomId'
            : 'https://live.douyin.com/$webRoomId',
      };
      late final Response<dynamic> response;
      if (siteId == 'bilibili') {
        submitted = true;
        response = await _dio.post<dynamic>(_endpoint.toString(),
            data: {
              'bubble': 0,
              'msg': text,
              'color': 16777215,
              'mode': 1,
              'fontsize': 25,
              'rnd': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'roomid': roomId,
              'csrf': cookies['bili_jct'],
              'csrf_token': cookies['bili_jct'],
            },
            options: Options(
                headers: headers,
                contentType: Headers.formUrlEncodedContentType),
            cancelToken: _cancel);
      } else {
        final uri = _endpoint.replace(queryParameters: {
          'aid': '6383',
          'app_name': 'douyin_web',
          'live_id': '1',
          'device_platform': 'web',
          'room_id': roomId,
          'content': text,
          'type': '0',
          'browser_language': 'zh-CN',
          'browser_platform': 'Win32',
          'browser_name': 'Chrome',
          'browser_version': '125.0.0.0',
          if (cookies['msToken']?.isNotEmpty == true)
            'msToken': cookies['msToken']!,
        });
        final signed =
            _signDouyin(uri.toString(), headers['User-Agent'] as String);
        if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
        submitted = true;
        response = await _dio.get<dynamic>(signed,
            options: Options(headers: headers), cancelToken: _cancel);
      }
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is! Map)
        return const DanmakuSendResult('unknown', '平台未返回有效结果，请先查看聊天，避免重复发送');
      final code = data[siteId == 'douyin' ? 'status_code' : 'code'];
      Log.writeLog(
          '[Danmaku] site=$siteId source=native responseCode=${int.tryParse('$code') ?? -1}');
      // Bilibili may return code=0 with msg="..."/message="f" for filtered chat.
      final blocked = siteId == 'bilibili' &&
          ((data['msg']?.toString().isNotEmpty == true) ||
              data['message'] == 'f');
      if ((code == 0 || code == '0') && !blocked)
        return const DanmakuSendResult('sent', '发送成功');
      if (code == null)
        return const DanmakuSendResult('unknown', '平台未确认发送，请先查看聊天，避免重复发送');
      // Do not display arbitrary response data that may contain account identifiers.
      final login = [-101, -111, 401].contains(int.tryParse('$code'));
      return DanmakuSendResult(
          login ? 'login' : 'rejected',
          login
              ? '登录已失效，请在搜索网页中重新登录'
              : '平台拒绝发送，请检查禁言、实名要求或发送频率（${int.tryParse('$code') ?? -1}）');
    } catch (_) {
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      return DanmakuSendResult(submitted ? 'unknown' : 'not_ready',
          submitted ? '发送结果未确认，请先查看聊天，避免重复发送' : '读取网页登录状态失败，本次未发送');
    } finally {
      Log.writeLog(
          '[Danmaku] site=$siteId source=native submitted=$submitted elapsedMs=${watch.elapsedMilliseconds}');
      _busy = false;
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _cancel.cancel();
    _dio.close(force: true);
  }
}
