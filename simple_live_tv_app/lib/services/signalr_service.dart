import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';
import 'package:web_socket_channel/io.dart';

enum SignalRConnectionState {
  connecting,
  connected,
  disconnected,
}

class SyncServerProbeResult {
  final bool isReachable;
  final int? latencyMs;
  final String label;

  const SyncServerProbeResult._({
    required this.isReachable,
    required this.label,
    this.latencyMs,
  });

  factory SyncServerProbeResult.reachable(int latencyMs) {
    return SyncServerProbeResult._(
      isReachable: true,
      latencyMs: latencyMs,
      label: "$latencyMs ms",
    );
  }

  const SyncServerProbeResult.unreachable()
      : this._(isReachable: false, label: "不可用");

  const SyncServerProbeResult.notConfigured()
      : this._(isReachable: false, label: "未配置");
}

class SignalRService {
  static const int kRoomIdLength = 6;
  static const String kDefaultUrl = "wss://sync.furry.mo.cn/sync";
  static const String kCloudflareUrl =
      "wss://simple-live-sync.3439394104.workers.dev/sync";
  static const String kDefaultServerOption = "自建服务器（默认）";
  static const String kCloudflareServerOption = "Cloudflare Worker（备用）";
  static const String kCustomServerOption = "自定义地址";
  static const List<String> kServerOptions = [
    kDefaultServerOption,
    kCloudflareServerOption,
    kCustomServerOption,
  ];
  static const String kDefaultLocalProxy = "127.0.0.1:51888";
  static const String kDirectProxyValue = "direct";

  SignalRConnectionState state = SignalRConnectionState.connecting;

  final _stateStreamController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get stateStream =>
      _stateStreamController.stream;

  final _onFavoriteStreamController =
      StreamController<RoomSyncPayload>.broadcast();
  Stream<RoomSyncPayload> get onFavoriteStream =>
      _onFavoriteStreamController.stream;

  final _onHistoryStreamController =
      StreamController<RoomSyncPayload>.broadcast();
  Stream<RoomSyncPayload> get onHistoryStream =>
      _onHistoryStreamController.stream;

  final _onShieldWordStreamController =
      StreamController<RoomSyncPayload>.broadcast();
  Stream<RoomSyncPayload> get onShieldWordStream =>
      _onShieldWordStreamController.stream;

  final _onBiliAccountStreamController =
      StreamController<RoomSyncPayload>.broadcast();
  Stream<RoomSyncPayload> get onBiliAccountStream =>
      _onBiliAccountStreamController.stream;

  final _onRoomDestroyedStreamController = StreamController<String>.broadcast();
  Stream<String> get onRoomDestroyedStream =>
      _onRoomDestroyedStreamController.stream;

  final _onRoomUserUpdatedStreamController =
      StreamController<List<RoomUser>>.broadcast();
  Stream<List<RoomUser>> get onRoomUserUpdatedStream =>
      _onRoomUserUpdatedStreamController.stream;

  IOWebSocketChannel? _channel;
  HttpClient? _httpClient;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  int _requestId = 0;
  String _currentRoomId = "";
  final hubConnection = SignalRConnectionInfo();
  final Map<String, Completer<Resp<dynamic>>> _pendingRequests = {};

  static String get configuredUrl {
    final value = configuredValue;
    return value.isEmpty ? kDefaultUrl : value;
  }

  static String get configuredValue {
    return LocalStorageService.instance
        .getValue(
          LocalStorageService.kSyncServerUrl,
          "",
        )
        .trim();
  }

  static String get configuredServerOption {
    final url = configuredUrl;
    if (url == kDefaultUrl) {
      return kDefaultServerOption;
    }
    if (url == kCloudflareUrl) {
      return kCloudflareServerOption;
    }
    return kCustomServerOption;
  }

  static String get configuredServerLabel => configuredServerOption;

  static bool isValidServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == "wss" || uri.scheme == "ws") &&
        uri.host.isNotEmpty;
  }

  static Future<SyncServerProbeResult> probeServer(
    String value, {
    bool forceDirect = false,
  }) async {
    final url = value.trim();
    if (!isValidServerUrl(url)) {
      return const SyncServerProbeResult.notConfigured();
    }

    final stopwatch = Stopwatch()..start();
    HttpClient? client;
    IOWebSocketChannel? channel;
    try {
      client = await _createWebSocketHttpClient(forceDirect: forceDirect);
      channel = IOWebSocketChannel.connect(
        url,
        pingInterval: const Duration(seconds: 4),
        connectTimeout: const Duration(seconds: 8),
        customClient: client,
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      const requestId = "connectivity_probe";
      final pong = channel.stream
          .map((event) => json.decode(event.toString()))
          .where(
            (event) =>
                event is Map &&
                event["type"] == "pong" &&
                event["requestId"] == requestId,
          )
          .first
          .timeout(const Duration(seconds: 5));
      channel.sink.add(json.encode({
        "type": "ping",
        "requestId": requestId,
      }));
      await pong;
      stopwatch.stop();
      return SyncServerProbeResult.reachable(stopwatch.elapsedMilliseconds);
    } catch (_) {
      return const SyncServerProbeResult.unreachable();
    } finally {
      await channel?.sink.close();
      client?.close(force: true);
    }
  }

  static Future<void> setConfiguredUrl(String value) {
    return LocalStorageService.instance.setValue(
      LocalStorageService.kSyncServerUrl,
      value.trim(),
    );
  }

  static String get configuredProxyUrl {
    return LocalStorageService.instance
        .getValue(LocalStorageService.kSyncProxyUrl, "")
        .trim();
  }

  static String get proxyDisplayName {
    final value = configuredProxyUrl;
    if (value.isEmpty) {
      return "直连（未设置代理）";
    }
    if (value.toLowerCase() == kDirectProxyValue) {
      return "直连";
    }
    return value;
  }

  static Future<void> setConfiguredProxyUrl(String value) {
    return LocalStorageService.instance.setValue(
      LocalStorageService.kSyncProxyUrl,
      value.trim(),
    );
  }

  static bool isValidProxyConfig(String value) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == kDirectProxyValue) {
      return true;
    }
    return _normalizeProxyAddress(text) != null;
  }

  Future<void> connect() async {
    try {
      await disconnect();
      state = SignalRConnectionState.connecting;
      _stateStreamController.add(state);
      _httpClient = await _createWebSocketHttpClient();
      _channel = IOWebSocketChannel.connect(
        configuredUrl,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 15),
        customClient: _httpClient,
      );
      await _channel!.ready.timeout(const Duration(seconds: 15));
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );
      _startHeartbeat();
      state = SignalRConnectionState.connected;
      _stateStreamController.add(state);
    } catch (e) {
      Log.logPrint(e);
      await _cleanupSocket();
      _setDisconnected();
      throw Exception(_formatConnectionError(e));
    }
  }

  Future<void> disconnect() async {
    await _cleanupSocket();
    _setDisconnected();
  }

  Future<void> _cleanupSocket() async {
    _stopHeartbeat();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Future<Resp<String>> createRoom() async {
    final resp = await _sendRequest<String>(
      type: "createRoom",
      payload: _clientInfo(),
      successTypes: const {"roomCreated"},
      dataReader: (message) => message["roomId"]?.toString(),
    );
    if (resp.isSuccess && (resp.data?.isNotEmpty ?? false)) {
      _currentRoomId = resp.data!;
    }
    return resp;
  }

  Future<Resp> joinRoom(String roomId) async {
    final safeRoomId = roomId.trim().toUpperCase();
    final resp = await _sendRequest(
      type: "joinRoom",
      roomId: safeRoomId,
      payload: _clientInfo(),
      successTypes: const {"roomJoined"},
    );
    if (resp.isSuccess) {
      _currentRoomId = safeRoomId;
    }
    return resp;
  }

  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
    Map<String, Object?> extraPayload = const {},
  }) {
    return _sendRequest(
      type: _mapSendAction(action),
      roomId: roomName.trim().isEmpty ? _currentRoomId : roomName.trim(),
      payload: {
        "overlay": overlay,
        "content": content,
        ...extraPayload,
      },
      successTypes: const {"ack"},
    );
  }

  void dispose() {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(Resp(false, "连接已关闭", null));
      }
    }
    _pendingRequests.clear();
    _stateStreamController.close();
    _onFavoriteStreamController.close();
    _onHistoryStreamController.close();
    _onShieldWordStreamController.close();
    _onBiliAccountStreamController.close();
    _onRoomDestroyedStreamController.close();
    _onRoomUserUpdatedStreamController.close();
    _stopHeartbeat();
    _subscription?.cancel();
    _channel?.sink.close();
  }

  Future<Resp<T>> _sendRequest<T>({
    required String type,
    String? roomId,
    Object? payload,
    required Set<String> successTypes,
    T? Function(Map<String, dynamic> message)? dataReader,
  }) async {
    if (state != SignalRConnectionState.connected || _channel == null) {
      throw Exception("not connected");
    }
    final requestId = (++_requestId).toString();
    final completer = Completer<Resp<dynamic>>();
    _pendingRequests[requestId] = completer;
    final message = <String, dynamic>{
      "type": type,
      "requestId": requestId,
      if (roomId != null && roomId.isNotEmpty) "roomId": roomId,
      if (payload != null) "payload": payload,
    };
    _channel!.sink.add(jsonEncode(message));
    final timer = Timer(const Duration(seconds: 15), () {
      final pending = _pendingRequests.remove(requestId);
      if (pending != null && !pending.isCompleted) {
        pending.complete(Resp(false, "同步服务响应超时", null));
      }
    });
    try {
      final resp = await completer.future;
      if (!resp.isSuccess) {
        return Resp<T>(false, resp.message, null);
      }
      final message = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : <String, dynamic>{};
      if (!successTypes.contains(message["type"]?.toString())) {
        return Resp<T>(false, "同步服务返回异常：${message["type"]}", null);
      }
      return Resp<T>(
        true,
        "",
        dataReader == null ? null : dataReader(message),
      );
    } finally {
      timer.cancel();
      _pendingRequests.remove(requestId);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      if (raw is! String) {
        return;
      }
      final message = jsonDecode(raw);
      if (message is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(message);
      final type = data["type"]?.toString() ?? "";
      final requestId = data["requestId"]?.toString();
      if (requestId != null && requestId.isNotEmpty) {
        final pending = _pendingRequests.remove(requestId);
        if (pending != null && !pending.isCompleted) {
          if (type == "error") {
            pending.complete(Resp(false, _readErrorMessage(data), null));
          } else {
            pending.complete(Resp(true, "", data));
          }
          return;
        }
      }
      switch (type) {
        case "favoriteReceived":
          _emitBoolString(data, _onFavoriteStreamController);
          break;
        case "historyReceived":
          _emitBoolString(data, _onHistoryStreamController);
          break;
        case "shieldWordReceived":
          _emitBoolString(data, _onShieldWordStreamController);
          break;
        case "biliAccountReceived":
          _emitBoolString(data, _onBiliAccountStreamController);
          break;
        case "roomDestroyed":
          _onRoomDestroyedStreamController
              .add(data["reason"]?.toString() ?? "");
          break;
        case "userUpdated":
          final users = data["users"];
          final roomUsers = users is List
              ? users.map((e) => RoomUser.fromObject(e)).toList()
              : <RoomUser>[];
          for (final user in roomUsers) {
            if (user.isSelf) {
              hubConnection.connectionId = user.connectionId;
              break;
            }
          }
          _onRoomUserUpdatedStreamController.add(roomUsers);
          break;
      }
    } catch (e) {
      Log.logPrint(e);
    }
  }

  void _emitBoolString(
    Map<String, dynamic> message,
    StreamController<RoomSyncPayload> controller,
  ) {
    final payload = message["payload"];
    if (payload is! Map) {
      return;
    }
    controller.add(RoomSyncPayload.fromMap(Map<String, dynamic>.from(payload)));
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    Log.logPrint(error);
    _completePendingWithError("同步服务连接失败：${_formatConnectionError(error)}");
    _setDisconnected();
  }

  void _handleSocketDone() {
    _completePendingWithError("同步服务连接已断开");
    _setDisconnected();
  }

  void _completePendingWithError(String message) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(Resp(false, message, null));
      }
    }
    _pendingRequests.clear();
  }

  void _setDisconnected() {
    _stopHeartbeat();
    state = SignalRConnectionState.disconnected;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(state);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (state == SignalRConnectionState.connected && _channel != null) {
        _channel!.sink.add(jsonEncode({
          "type": "ping",
          "requestId": "ping_${DateTime.now().millisecondsSinceEpoch}",
        }));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<HttpClient> _createWebSocketHttpClient({
    bool forceDirect = false,
  }) async {
    final client = HttpClient();
    if (forceDirect) {
      client.findProxy = (_) => "DIRECT";
      return client;
    }
    final proxyAddress = await _resolveProxyAddress();
    if (proxyAddress == null) {
      return client;
    }
    Log.d("远程同步使用代理: $proxyAddress");
    client.findProxy = (_) => "PROXY $proxyAddress";
    return client;
  }

  static Future<String?> _resolveProxyAddress() async {
    final configured = configuredProxyUrl;
    if (configured.isEmpty || configured.toLowerCase() == kDirectProxyValue) {
      return null;
    }
    return _normalizeProxyAddress(configured);
  }

  static String? _normalizeProxyAddress(String value) {
    var text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    if (!text.contains("://")) {
      final parts = text.split(":");
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        return text;
      }
      return null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == "http" || uri.scheme == "https") ||
        uri.host.isEmpty ||
        !uri.hasPort) {
      return null;
    }
    return "${uri.host}:${uri.port}";
  }

  Map<String, String> _clientInfo() => {
        "app": "Simple Live TV",
        "platform": "tv",
        "version": Utils.packageInfo.version,
      };

  String _mapSendAction(String action) {
    switch (action) {
      case "SendFavorite":
        return "sendFavorite";
      case "SendHistory":
        return "sendHistory";
      case "SendShieldWord":
        return "sendShieldWord";
      case "SendBiliAccount":
        return "sendBiliAccount";
      default:
        return action;
    }
  }

  String _readErrorMessage(Map<String, dynamic> message) {
    final error = message["error"];
    if (error is Map) {
      return error["message"]?.toString() ??
          error["code"]?.toString() ??
          "未知错误";
    }
    return error?.toString() ?? "未知错误";
  }

  String _formatConnectionError(Object error) {
    final text = error.toString();
    if (error is TimeoutException || text.contains("TimeoutException")) {
      return "同步服务连接超时，请检查网络或同步服务地址。"
          "两台设备必须选择相同的同步服务；Cloudflare Worker 在部分网络下可能需要代理。";
    }
    if (text.contains("SocketException")) {
      return "无法连接同步服务，请检查网络或同步服务地址";
    }
    return text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
}

class SignalRConnectionInfo {
  String? connectionId;
}

class Resp<T> {
  final bool isSuccess;
  final String message;
  final T? data;
  Resp(this.isSuccess, this.message, this.data);
}

class RoomSyncPayload {
  final bool overlay;
  final String content;
  final int chunkIndex;
  final int chunkTotal;
  final int itemStart;
  final int itemEnd;
  final int itemTotal;

  const RoomSyncPayload({
    required this.overlay,
    required this.content,
    this.chunkIndex = 1,
    this.chunkTotal = 1,
    this.itemStart = 0,
    this.itemEnd = 0,
    this.itemTotal = 0,
  });

  factory RoomSyncPayload.fromMap(Map<String, dynamic> payload) {
    return RoomSyncPayload(
      overlay: payload["overlay"] == true,
      content: payload["content"]?.toString() ?? "",
      chunkIndex: _readInt(payload["chunkIndex"], fallback: 1),
      chunkTotal: _readInt(payload["chunkTotal"], fallback: 1),
      itemStart: _readInt(payload["itemStart"], fallback: 0),
      itemEnd: _readInt(payload["itemEnd"], fallback: 0),
      itemTotal: _readInt(payload["itemTotal"], fallback: 0),
    );
  }

  bool get isLastChunk => chunkIndex >= chunkTotal;

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? "") ?? fallback;
  }
}

class RoomUser {
  final String connectionId;
  final String shortId;
  final String platform;
  final String version;
  final String app;
  final bool? isCreator;
  final bool isSelf;

  RoomUser({
    required this.connectionId,
    required this.shortId,
    required this.platform,
    required this.version,
    required this.app,
    this.isCreator = false,
    this.isSelf = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      connectionId: json['connectionId']?.toString() ?? "",
      shortId: json['shortId']?.toString() ?? "",
      platform: json['platform']?.toString() ?? "",
      version: json['version']?.toString() ?? "",
      app: json['app']?.toString() ?? "",
      isCreator: json['isCreator'] == true,
      isSelf: json['isSelf'] == true,
    );
  }

  factory RoomUser.fromObject(Object? obj) {
    if (obj is Map) {
      return RoomUser.fromJson(Map<String, dynamic>.from(obj));
    }
    return RoomUser(
      connectionId: "",
      shortId: "",
      platform: "",
      version: "",
      app: "",
    );
  }
}
