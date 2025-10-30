import 'package:simple_live_core/simple_live_core.dart';

class TwitchDanmaku implements LiveDanmaku{
  @override
  int heartbeatTime = 60 * 1000;

  @override
  Function(String msg)? onClose;

  @override
  Function(LiveMessage msg)? onMessage;

  @override
  Function()? onReady;

  @override
  void heartbeat() {
  }

  @override
  Future start(args) {
    // TODO: implement start
    return Future.value(true);
  }

  @override
  Future stop() {
    return Future.value(true);
  }

}