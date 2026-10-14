import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus { connected, failed, closed }

typedef WebSocketConnector =
    FutureOr<IOWebSocketChannel> Function(
      String url, {
      Duration? connectTimeout,
      Map<String, dynamic>? headers,
    });

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 链接
  final String url;

  /// 备用链接
  final String? backupUrl;

  /// 心跳时间
  final int heartBeatTime;

  /// 接收到信息
  final Function(dynamic)? onMessage;

  /// 连接关闭
  final Function(String msg)? onClose;

  /// 尝试重连
  final Function()? onReconnect;

  /// 准备就绪
  final Function()? onReady;

  /// 心跳
  final Function()? onHeartBeat;

  /// 请求头
  Map<String, dynamic>? headers;

  /// Primarily useful for tests and embedders that customize socket creation.
  final WebSocketConnector webSocketConnector;

  final Duration reconnectDelay;
  final Duration connectTimeout;

  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
    WebSocketConnector? webSocketConnector,
    this.reconnectDelay = const Duration(seconds: 5),
    this.connectTimeout = const Duration(seconds: 10),
  }) : webSocketConnector = webSocketConnector ?? _connect;

  static IOWebSocketChannel _connect(
    String url, {
    Duration? connectTimeout,
    Map<String, dynamic>? headers,
  }) {
    return IOWebSocketChannel.connect(
      url,
      connectTimeout: connectTimeout,
      headers: headers,
    );
  }

  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 重连次数
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大重连次数
  int maxReconnectTime = 5;

  StreamSubscription<dynamic>? streamSubscription;

  int _generation = 0;
  bool _active = false;
  bool _connecting = false;

  void connect({bool retry = false}) {
    _active = true;
    reconnectTime = 0;
    _generation++;
    _connecting = false;
    _cancelTimersAndTransport();
    status = SocketStatus.closed;
    unawaited(_connectGeneration(_generation, startWithBackup: retry));
  }

  Future<void> _connectGeneration(
    int generation, {
    bool startWithBackup = false,
  }) async {
    if (!_isCurrent(generation) || _connecting) return;
    _connecting = true;
    Object? lastError;
    final urls = <String>[
      if (!startWithBackup) url,
      if (backupUrl != null && backupUrl!.isNotEmpty) backupUrl!,
    ];
    if (urls.isEmpty) urls.add(url);

    try {
      for (final socketUrl in urls) {
        IOWebSocketChannel? candidate;
        try {
          candidate = await webSocketConnector(
            socketUrl,
            connectTimeout: connectTimeout,
            headers: headers,
          );
          if (!_isCurrent(generation)) {
            _discardCandidate(candidate);
            return;
          }
          await candidate.ready;
          if (!_isCurrent(generation)) {
            _discardCandidate(candidate);
            return;
          }
          webSocket = candidate;
          _ready(generation);
          return;
        } catch (error) {
          lastError = error;
          if (candidate != null) {
            if (candidate == webSocket) {
              _disposeTransport();
            } else {
              _discardCandidate(candidate);
            }
          }
          if (!_isCurrent(generation)) return;
        }
      }
    } finally {
      if (generation == _generation) _connecting = false;
    }

    if (_isCurrent(generation)) {
      _handleFailure(lastError ?? StateError('WebSocket connection failed'));
    }
  }

  bool _isCurrent(int generation) => _active && generation == _generation;

  void _discardCandidate(IOWebSocketChannel candidate) {
    // ready 和 stream 都会报告握手失败；未监听的 stream 还会阻塞 sink.close。
    candidate.stream.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    unawaited(candidate.sink.close().catchError((Object error) {}));
  }

  /// 连接完成。保留此方法以兼容现有调用方。
  void ready() => _ready(_generation);

  void _ready(int generation) {
    if (!_isCurrent(generation) || webSocket == null) return;
    status = SocketStatus.connected;
    _connecting = false;

    streamSubscription = webSocket!.stream.listen(
      receiveMessage,
      onError: (Object error, StackTrace stackTrace) {
        _handleFailure(error, generation: generation);
      },
      onDone: () => _handleFailure(
        StateError('WebSocket closed'),
        generation: generation,
      ),
      cancelOnError: true,
    );

    onReady?.call();
    initHeartBeat();
  }

  void initHeartBeat() {
    heartBeatTimer?.cancel();
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime),
      (timer) => onHeartBeat?.call(),
    );
  }

  void receiveMessage(dynamic data) {
    // 接受到一条信息才算重连成功
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void onError(Object error, Object stackTrace) => _handleFailure(error);

  void onDone() => _handleFailure(StateError('WebSocket closed'));

  void _handleFailure(Object error, {int? generation}) {
    if (!_active || (generation != null && generation != _generation)) return;
    status = SocketStatus.failed;
    onClose?.call(error.toString());
    _disposeTransport();
    _scheduleReconnect();
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) webSocket?.sink.add(message);
  }

  /// 主动关闭；与传输失败不同，不会安排重连。
  void close() {
    _active = false;
    _generation++;
    status = SocketStatus.closed;
    _connecting = false;
    _cancelTimersAndTransport();
  }

  void _cancelTimersAndTransport() {
    reconnectTimer?.cancel();
    reconnectTimer = null;
    _disposeTransport();
  }

  void _disposeTransport() {
    heartBeatTimer?.cancel();
    heartBeatTimer = null;
    final subscription = streamSubscription;
    streamSubscription = null;
    unawaited(subscription?.cancel());
    final socket = webSocket;
    webSocket = null;
    unawaited(socket?.sink.close());
  }

  void reconnect() {
    if (!_active) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_active || reconnectTimer != null || _connecting) return;
    if (reconnectTime >= maxReconnectTime) {
      onClose?.call('重连超过最大次数，与服务器断开连接');
      close();
      return;
    }

    reconnectTime++;
    reconnectTimer = Timer(reconnectDelay, () {
      reconnectTimer = null;
      if (!_active) return;
      onReconnect?.call();
      unawaited(_connectGeneration(_generation));
    });
  }
}
