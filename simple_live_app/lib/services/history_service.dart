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
  Duration _oldWatchedDuration = Duration.zero;
  History? curLiveRoomHistory;
  //两分钟自动保存一次，防止用户直接关闭app，丢失数据
  final _saveInterval = const Duration(minutes: 2);
  Timer? _timer; // 定时器

  // 开始计时
  void start(History history) {
    _loadHistory(history);
    _stopwatch.start();
    _timer = Timer.periodic(_saveInterval, (timer) {
      _updateHistory();
    });
  }

  // reset
  void reset(String roomId){
    _updateHistory();
    _stopwatch.reset();
    History? history = DBService.instance.getHistory(roomId);
    _loadHistory(history!);
  }

  // 停止计时
  void stop() {
    _stopwatch.stop();
    _updateHistory();
    _stopwatch.reset();
    _elapsed = Duration.zero;
    // 取消定时器
    _timer?.cancel();
    _timer = null;
    curLiveRoomHistory = null;
    Log.i("本次观看时长：$_elapsed");
  }

  void _loadHistory(History history) {
    curLiveRoomHistory = DBService.instance.getHistory(history.id);
    // 首次观看则创建
    if(curLiveRoomHistory == null){
      curLiveRoomHistory = history;
      DBService.instance.addOrUpdateHistory(history);
    }
    _oldWatchedDuration = curLiveRoomHistory!.watchDuration!.toDuration();
  }

  // updateHistory
  void _updateHistory() {
    if(curLiveRoomHistory == null){
      return;
    }
    // 累加到当前历史记录
    _elapsed = _stopwatch.elapsed;
    Duration curTime = _oldWatchedDuration+_elapsed;
    Log.i("已观看时间：${_oldWatchedDuration.toHMSString()}_增加时间：${_elapsed.toHMSString()}");
    curLiveRoomHistory?.watchDuration = curTime.toHMSString();
    curLiveRoomHistory?.updateTime = DateTime.now();
    DBService.instance.addOrUpdateHistory(curLiveRoomHistory!);
    EventBus.instance.emit(Constant.kUpdateFollow, curLiveRoomHistory);
  }
}
