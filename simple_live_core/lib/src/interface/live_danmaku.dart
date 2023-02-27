import 'dart:async';

import 'package:simple_live_core/src/model/live_message.dart';

class LiveDanmaku {
  Function(LiveMessage msg)? onMessage;
  Function(String msg)? onClose;
  Function()? onReady;

  /// 心跳时间
  int heartbeatTime = 0;

  /// 发生心跳
  void heartbeat() {}

  /// 开始接收信息
  Future start(dynamic args) {
    return Future.value();
  }

  /// 停止接收信息
  Future stop() {
    return Future.value();
  }
}
