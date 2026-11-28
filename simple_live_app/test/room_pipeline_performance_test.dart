import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}
class _Player implements Player {
  final disposed = Completer<void>();
  @override Future<void> dispose() async { disposed.complete(); }
  @override Future<void> stop() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Site extends LiveSite {
  final detail = Completer<LiveRoomDetail>();
  @override Future<LiveRoomDetail> getRoomDetail({required String roomId}) => detail.future;
  @override LiveDanmaku getDanmaku() => LiveDanmaku();
}
class _Room extends LiveRoomController {
  _Room(_Site source):super(pSite:Site(id:'test',name:'',logo:'',liveSite:source),pRoomId:'1');
  final fake = _Player();
  @override Player get player => fake;
  @override Future<void> initializePlayer() async {}
  @override Future<int> getQualityLevel() async => 2;
  @override Future<void> resetSystem() async {}
  @override void addHistory() {}
}
LiveMessage _message(int n) => LiveMessage(type:LiveMessageType.chat,
    userName:'主播',message:'$n',color:LiveMessageColor.white);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>Get.put<AppSettingsController>(_Settings()));
  tearDown(()=>Get.reset());
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(MaterialApp(
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(), home: const Scaffold()));
  testWidgets('关闭房间同时取消到时弹窗背后的退出定时器', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: FlutterSmartDialog.init(), home: const Scaffold()));
    final room = _Room(_Site())
      ..autoExitEnable.value = true
      ..autoExitMinutes.value = 0;
    fakeAsync((time) {
      try {
        room.setAutoExit();
        time.elapse(const Duration(seconds: 1));
        expect(time.pendingTimers.where((t) => t.duration == const Duration(seconds: 10)).length, 1);
        room.onClose();
        time.flushMicrotasks();
        expect(time.pendingTimers.where((t) => t.duration == const Duration(seconds: 10)), isEmpty);
      } finally {
        for (final timer in time.pendingTimers) { timer.cancel(); }
      }
    });
  });
  testWidgets('手动翻历史时持续两万条聊天仍有固定内存上限', (tester) async {
    await mount(tester);
    final room = _Room(_Site())..disableAutoScroll.value = true;
    final watch = Stopwatch()..start();
    for(var i=0;i<20000;i++) { room.onWSMessage(_message(i)); }
    expect(room.messages.length, lessThanOrEqualTo(1000));
    expect(room.messages.last.message, '19999');
    expect(room.messages.first.message, '19000');
    debugPrint('20000 chat messages: ${watch.elapsedMilliseconds}ms, retained=${room.messages.length}');
    room.onClose();
    await tester.pump();
  });
  testWidgets('正常滚动和系统提示共享200条上限', (tester) async {
    await mount(tester);
    final room = _Room(_Site());
    for(var i=0;i<500;i++) { room.onWSMessage(_message(i)); }
    expect(room.messages.length, 200);
    for(var i=0;i<500;i++) { room.addSysMsg('system $i'); }
    expect(room.messages.length, 200);
    expect(room.messages.last.message, 'system 499');
    room.onClose();
    await tester.pump();
  });
  testWidgets('关闭后迟到消息、在线人数和系统回调都不再修改房间', (tester) async {
    await mount(tester);
    final room = _Room(_Site());
    room.onClose();
    await tester.pump();
    final count = room.messages.length;
    room.onWSMessage(_message(1));
    room.onWSMessage(LiveMessage(type:LiveMessageType.online,userName:'',
        message:'',data:999,color:LiveMessageColor.white));
    room.onWSClose('late close');
    room.onWSReady();
    expect(room.messages.length, count);
    expect(room.online.value, 0);
    expect(room.fake.disposed.isCompleted,isTrue);
  });
  testWidgets('刷新期间旧房间socket回调失效，关闭释放回调和滚动控制器', (tester) async {
    await mount(tester);
    final source = _Site();
    final room = _Room(source);
    room.initDanmau();
    final chat = room.liveDanmaku;
    final lateMessage = chat.onMessage!;
    room.loadData();
    await tester.pump();
    final before = room.messages.length;
    lateMessage(_message(7));
    expect(room.messages.length,before);
    source.detail.complete(LiveRoomDetail(roomId:'1',title:'',cover:'',userName:'',
        userAvatar:'',online:0,status:false,url:''));
    await tester.pump();
    room.onClose();
    await tester.pump();
    expect(chat.onMessage,isNull);
    expect(()=>room.scrollController.addListener((){}),throwsFlutterError);
  });
}
