import 'dart:async';

import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils/duration2strUtils.dart';
import 'package:simple_live_app/models/db/history.dart';

import 'db_service.dart';

class HistoryService extends GetxService {
  static HistoryService get instance => Get.find<HistoryService>();
  final Stopwatch _stopwatch = Stopwatch();
  var _elapsed = Duration.zero;
  History? curLiveRoomHistory;
  //两分钟自动保存一次，防止用户直接关闭app，丢失数据
  final _saveInterval = const Duration(minutes: 2);
  Timer? _timer; // 定时器

  // 开始计时
  void start(History history) {
    _loadHistory(history);
    // 访问立马添加一次，防呆，防秒切秒关
    _updateHistory();
    _stopwatch.start();
    _timer = Timer.periodic(_saveInterval, (timer) {
      _updateHistory();
    });
  }

  // 停止计时
  void stop() {
    _stopwatch.stop();
    _elapsed = _stopwatch.elapsed;
    _updateHistory();
    _stopwatch.reset();
    // 取消定时器
    _timer?.cancel();
    _timer = null;
    EventBus.instance.emit(Constant.kUpdateFollow, curLiveRoomHistory);
    Log.i("本次观看时长：$_elapsed");
  }

  void _loadHistory(History history) {
    curLiveRoomHistory = DBService.instance.getHistory(history.id);
    // 首次观看则创建
    curLiveRoomHistory ??= history;
  }

  // updateHistory
  void _updateHistory() {
    // 累加到当前历史记录
    var temp = curLiveRoomHistory!.watchDuration!.toDuration();
    temp += _elapsed;
    curLiveRoomHistory?.watchDuration = temp.toHMSString();
    curLiveRoomHistory?.updateTime = DateTime.now();
    DBService.instance.addOrUpdateHistory(curLiveRoomHistory!);
  }
}
