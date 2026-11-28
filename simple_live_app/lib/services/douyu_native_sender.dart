import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';

/// Bounded streaming STT codec; lengths are UTF-8 bytes, not Dart characters.
class DouyuFrames {
  Uint8List _pending = Uint8List(0);
  static String _escape(String s) =>
      s.replaceAll('@', '@A').replaceAll('/', '@S');
  static Map<String, String> fields(String s) => {
        for (final part in s.split('/'))
          if (part.contains('@='))
            part.substring(0, part.indexOf('@=')): part
                .substring(part.indexOf('@=') + 2)
                .replaceAll('@S', '/')
                .replaceAll('@A', '@')
      };
  static Uint8List encode(Map<String, dynamic> fields) {
    final body = utf8.encode(
        '${fields.entries.map((e) => '${e.key}@=${_escape('${e.value}')}/').join()}\x00');
    final bytes = Uint8List(body.length + 12);
    final header = ByteData.sublistView(bytes);
    header.setUint32(0, bytes.length - 4, Endian.little);
    header.setUint32(4, bytes.length - 4, Endian.little);
    header.setUint16(8, 689, Endian.little);
    bytes.setRange(12, bytes.length, body);
    return bytes;
  }

  List<Map<String, String>> add(List<int> data) {
    if (_pending.length + data.length > 2 * 1024 * 1024)
      throw const FormatException('STT frame limit');
    final all = Uint8List(_pending.length + data.length)
      ..setAll(0, _pending)
      ..setAll(_pending.length, data);
    final messages = <Map<String, String>>[];
    var offset = 0;
    while (offset + 12 <= all.length) {
      final header = ByteData.sublistView(all, offset);
      final size = header.getUint32(0, Endian.little) + 4;
      if (size < 13 ||
          size > 2 * 1024 * 1024 ||
          header.getUint32(4, Endian.little) + 4 != size) {
        _pending = Uint8List(0);
        throw const FormatException('Invalid STT frame');
      }
      if (offset + size > all.length) break;
      messages.add(
          fields(utf8.decode(all.sublist(offset + 12, offset + size - 1))));
      offset += size;
    }
    _pending = Uint8List.fromList(all.sublist(offset));
    return messages;
  }
}

class DouyuNativeSender implements DanmakuSender {
  DouyuNativeSender(
      {required this.roomId,
      required DanmakuCredentials credentials,
      this.onIdentity,
      Dio? dio,
      Future<WebSocket> Function(Uri, Map<String, dynamic>)? connect})
      : _credentials = credentials,
        _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 4),
                followRedirects: false)),
        _connect = connect ??
            ((uri, headers) =>
                WebSocket.connect(uri.toString(), headers: headers));
  final String roomId;
  final DanmakuCredentials _credentials;
  final void Function(String)? onIdentity;
  final Dio _dio;
  final Future<WebSocket> Function(Uri, Map<String, dynamic>) _connect;
  final _cancel = CancelToken();
  final _sockets = <WebSocket>[];
  Future<void>? _connecting;
  Completer<void>? _ready;
  Completer<DanmakuSendResult>? _ack;
  WebSocket? _gateway, _barrage;
  Timer? _heartbeat;
  String? _fingerprint, _pendingText, _uid, _username;
  String? _pendingCst;
  final _uncertainTexts = <String>{};
  String _device = '';
  String _trackingDevice = '';
  String _group = '';
  Map _key = {};
  String? _heartbeatNonce;
  int? _heartbeatRounds;
  int _generation = 0;
  bool _closed = false, _busy = false, _authenticated = false;
  static final _origin = Uri.parse('https://www.douyu.com/');
  static String _md5(String value) =>
      md5.convert(utf8.encode(value)).toString();

  static String challenge(
      {required String key,
      required String nonce,
      required int rounds,
      required String roomId,
      required String deviceId,
      required int timestamp}) {
    if (rounds < 0 || rounds > 100000)
      throw const FormatException('Invalid challenge');
    var digest = nonce;
    for (var i = 0; i < rounds; i++) {
      digest = _md5('$digest$key');
    }
    return _md5('$digest$key$roomId$deviceId$timestamp');
  }

  @override
  void prepare() {
    if (_closed) return;
    unawaited(checkReady());
  }

  /// Read-only connection/authentication check; never submits a chat message.
  Future<DanmakuSendResult> checkReady() async {
    try {
      await _ensureReady();
      return const DanmakuSendResult('ready', '斗鱼发送连接已就绪');
    } on _DouyuFailure catch (error) {
      return DanmakuSendResult(error.status, error.message);
    } catch (_) {
      return const DanmakuSendResult('not_ready', '斗鱼发送连接尚未就绪');
    }
  }

  Future<void> _ensureReady() async {
    if (_closed) throw StateError('Closed');
    final raw = await _credentials(_origin).timeout(const Duration(seconds: 5));
    // Official Cookie service prepends acf_ and decodeURIComponent to these keys.
    final credentials = <String, String>{'dy_did': raw['dy_did'] ?? ''};
    for (final name in [
      'username',
      'auth_wl',
      'stk',
      'ltkid',
      'biz',
      'dmjwt_token',
      'did'
    ]) {
      final value = raw['acf_$name'] ?? raw[name] ?? '';
      try {
        credentials[name] = Uri.decodeComponent(value);
      } catch (_) {
        credentials[name] = value;
      }
    }
    if (_closed) throw StateError('Closed');
    if (credentials['username']?.isNotEmpty != true ||
        !['auth_wl', 'dmjwt_token']
            .any((k) => credentials[k]?.isNotEmpty == true)) {
      _closeSockets();
      _fingerprint = null;
      throw const _DouyuFailure('login', '请在搜索网页中登录斗鱼账号');
    }
    // Refresh credentials every explicit send; do not retain a logged-out account.
    final fingerprint = sha256
        .convert(utf8.encode([
          'username',
          'auth_wl',
          'stk',
          'ltkid',
          'dmjwt_token',
          'did',
          'dy_did'
        ].map((k) => credentials[k] ?? '').join('\x00')))
        .toString();
    if (_fingerprint != fingerprint) {
      final previous = _connecting;
      if (previous != null) await previous.catchError((Object _) {});
      if (_closed) throw StateError('Closed');
      _closeSockets();
      _fingerprint = fingerprint;
    }
    if (_authenticated && _gateway?.readyState == WebSocket.open) return;
    final pending = _connecting ??= _initialize(credentials);
    try {
      await pending;
    } finally {
      if (identical(_connecting, pending)) _connecting = null;
    }
  }

  Future<Map> _json(String path, {bool post = false}) async {
    final response = await _dio.request<dynamic>('https://www.douyu.com$path',
        options: Options(
            method: post ? 'POST' : 'GET',
            headers: {'Referer': 'https://www.douyu.com/$roomId'}),
        cancelToken: _cancel);
    final value =
        response.data is String ? jsonDecode(response.data) : response.data;
    if (value is! Map ||
        (value['error'] != 0 && value['error'] != '0') ||
        value['data'] is! Map) {
      throw const _DouyuFailure('not_ready', '斗鱼连接参数尚未就绪，本次未发送');
    }
    return value['data'] as Map;
  }

  Future<void> _initialize(Map<String, String> cookies) async {
    final generation = _generation;
    _ready = Completer<void>();
    // Observe errors immediately, even if server disconnects during setup.
    unawaited(_ready!.future.catchError((Object _) {}));
    // Official gateway helper reads acf_did, unlike chat's separate dy_did.
    _device = cookies['did']?.isNotEmpty == true
        ? cookies['did']!
        : '10000000000000000000000000001501';
    _trackingDevice = cookies['dy_did'] ?? '';
    try {
      final values = await Future.wait([
        _json('/lapi/live/gateway/web/$roomId?isH5=1', post: true),
        _json(
            '/wgapi/livenc/liveweb/websec/getEncryption?did=${Uri.encodeQueryComponent(_device)}'),
      ]);
      if (_closed || generation != _generation) throw StateError('Closed');
      _key = values[1];
      final servers = values[0]['wss'];
      if (servers is! List || servers.isEmpty)
        throw const FormatException('Missing gateway');
      _gateway = await _open(servers.first, gateway: true);
      if (_closed || generation != _generation) throw StateError('Closed');
      final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _write(_gateway, {
        'type': 'loginreq',
        'roomid': roomId,
        'dfl': '',
        'username': cookies['username'] ?? '',
        'password': cookies['auth_wl'] ?? '',
        'ltkid': cookies['ltkid'] ?? '',
        'biz': cookies['biz'] ?? '',
        'stk': cookies['stk'] ?? '',
        'jwt': cookies['dmjwt_token'] ?? '',
        'devid': _device,
        'ct': 0,
        'pt': 2,
        'cvr': 0,
        'tvr': 7,
        'apd': '',
        'rt': time,
        'vk': _md5('$time' r"r5*^5;}2#${XF[h+;'./.Q'1;,-]f'p[" '$_device'),
        'ver': '20220825',
        'aver': '218101901',
        'dmbt': 'chrome',
        'dmbv': '125',
      });
      await _ready!.future.timeout(const Duration(seconds: 6));
      if (_closed || generation != _generation) throw StateError('Closed');
      _heartbeat =
          Timer.periodic(const Duration(seconds: 40), (_) => heartbeat());
    } catch (_) {
      _closeSockets();
      rethrow;
    }
  }

  void heartbeat() {
    if (_closed || !_authenticated) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final key = _key['cpp']?['heartbeat'];
      if (key is Map) {
        _write(_gateway, {
          'type': 'keeplive',
          'tick': now,
          'vbw': 0,
          'cdn': '',
          'kd': '',
          'alg_ver': '1.0',
          'key_ver': key['key_ver'],
          'sig': challenge(
              key: '${key['key']}',
              nonce: _heartbeatNonce ?? '${_key['rand_str']}',
              rounds: _heartbeatRounds ?? int.parse('${_key['enc_time']}'),
              roomId: roomId,
              deviceId: _device,
              timestamp: now)
        });
      }
      _heartbeatNonce = null;
      _heartbeatRounds = null;
      if (_barrage?.readyState == WebSocket.open) {
        _write(_barrage, {'type': 'mrkl'});
      }
    } catch (_) {
      _fail(const _DouyuFailure('not_ready', '斗鱼连接已断开'));
    }
  }

  Future<WebSocket> _open(dynamic server, {required bool gateway}) async {
    final generation = _generation;
    final host = '${server['domain'] ?? server['host'] ?? server['ip'] ?? ''}';
    final port = int.tryParse('${server['port']}');
    // Only send website credentials to platform-provided Douyu gateway hosts.
    if (!host.endsWith('.douyu.com') ||
        port == null ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('Invalid gateway origin');
    }
    final creation = _connect(Uri(scheme: 'wss', host: host, port: port),
        {'Origin': 'https://www.douyu.com'});
    late final WebSocket socket;
    try {
      socket = await creation.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      unawaited(creation.then((s) => s.close()).catchError((Object _) {}));
      rethrow;
    }
    if (_closed || generation != _generation) {
      await socket.close();
      throw StateError('Closed');
    }
    _sockets.add(socket);
    final frames = DouyuFrames();
    socket.listen((event) {
      try {
        if (event is! List<int>) return;
        for (final message in frames.add(event)) {
          _receive(message, socket, gateway);
        }
      } catch (_) {
        _fail(const _DouyuFailure('not_ready', '斗鱼连接响应异常'));
      }
    }, onError: (Object _) {
      if (_sockets.contains(socket))
        _fail(const _DouyuFailure('not_ready', '斗鱼连接中断'));
    }, onDone: () {
      if (_sockets.contains(socket))
        _fail(const _DouyuFailure('not_ready', '斗鱼连接已断开'));
    });
    return socket;
  }

  void _write(WebSocket? socket, Map<String, dynamic> fields) {
    if (_closed) throw StateError('Closed');
    if (socket == null || socket.readyState != WebSocket.open)
      throw StateError('Disconnected');
    socket.add(DouyuFrames.encode(fields));
  }

  void _receive(Map<String, String> msg, WebSocket socket, bool gateway) {
    if (_closed || !_sockets.contains(socket)) return;
    final type = msg['type'];
    if (type == 'error') {
      Log.writeLog(
          '[Danmaku] site=douyu source=native gatewayCode=${int.tryParse(msg['code'] ?? '') ?? -1}');
      _fail(_DouyuFailure('rejected',
          '斗鱼拒绝连接或发言（${int.tryParse(msg['code'] ?? '') ?? -1}），请检查网页登录状态'));
    } else if (type == 'loginres' && gateway) {
      _uid = msg['userid'];
      _username = msg['username'];
      if (_uid == null || _uid == '0') {
        _fail(const _DouyuFailure('login', '斗鱼登录已失效，请重新登录搜索网页'));
        return;
      }
      final key = _key['cpp']?['danmu'];
      Log.writeLog('[Danmaku] site=douyu source=native stage=account_accepted');
      _write(socket, {
        'type': 'livreq',
        'alg_ver': '1.0',
        'key_ver': key?['key_ver'] ?? ''
      });
    } else if (type == 'livres' && gateway) {
      final key = _key['cpp']?['danmu'];
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _write(socket, {
        'type': 'lsigreq',
        'ts': now,
        'sig': challenge(
            key: '${key['key']}',
            nonce: msg['nonce'] ?? '',
            rounds: int.parse(msg['its'] ?? '-1'),
            roomId: roomId,
            deviceId: _device,
            timestamp: now)
      });
      _authenticated = true;
      Log.writeLog('[Danmaku] site=douyu source=native stage=gateway_signed');
      if (_ready?.isCompleted == false) _ready!.complete();
    } else if (type == 'msgrepeaterproxylist' && gateway) {
      final servers = (msg['list'] ?? '')
          // STT arrays escape each record once in addition to the outer map.
          .split(RegExp(r'@S/|//'))
          .map((s) => s.replaceAll('@S', '/').replaceAll('@A', '@'))
          .map(DouyuFrames.fields)
          .where((m) => m.isNotEmpty)
          .toList();
      if (servers.isNotEmpty && _barrage == null) {
        unawaited(_open(servers.first, gateway: false).then((s) {
          _barrage = s;
          _write(s, {
            'type': 'loginreq',
            'roomid': roomId,
            'username': _username ?? '',
            'uid': _uid ?? '',
            'ver': '20220825',
            'aver': '218101901',
            'ct': 0
          });
        }).catchError((Object _) {}));
      }
    } else if (type == 'setmsggroup' && gateway) {
      _group = msg['gid'] ?? '';
      if (_barrage != null && _group.isNotEmpty)
        _write(_barrage, {'type': 'joingroup', 'rid': roomId, 'gid': _group});
    } else if ((type == 'loginres' || type == 'barrage_login_response') &&
        !gateway) {
      if (_group.isNotEmpty)
        _write(socket, {'type': 'joingroup', 'rid': roomId, 'gid': _group});
    } else if (type == 'keeplive' && gateway) {
      _heartbeatNonce = msg['nonce'];
      _heartbeatRounds = int.tryParse(msg['its'] ?? '');
    } else if (type == 'chatres' && gateway && msg['res'] != null) {
      Log.writeLog(
          '[Danmaku] site=douyu source=native responseCode=${int.tryParse(msg['res']!) ?? -1}');
      final ack = _ack;
      _ack = null;
      if (ack != null && !ack.isCompleted) {
        // This gateway belongs only to this sender, with one chat in flight.
        // Unknown transactions close it below, so a late old reply cannot ACK a
        // later send. Unlike the shared receiving stream, no other browser can
        // generate a chatres on this connection.
        ack.complete(msg['res'] == '0'
            ? const DanmakuSendResult('sent', '发送成功')
            : DanmakuSendResult('rejected',
                '斗鱼拒绝发言，请检查禁言、冷却或账号验证（${int.tryParse(msg['res']!) ?? -1}）'));
      }
    } else if (type == 'chatmsg' &&
        _ack != null &&
        msg['uid'] == _uid &&
        msg['txt'] == _pendingText &&
        (msg['cst'] != null
            ? msg['cst'] == _pendingCst
            : !_uncertainTexts.contains(_md5(_pendingText!)))) {
      _ack!.complete(const DanmakuSendResult('sent', '发送成功'));
      _ack = null;
    }
  }

  void _fail(_DouyuFailure error) {
    if (_ready?.isCompleted == false) _ready!.completeError(error);
    final ack = _ack;
    _ack = null;
    if (ack != null && !ack.isCompleted)
      ack.complete(error.status == 'not_ready'
          ? const DanmakuSendResult('unknown', '斗鱼连接中断，发送结果未确认，请先查看聊天')
          : DanmakuSendResult(error.status, error.message));
    _closeSockets();
  }

  void _closeSockets() {
    ++_generation;
    if (_ready?.isCompleted == false)
      _ready!.completeError(StateError('Connection replaced'));
    _heartbeat?.cancel();
    _heartbeat = null;
    _authenticated = false;
    final sockets = _sockets.toList();
    _sockets.clear();
    _gateway = null;
    _barrage = null;
    _group = '';
    _key = {};
    _uid = null;
    _username = null;
    _heartbeatNonce = null;
    _heartbeatRounds = null;
    for (final socket in sockets) {
      unawaited(socket.close().catchError((Object _) {}));
    }
  }

  @override
  Future<DanmakuSendResult> send(String text) async {
    if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
    if (_busy) return const DanmakuSendResult('busy', '上一条弹幕仍在发送');
    if (text.trim().isEmpty)
      return const DanmakuSendResult('rejected', '请输入弹幕');
    if (_uncertainTexts.contains(_md5(text)) || _uncertainTexts.length >= 100) {
      return const DanmakuSendResult('unknown', '此弹幕发送结果未确认，请先查看聊天，避免重复发送');
    }
    _busy = true;
    var submitted = false;
    final watch = Stopwatch()..start();
    try {
      await _ensureReady();
      if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
      if(_uid!=null) onIdentity?.call(_uid!);
      final ack = Completer<DanmakuSendResult>();
      _ack = ack;
      _pendingText = text;
      _pendingCst = '${DateTime.now().millisecondsSinceEpoch}';
      submitted = true;
      _write(_gateway, {
        'type': 'chatmessage',
        'content': text,
        'sender': _uid,
        'dy': _trackingDevice,
        'col': 0,
        'pe': 0,
        'ifs': 0,
        'nc': 0,
        'dat': 0,
        'rev': 0,
        'tts': 0,
        'admzq': 0,
        'cst': _pendingCst
      });
      final result = await ack.future.timeout(const Duration(seconds: 5),
          onTimeout: () =>
              const DanmakuSendResult('unknown', '斗鱼未确认发送，请先查看聊天，避免重复发送'));
      if (result.status == 'unknown') {
        _closeSockets(); // No stale gateway ACK may reach the next transaction.
        _uncertainTexts.add(_md5(text));
      }
      return result.sent ? DanmakuSendResult(result.status,result.message,userId:_uid) : result;
    } on _DouyuFailure catch (error) {
      return DanmakuSendResult(error.status, error.message);
    } catch (_) {
      if (submitted && !_closed) {
        _uncertainTexts.add(_md5(text));
        _closeSockets();
      }
      return DanmakuSendResult(
          _closed
              ? 'closed'
              : submitted
                  ? 'unknown'
                  : 'not_ready',
          _closed
              ? '直播间已切换'
              : submitted
                  ? '发送结果未确认，请先查看聊天，避免重复发送'
                  : '斗鱼发送连接尚未就绪，本次未发送');
    } finally {
      _ack = null;
      _pendingText = null;
      _pendingCst = null;
      _busy = false;
      Log.writeLog(
          '[Danmaku] site=douyu source=native submitted=$submitted elapsedMs=${watch.elapsedMilliseconds}');
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _cancel.cancel();
    if (_ready?.isCompleted == false)
      _ready!.completeError(StateError('Closed'));
    if (_ack?.isCompleted == false)
      _ack!.complete(const DanmakuSendResult('closed', '直播间已切换'));
    _closeSockets();
    _dio.close(force: true);
  }
}

class _DouyuFailure implements Exception {
  const _DouyuFailure(this.status, this.message);
  final String status, message;
}
