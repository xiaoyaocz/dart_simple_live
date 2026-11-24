import 'dart:async';

import 'package:simple_live_app/app/log.dart';

/// 全局事件
class EventBus {
  /// 点击了底部导航
  static const String kBottomNavigationBarClicked =
      "BottomNavigationBarClicked";

  /// 主页底栏入口显隐/排序变化，需要重建底栏
  static const String kUpdateHomeTabs = "UpdateHomeTabs";

  /// 平台显隐/排序变化，需要重建首页/分类/搜索的平台标签
  static const String kUpdateSiteTabs = "UpdateSiteTabs";
  static EventBus? _instance;

  static EventBus get instance {
    _instance ??= EventBus();
    return _instance!;
  }

  final Map<String, StreamController> _streams = {};

  /// 触发事件
  void emit<T>(String name, T data) {
    if (!_streams.containsKey(name)) {
      _streams.addAll({name: StreamController.broadcast()});
    }
    Log.d("Emit Event：$name\r\n$data");

    _streams[name]!.add(data);
  }

  /// 监听事件
  StreamSubscription<dynamic> listen(String name, Function(dynamic)? onData) {
    if (!_streams.containsKey(name)) {
      _streams.addAll({name: StreamController.broadcast()});
    }
    return _streams[name]!.stream.listen(onData);
  }
}
