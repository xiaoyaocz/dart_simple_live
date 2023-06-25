import 'dart:async';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';

class DouyinDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 10 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://danmuproxy.douyu.com:8506";

  WebScoketUtils? webScoketUtils;

  @override
  Future start(dynamic args) async {}

  @override
  void heartbeat() {}

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
  }
}
