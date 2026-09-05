import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';
import 'package:simple_live_core/src/danmaku/douyin_emoji_assets.dart';
import 'package:simple_live_core/src/scripts/douyin_sign.dart';

import 'proto/douyin.pb.dart';

class DouyinDanmakuArgs {
  final String webRid;
  final String roomId;
  final String userId;
  final String cookie;
  DouyinDanmakuArgs({
    required this.webRid,
    required this.roomId,
    required this.userId,
    required this.cookie,
  });
  @override
  String toString() {
    return json.encode({
      "webRid": webRid,
      "roomId": roomId,
      "userId": userId,
      "cookie": cookie,
    });
  }
}

class DouyinDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 10 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://webcast3-ws-web-lq.douyin.com/webcast/im/push/v2/";
  late DouyinDanmakuArgs danmakuArgs;
  WebScoketUtils? webScoketUtils;
  final List<LiveMessage> _pendingChatMessages = <LiveMessage>[];
  Timer? _flushChatTimer;
  _DouyinImContext? _imContext;
  bool _contextRefreshUsed = false;
  static const int _maxChatFlushBatch = 50;
  static const Duration _chatFlushInterval = Duration(milliseconds: 80);

  @override
  Future start(dynamic args) async {
    final startStopwatch = Stopwatch()..start();
    danmakuArgs = args as DouyinDanmakuArgs;
    _contextRefreshUsed = false;
    try {
      _imContext = await _fetchImContext();
    } catch (e) {
      CoreLog.w("[DouyinDanmaku] 动态弹幕上下文获取失败，使用兼容地址：$e");
    }
    _openWebSocket(args);
    startStopwatch.stop();
    CoreLog.i(
      "[DouyinDanmaku] start(${danmakuArgs.webRid}) 耗时 ${startStopwatch.elapsedMilliseconds}ms",
    );
  }

  Map<String, String> _buildQueryParameters({
    String? cursor,
    String? internalExt,
    int? dynamicHeartbeat,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return {
      "app_name": "douyin_web",
      "version_code": "180800",
      "webcast_sdk_version": "1.3.0",
      "update_version_code": "1.3.0",
      "compress": "gzip",
      "resp_content_type": "protobuf",
      "cursor": cursor ?? "h-1_t-${ts}_r-1_d-1_u-1",
      "host": "https://live.douyin.com",
      "aid": "6383",
      "live_id": "1",
      "did_rule": "3",
      "debug": "false",
      "maxCacheMessageNumber": "20",
      "endpoint": "live_pc",
      "support_wrds": "1",
      "im_path": "/webcast/im/fetch/",
      "user_unique_id": danmakuArgs.userId,
      "device_platform": "web",
      "cookie_enabled": "true",
      "screen_width": "1920",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Mozilla",
      "browser_version": DouyinSite.kDefaultUserAgent.replaceAll(
        "Mozilla/",
        "",
      ),
      "browser_online": "true",
      "tz_name": "Asia/Shanghai",
      "identity": "audience",
      "room_id": danmakuArgs.roomId,
      "heartbeatDuration": dynamicHeartbeat?.toString() ?? "0",
      if (internalExt != null && internalExt.isNotEmpty)
        "internal_ext": internalExt,
    };
  }

  Map<String, dynamic> _signatureParameters() {
    return DouyinSign.getDefaultSignatureParams(
      danmakuArgs.roomId,
      danmakuArgs.userId,
    );
  }

  Map<String, dynamic> _socketHeaders() {
    return {
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
      "Cache-Control": "no-cache",
      "Pragma": "no-cache",
      "User-Agent": DouyinSite.kDefaultUserAgent,
      "Cookie": danmakuArgs.cookie,
      "Origin": "https://live.douyin.com",
      "Referer": "https://live.douyin.com/${danmakuArgs.webRid}",
    };
  }

  Future<_DouyinImContext?> _fetchImContext() async {
    try {
      final query = _buildQueryParameters();
      final signature = DouyinSign.getSignatureForParams(
        _signatureParameters(),
      );
      final unsignedUri = Uri.parse(
        "https://live.douyin.com/webcast/im/fetch/",
      ).replace(queryParameters: {...query, "signature": signature});
      final requestUrl = DouyinSign.getAbogusUrlWithMsToken(
        unsignedUri.toString(),
        DouyinSite.kDefaultUserAgent,
        msToken: _cookieValue("msToken"),
      );
      final bytes = await HttpClient.instance.getBytes(
        requestUrl,
        header: _socketHeaders(),
      );
      if (bytes.isEmpty) {
        CoreLog.w(
          "[DouyinDanmaku] IM 预取失败：空响应 cookie=${danmakuArgs.cookie.trim().isNotEmpty}",
        );
        return null;
      }
      final response = _decodeImResponse(bytes);
      final pushServer = response.pushServer.trim();
      final cursor = response.cursor.trim().isNotEmpty
          ? response.cursor.trim()
          : response.liveCursor.trim();
      if (cursor.isEmpty) {
        CoreLog.w("[DouyinDanmaku] IM 预取缺少动态游标");
        return null;
      }
      _consumeResponse(response);
      final duration = response.heartbeatDuration.toInt();
      if (duration > 0) {
        heartbeatTime = duration.clamp(1000, 120000);
      }
      CoreLog.i(
        "[DouyinDanmaku] IM 预取成功 host=${pushServer.isEmpty ? 'fallback' : _redactHost(pushServer)} heartbeat=${heartbeatTime}ms",
      );
      return _DouyinImContext(
        pushServer: pushServer.isEmpty ? serverUrl : pushServer,
        cursor: cursor,
        internalExt: response.internalExt,
        heartbeatDuration: duration,
      );
    } on CoreError catch (e) {
      final reason = e.statusCode == 444
          ? "HTTP 444 风控限制"
          : e.statusCode > 0
          ? "HTTP ${e.statusCode}"
          : e.message;
      CoreLog.w(
        "[DouyinDanmaku] IM 预取失败：$reason cookie=${danmakuArgs.cookie.trim().isNotEmpty}",
      );
      return null;
    } on FormatException catch (e) {
      CoreLog.w("[DouyinDanmaku] IM 预取 protobuf 解析失败：$e");
      return null;
    } catch (e) {
      CoreLog.w("[DouyinDanmaku] IM 预取响应不可用：$e");
      return null;
    }
  }

  Response _decodeImResponse(List<int> bytes) {
    var payload = bytes;
    if (payload.isNotEmpty && payload[0] == 0x7b) {
      throw const FormatException("响应为JSON，可能缺少protobuf参数或触发风控");
    }
    if (payload.length >= 2 && payload[0] == 0x1f && payload[1] == 0x8b) {
      payload = gzip.decode(payload);
    }
    return Response.fromBuffer(payload);
  }

  String? _cookieValue(String name) {
    for (final part in danmakuArgs.cookie.split(';')) {
      final pieces = part.trim().split('=');
      if (pieces.length >= 2 && pieces.first.trim() == name) {
        return pieces.sublist(1).join('=').trim();
      }
    }
    return null;
  }

  String _normalizePushServer(String value) {
    var server = value.trim();
    if (server.isEmpty) {
      return serverUrl;
    }
    if (!server.contains('://')) {
      server = 'wss://$server';
    }
    final uri = Uri.parse(server);
    return uri
        .replace(
          scheme: 'wss',
          path: uri.path.isEmpty || uri.path == '/'
              ? '/webcast/im/push/v2/'
              : uri.path,
        )
        .toString();
  }

  String _buildSocketUrl(String base, _DouyinImContext? context) {
    final uri = Uri.parse(base).replace(
      scheme: 'wss',
      queryParameters: {
        ..._buildQueryParameters(
          cursor: context?.cursor,
          internalExt: context?.internalExt,
          dynamicHeartbeat: context?.heartbeatDuration,
        ),
        "signature": DouyinSign.getSignatureForParams(_signatureParameters()),
      },
    );
    return uri.toString();
  }

  List<String> _socketUrls(_DouyinImContext? context) {
    final dynamicUrl = context == null
        ? null
        : _buildSocketUrl(_normalizePushServer(context.pushServer), context);
    final staticUrl = _buildSocketUrl(serverUrl, context);
    final urls = <String>[
      if (dynamicUrl != null && dynamicUrl.isNotEmpty) dynamicUrl,
      staticUrl,
      staticUrl.replaceAll('webcast3-ws-web-lq', 'webcast5-ws-web-lf'),
      staticUrl.replaceAll('webcast3-ws-web-lq', 'webcast5-ws-web-hl'),
      staticUrl.replaceAll('webcast3-ws-web-lq', 'webcast3-ws-web-hl'),
      staticUrl.replaceAll('webcast3-ws-web-lq', 'webcast3-ws-web-lf'),
    ];
    return urls.toSet().toList();
  }

  void _openWebSocket(dynamic args) {
    final urls = _socketUrls(_imContext);
    CoreLog.d(
      "[DouyinDanmaku] 连接弹幕服务器 room=${danmakuArgs.webRid} candidates=${urls.length} dynamic=${_imContext != null}",
    );
    webScoketUtils = WebScoketUtils(
      url: urls.first,
      backupUrls: urls.skip(1).toList(),
      headers: _socketHeaders(),
      heartBeatTime: heartbeatTime,
      onMessage: decodeMessage,
      onReady: () {
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: heartbeat,
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        CoreLog.w("[DouyinDanmaku] WebSocket 握手/连接失败：$e");
        if (!_contextRefreshUsed && _imContext != null) {
          _contextRefreshUsed = true;
          unawaited(_refreshContextAndReconnect(args, e));
          return;
        }
        onClose?.call("服务器连接失败（握手或传输失败）$e");
      },
    );
    webScoketUtils?.connect();
  }

  Future<void> _refreshContextAndReconnect(dynamic args, String error) async {
    CoreLog.w("[DouyinDanmaku] 动态推送连接失败，刷新 IM 上下文：$error");
    try {
      final context = await _fetchImContext();
      if (context != null) {
        webScoketUtils?.close();
        _imContext = context;
        _openWebSocket(args);
        return;
      }
    } catch (e) {
      CoreLog.w("[DouyinDanmaku] 刷新 IM 上下文失败：$e");
    }
    onClose?.call("服务器连接失败（动态上下文刷新后握手失败）$error");
  }

  @override
  void heartbeat() {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void decodeMessage(args) {
    final stopwatch = Stopwatch()..start();
    var wssPackage = PushFrame.fromBuffer(args);
    var decompressed = gzip.decode(wssPackage.payload);
    var payloadPackage = Response.fromBuffer(decompressed);
    final counts = _consumeResponse(payloadPackage, logId: wssPackage.logId);
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds >= 16 || counts.$2 >= 20) {
      CoreLog.i(
        "[DouyinDanmaku] decodeMessage 耗时 ${stopwatch.elapsedMilliseconds}ms messages=${counts.$1} chats=${counts.$2}",
      );
    }
  }

  (int, int) _consumeResponse(Response payloadPackage, {dynamic logId}) {
    var messageCount = 0;
    var chatCount = 0;
    if (payloadPackage.needAck && logId != null) {
      sendAck(logId, payloadPackage.internalExt);
    }
    for (var msg in payloadPackage.messagesList) {
      messageCount++;
      if (msg.method == 'WebcastChatMessage') {
        final liveMessage = unPackWebcastChatMessage(msg.payload);
        if (liveMessage != null) {
          chatCount++;
          _enqueueChatMessage(liveMessage);
        }
      } else if (msg.method == 'WebcastRoomUserSeqMessage') {
        unPackWebcastRoomUserSeqMessage(msg.payload);
      }
    }
    return (messageCount, chatCount);
  }

  String _redactHost(String value) {
    try {
      final uri = Uri.parse(value.contains('://') ? value : 'wss://$value');
      return uri.host;
    } catch (_) {
      return 'invalid';
    }
  }

  LiveMessage? unPackWebcastChatMessage(List<int> payload) {
    var chatMessage = ChatMessage.fromBuffer(payload);
    final spans = _extractRtfSpans(chatMessage);
    if (spans.isEmpty) {
      _appendTextWithEmojiFallback(spans, chatMessage.content);
    }
    final imageUrls = spans
        .where((item) => item.isImage)
        .map((item) => item.imageUrl!.trim())
        .toSet()
        .toList();
    final message = _buildChatMessageText(chatMessage, spans);
    return LiveMessage(
      type: LiveMessageType.chat,
      color: LiveMessageColor.white,
      //暂不知道具体怎么转换颜色
      // color: chatMessage.common.fullScreenTextColor.
      //     ? LiveMessageColor.white
      //     : LiveMessageColor.numberToColor(color),
      message: message,
      userName: chatMessage.user.nickName,
      imageUrls: imageUrls.isEmpty ? null : imageUrls,
      spans: spans.isEmpty ? null : spans,
    );
  }

  void _enqueueChatMessage(LiveMessage message) {
    _pendingChatMessages.add(message);
    if (_pendingChatMessages.length >= _maxChatFlushBatch) {
      _flushChatTimer ??= Timer(Duration.zero, _flushChatMessages);
      return;
    }
    _flushChatTimer ??= Timer(_chatFlushInterval, _flushChatMessages);
  }

  void _flushChatMessages() {
    _flushChatTimer?.cancel();
    _flushChatTimer = null;
    if (_pendingChatMessages.isEmpty) {
      return;
    }
    final batchSize = _pendingChatMessages.length > _maxChatFlushBatch
        ? _maxChatFlushBatch
        : _pendingChatMessages.length;
    final batch = _pendingChatMessages.sublist(0, batchSize);
    _pendingChatMessages.removeRange(0, batchSize);
    for (final message in batch) {
      onMessage?.call(message);
    }
    if (_pendingChatMessages.isNotEmpty) {
      _flushChatTimer = Timer(_chatFlushInterval, _flushChatMessages);
    }
  }

  String _buildChatMessageText(
    ChatMessage chatMessage,
    List<LiveMessageSpan> spans,
  ) {
    final content = chatMessage.content.trim();
    if (content.isNotEmpty) {
      return content;
    }
    if (spans.isEmpty) {
      return chatMessage.content;
    }
    final buffer = StringBuffer();
    for (final span in spans) {
      if (span.isText) {
        buffer.write(span.text);
      }
    }
    return buffer.toString().trim();
  }

  List<LiveMessageSpan> _extractRtfSpans(ChatMessage chatMessage) {
    final spans = <LiveMessageSpan>[];
    if (!chatMessage.hasRtfContent()) {
      return spans;
    }
    for (final piece in chatMessage.rtfContent.piecesList) {
      if (piece.hasImageValue() && piece.imageValue.hasImage()) {
        final imageUrl = _extractImageUrl(piece.imageValue.image);
        if (imageUrl != null) {
          spans.add(LiveMessageSpan.image(imageUrl));
          continue;
        }
        final fallback = _extractImageFallbackText(piece.imageValue.image);
        if (fallback != null) {
          _appendTextWithEmojiFallback(spans, fallback);
        }
      }
      if (piece.stringValue.trim().isNotEmpty) {
        _appendTextWithEmojiFallback(spans, piece.stringValue);
      }
      if (piece.hasPatternRefValue()) {
        final pattern = piece.patternRefValue.defaultPattern.trim();
        if (pattern.isNotEmpty) {
          _appendTextWithEmojiFallback(spans, pattern);
        }
      }
    }
    return spans;
  }

  void _appendTextWithEmojiFallback(List<LiveMessageSpan> spans, String text) {
    if (text.isEmpty) {
      return;
    }
    var start = 0;
    for (final match in RegExp(r'\[[^\[\]]{1,16}\]').allMatches(text)) {
      final token = match.group(0);
      if (token == null) {
        continue;
      }
      final asset = douyinEmojiAssets[token];
      if (asset == null) {
        continue;
      }
      if (match.start > start) {
        spans.add(LiveMessageSpan.text(text.substring(start, match.start)));
      }
      spans.add(LiveMessageSpan.image(asset));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(LiveMessageSpan.text(text.substring(start)));
    }
  }

  String? _extractImageUrl(Image image) {
    for (final url in image.urlListList) {
      final value = url.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
    final openWebUrl = image.openWebUrl.trim();
    if (openWebUrl.startsWith('http://') || openWebUrl.startsWith('https://')) {
      return openWebUrl;
    }
    final uri = image.uri.trim();
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return uri;
    }
    return null;
  }

  String? _extractImageFallbackText(Image image) {
    final alternativeText = image.content.alternativeText.trim();
    if (alternativeText.isNotEmpty) {
      return alternativeText;
    }
    final name = image.content.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final uri = image.uri.trim();
    if (uri.isNotEmpty) {
      return '[$uri]';
    }
    return null;
  }

  void unPackWebcastRoomUserSeqMessage(List<int> payload) {
    var roomUserSeqMessage = RoomUserSeqMessage.fromBuffer(payload);

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: roomUserSeqMessage.totalUser.toInt(),
        color: LiveMessageColor.white,
        message: "",
        userName: "",
      ),
    );
  }

  void sendAck(var logId, String internalExt) {
    var obj = PushFrame();
    obj.payloadType = 'ack';
    obj.logId = logId;
    obj.payload = utf8.encode(internalExt);
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void joinRoom(args) {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  @override
  Future stop() async {
    _flushChatTimer?.cancel();
    _flushChatTimer = null;
    _pendingChatMessages.clear();
    onMessage = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
  }
}

class _DouyinImContext {
  final String pushServer;
  final String cursor;
  final String internalExt;
  final int heartbeatDuration;

  const _DouyinImContext({
    required this.pushServer,
    required this.cursor,
    required this.internalExt,
    required this.heartbeatDuration,
  });
}
