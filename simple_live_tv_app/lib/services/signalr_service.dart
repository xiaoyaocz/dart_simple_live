import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/utils.dart';

enum SignalRConnectionState { connecting, connected, disconnected }

class SignalRService {
  static const String kUrl =
      'wss://simple-live-sync.3439394104.workers.dev/sync';
  static const int kRoomIdLength = 6;

  SignalRConnectionState state = SignalRConnectionState.disconnected;

  final _stateStreamController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get stateStream =>
      _stateStreamController.stream;

  final _onFavoriteStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onFavoriteStream =>
      _onFavoriteStreamController.stream;
  final _onHistoryStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onHistoryStream =>
      _onHistoryStreamController.stream;
  final _onShieldWordStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onShieldWordStream =>
      _onShieldWordStreamController.stream;
  final _onBiliAccountStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onBiliAccountStream =>
      _onBiliAccountStreamController.stream;
  final _onRoomDestroyedStreamController = StreamController<String>.broadcast();
  Stream<String> get onRoomDestroyedStream =>
      _onRoomDestroyedStreamController.stream;
  final _onRoomUserUpdatedStreamController =
      StreamController<List<RoomUser>>.broadcast();
  Stream<List<RoomUser>> get onRoomUserUpdatedStream =>
      _onRoomUserUpdatedStreamController.stream;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  int _nextRequestId = 0;
  bool _disposed = false;

  Future<void> connect() async {
    await disconnect();
    _setState(SignalRConnectionState.connecting);
    try {
      final socket =
          await WebSocket.connect(kUrl).timeout(const Duration(seconds: 15));
      _socket = socket;
      _subscription = socket.listen(
        _onMessage,
        onError: (Object error) {
          Log.logPrint(error);
          _onClosed();
        },
        onDone: _onClosed,
      );
      _setState(SignalRConnectionState.connected);
      _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
        if (state == SignalRConnectionState.connected) {
          _socket?.add(jsonEncode({
            'type': 'ping',
            'requestId': 'ping_${DateTime.now().millisecondsSinceEpoch}',
          }));
        }
      });
    } catch (_) {
      _onClosed();
      rethrow;
    }
  }

  void _setState(SignalRConnectionState value) {
    state = value;
    if (!_disposed) _stateStreamController.add(value);
  }

  void _onClosed() {
    _heartbeat?.cancel();
    _socket = null;
    for (final request in _pending.values) {
      if (!request.isCompleted) {
        request.complete({'type': 'error', 'error': '连接已断开'});
      }
    }
    _pending.clear();
    if (state != SignalRConnectionState.disconnected) {
      _setState(SignalRConnectionState.disconnected);
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final requestId = message['requestId']?.toString();
      final pending = requestId == null ? null : _pending.remove(requestId);
      if (pending != null) {
        pending.complete(message);
        return;
      }
      final payload = message['payload'];
      if (payload is Map) {
        final data =
            (payload['overlay'] == true, payload['content']?.toString() ?? '');
        switch (message['type']) {
          case 'favoriteReceived':
            _onFavoriteStreamController.add(data);
          case 'historyReceived':
            _onHistoryStreamController.add(data);
          case 'shieldWordReceived':
            _onShieldWordStreamController.add(data);
          case 'biliAccountReceived':
            _onBiliAccountStreamController.add(data);
        }
      }
      switch (message['type']) {
        case 'roomDestroyed':
          _onRoomDestroyedStreamController
              .add(message['reason']?.toString() ?? '');
        case 'userUpdated':
          final users = message['users'];
          if (users is List) {
            _onRoomUserUpdatedStreamController.add(
              users.map((user) => RoomUser.fromObject(user)).toList(),
            );
          }
      }
    } catch (error) {
      Log.logPrint(error);
    }
  }

  Future<void> disconnect() async {
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    _heartbeat?.cancel();
    await subscription?.cancel();
    await socket?.close();
    _onClosed();
  }

  Map<String, String> get _clientInfo => {
        'app': 'Simple Live TV',
        'platform': 'tv',
        'version': Utils.packageInfo.version,
      };

  Future<Resp<String>> createRoom() async {
    final response = await _request('createRoom', payload: _clientInfo);
    final roomId = response['roomId']?.toString();
    return Resp(
      response['type'] == 'roomCreated' && roomId?.length == kRoomIdLength,
      _errorMessage(response),
      roomId,
    );
  }

  Future<Resp> joinRoom(String roomId) async {
    final response = await _request(
      'joinRoom',
      roomId: roomId.trim().toUpperCase(),
      payload: _clientInfo,
    );
    return Resp(
        response['type'] == 'roomJoined', _errorMessage(response), null);
  }

  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
  }) async {
    final response = await _request(
      '${action[0].toLowerCase()}${action.substring(1)}',
      roomId: roomName,
      payload: {'overlay': overlay, 'content': content},
    );
    return Resp(response['type'] == 'ack', _errorMessage(response), null);
  }

  Future<Map<String, dynamic>> _request(
    String type, {
    String? roomId,
    Object? payload,
  }) async {
    final socket = _socket;
    if (state != SignalRConnectionState.connected || socket == null) {
      return {'type': 'error', 'error': '连接已断开'};
    }
    final requestId = '${++_nextRequestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;
    try {
      socket.add(jsonEncode({
        'type': type,
        'requestId': requestId,
        if (roomId != null) 'roomId': roomId,
        if (payload != null) 'payload': payload,
      }));
      return await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return {'type': 'error', 'error': '同步服务响应超时'};
    } catch (error) {
      Log.logPrint(error);
      return {'type': 'error', 'error': '发送同步请求失败'};
    } finally {
      _pending.remove(requestId);
    }
  }

  String _errorMessage(Map<String, dynamic> response) {
    if (response['type'] != 'error') {
      return response['type'] == 'roomCreated' ||
              response['type'] == 'roomJoined' ||
              response['type'] == 'ack'
          ? ''
          : '同步服务返回异常';
    }
    final error = response['error'];
    if (error is Map) return error['message']?.toString() ?? '同步服务暂不可用';
    return error?.toString() ?? '同步服务暂不可用';
  }

  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _onClosed();
    _stateStreamController.close();
    _onFavoriteStreamController.close();
    _onHistoryStreamController.close();
    _onShieldWordStreamController.close();
    _onBiliAccountStreamController.close();
    _onRoomDestroyedStreamController.close();
    _onRoomUserUpdatedStreamController.close();
  }
}

class Resp<T> {
  final bool isSuccess;
  final String message;
  final T? data;
  Resp(this.isSuccess, this.message, this.data);
}

class RoomUser {
  final String connectionId;
  final String shortId;
  final String platform;
  final String version;
  final String app;
  final bool isCreator;
  final bool isSelf;

  RoomUser.fromObject(Object? obj)
      : connectionId =
            (obj is Map ? obj['connectionId'] : null)?.toString() ?? '',
        shortId = (obj is Map ? obj['shortId'] : null)?.toString() ?? '',
        platform = (obj is Map ? obj['platform'] : null)?.toString() ?? '',
        version = (obj is Map ? obj['version'] : null)?.toString() ?? '',
        app = (obj is Map ? obj['app'] : null)?.toString() ?? '',
        isCreator = obj is Map && obj['isCreator'] == true,
        isSelf = obj is Map && obj['isSelf'] == true;
}
