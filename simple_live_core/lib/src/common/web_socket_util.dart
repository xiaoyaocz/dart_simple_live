import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus {
  connected,
  failed,
  closed,
}

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
    IOWebSocketChannel Function(String, Map<String, dynamic>?)? connectChannel,
  }) : _connectChannel = connectChannel ?? _defaultConnect;

  final IOWebSocketChannel Function(String, Map<String, dynamic>?) _connectChannel;

  static IOWebSocketChannel _defaultConnect(
    String url,
    Map<String, dynamic>? headers,
  ) => IOWebSocketChannel.connect(
    url,
    connectTimeout: const Duration(seconds: 10),
    headers: headers,
  );

  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  // Every close or replacement invalidates pending handshakes and callbacks.
  int _generation = 0;

  /// 重连次数
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大重连次数
  int maxReconnectTime = 5;

  StreamSubscription<dynamic>? streamSubscription;

  void connect({bool retry = false}) async {
    close();
    final generation = _generation;
    try {
      var wsurl = url;
      if (backupUrl != null && backupUrl!.isNotEmpty && retry) {
        wsurl = backupUrl!;
      }
      final channel = _connectChannel(wsurl, headers);
      webSocket = channel;
      await channel.ready;
      if (generation != _generation) return;
      ready();
    } catch (e) {
      if (generation != _generation) return;
      if (!retry) {
        connect(retry: true);
        return;
      }
      onError(e, e);
    }
  }

  /// 连接完成
  void ready() {
    status = SocketStatus.connected;

    final generation = _generation;
    streamSubscription = webSocket?.stream.listen(
      (data) {
        if (generation == _generation) receiveMessage(data);
      },
      onError: (e, s) {
        if (generation == _generation) onError(e, s);
      },
      onDone: () {
        if (generation == _generation) onDone();
      },
    );

    onReady?.call();
    // The ready callback can synchronously close or replace the connection.
    if (generation == _generation) initHeartBeat();
  }

  void initHeartBeat() {
    heartBeatTimer?.cancel();
    final generation = _generation;
    heartBeatTimer = Timer.periodic(
      Duration(milliseconds: heartBeatTime),
      (timer) {
        if (generation == _generation) onHeartBeat?.call();
      },
    );
  }

  void receiveMessage(dynamic data) {
    //接受到一条信息才算重连成功
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void onError(e, s) {
    status = SocketStatus.failed;
    onClose?.call(e.toString());
  }

  void onDone() {
    if (status == SocketStatus.closed) {
      return;
    }
    final generation = _generation;
    onReconnect?.call();
    if (generation == _generation) reconnect();
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) {
      webSocket?.sink.add(message);
    }
  }

  void close() {
    _generation++;
    status = SocketStatus.closed;

    streamSubscription?.cancel();

    reconnectTimer?.cancel();
    reconnectTimer = null;

    webSocket?.sink.close();

    heartBeatTimer?.cancel();
    heartBeatTimer = null;
  }

  void reconnect() {
    status = SocketStatus.closed;
    if (reconnectTime < maxReconnectTime) {
      reconnectTime++;
      reconnectTimer ??= Timer.periodic(Duration(seconds: 5), (timer) {
        connect();
      });
    } else {
      onClose?.call("重连超过最大次数，与服务器断开连接");
      reconnectTimer?.cancel();
      reconnectTimer = null;
      close();
      return;
    }
  }
}
