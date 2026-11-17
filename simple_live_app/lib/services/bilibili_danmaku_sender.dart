import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'danmaku_sender.dart';

/// Bilibili's form API does not depend on the official room SPA/player loading.
class BilibiliDanmakuSender implements DanmakuSender {
  BilibiliDanmakuSender(
      {required this.roomId, required DanmakuCredentials credentials, Dio? dio})
      : _credentials = credentials,
        _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
                followRedirects: false));
  static final endpoint = Uri.https('api.live.bilibili.com', '/msg/send');
  final String roomId;
  final DanmakuCredentials _credentials;
  final Dio _dio;
  final _cancel = CancelToken();
  final _uncertain = <String>{};
  bool _closed = false, _busy = false;

  @override
  void prepare() {} // Cookie reads occur on explicit sends, including logout.

  @override
  Future<DanmakuSendResult> send(String text) async {
    if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
    if (_busy) return const DanmakuSendResult('busy', '上一条弹幕仍在发送');
    if (text.trim().isEmpty) {
      return const DanmakuSendResult('rejected', '请输入弹幕');
    }
    if (_uncertain.contains(text) || _uncertain.length >= 100) {
      return const DanmakuSendResult('unknown', '此弹幕结果未确认，请先查看聊天，避免重复发送');
    }
    _busy = true;
    var submitted = false;
    try {
      final cookies =
          await _credentials(endpoint).timeout(const Duration(seconds: 5));
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      if (cookies['SESSDATA']?.isNotEmpty != true ||
          cookies['bili_jct']?.isNotEmpty != true) {
        return const DanmakuSendResult('login', '请在搜索网页中登录哔哩哔哩');
      }
      submitted = true;
      final response = await _dio.post<dynamic>(endpoint.toString(),
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
          options:
              Options(contentType: Headers.formUrlEncodedContentType, headers: {
            'Cookie':
                cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
            'Origin': 'https://live.bilibili.com',
            'Referer': 'https://live.bilibili.com/$roomId',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          }),
          cancelToken: _cancel);
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      final code = data is Map ? data['code'] : null;
      if (code is! num && code is! String) {
        _uncertain.add(text);
        return const DanmakuSendResult('unknown', '平台未返回有效结果，请先查看聊天');
      }
      final filtered = (data['msg']?.toString().isNotEmpty == true) ||
          data['message'] == 'f';
      if ((code == 0 || code == '0') && !filtered) {
        return DanmakuSendResult('sent', '平台已确认发送',userId:cookies['DedeUserID']);
      }
      final login = [-101, -111, 401].contains(int.tryParse('$code'));
      return DanmakuSendResult(
          login ? 'login' : 'rejected',
          login
              ? '登录已失效，请在搜索网页重新登录'
              : '平台拒绝或屏蔽弹幕，请检查实名、禁言和频率限制（${int.tryParse('$code') ?? -1}）');
    } on DioException catch (error) {
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      if (error.response != null) {
        if ((error.response!.statusCode ?? 500) >= 500) {
          _uncertain.add(text);
          return const DanmakuSendResult('unknown', '平台服务异常，发送结果未确认，请先查看聊天');
        }
        return DanmakuSendResult(
            'rejected', '平台拒绝请求（HTTP ${error.response!.statusCode}）');
      }
      if (submitted) _uncertain.add(text);
      return DanmakuSendResult(submitted ? 'unknown' : 'not_ready',
          submitted ? '网络中断，发送结果未确认，请先查看聊天' : '读取登录态失败，本次未发送');
    } catch (_) {
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      if (submitted) _uncertain.add(text);
      return DanmakuSendResult(submitted ? 'unknown' : 'not_ready',
          submitted ? '发送结果未确认，请先查看聊天' : '读取登录态失败，本次未发送');
    } finally {
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
