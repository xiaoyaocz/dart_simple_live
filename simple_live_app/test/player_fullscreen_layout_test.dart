import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: '1');
  int refreshes = 0;
  int enters = 0;
  int exits = 0;
  int composers = 0;
  @override
  Future<void> openDanmakuComposer() async { composers++; }
  @override
  void refreshRoom() => refreshes++;
  @override
  Future<void> enterFullScreen() async {
    enters++;
    fullScreenState.value = true;
  }

  @override
  Future<void> exitFull() async {
    exits++;
    fullScreenState.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

class _Surface extends StatefulWidget {
  const _Surface({super.key});
  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  int deactivations = 0;
  @override
  void deactivate() {
    deactivations++;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: ColoredBox(color: Colors.black));
}

class _Page extends LiveRoomPage {
  const _Page(this.surfaceKey, {this.input = false});
  final GlobalKey<_SurfaceState> surfaceKey;
  final bool input;
  @override
  Widget buildMediaPlayer() => _Surface(key: surfaceKey);
  @override
  List<Widget> buildAppbarActions(BuildContext context) => [];
  @override
  Widget buildUserProfile(BuildContext context) => const SizedBox(height: 48);
  @override
  Widget buildMessageArea() => Expanded(
      child: input
          ? const TextField(key: ValueKey('chat-input'))
          : const SizedBox());
  @override
  Widget buildBottomActions(BuildContext context) =>
      const SizedBox(key: ValueKey('bottom-toolbar'), height: 48);
}

class _ActionPage extends _Page {
  const _ActionPage(super.surfaceKey, this.action);
  final VoidCallback action;
  @override
  List<Widget> buildAppbarActions(BuildContext context) => [
        TextButton(onPressed: action, child: const Text('顶部操作')),
      ];
}

class _ChatPage extends _Page {
  const _ChatPage(super.surfaceKey);
  @override
  Widget buildMessageArea() => const Expanded(
      child: SelectableText('可选中的评论', key: ValueKey('selectable-chat')));
}

void main() {
  Future<_Room> mount(WidgetTester tester, {bool input = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    final room = Get.put<LiveRoomController>(_Room()) as _Room;
    addTearDown(() {
      Get.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
        MaterialApp(home: _Page(GlobalKey<_SurfaceState>(), input: input)));
    await tester.pump();
    return room;
  }

  testWidgets('桌面删除整条底部工具栏，视频与消息区延伸至底部', (tester) async {
    await mount(tester);
    expect(find.text('复制播放直链'), findsNothing);
    expect(find.text('复制链接'), findsNothing);
    expect(find.text('分享'), findsNothing);
    expect(tester.getRect(find.byType(_Surface)).bottom, 800);
  });
  testWidgets('页面和全屏Enter调用悬浮输入，长按与输入框Enter不重复打开', (tester) async {
    final room = await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: _Page(GlobalKey<_SurfaceState>(), input: true)));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 2);
  });
  testWidgets('桌面半屏和窄窗口上下布局均无底部功能栏', (tester) async {
    await mount(tester);
    for (final size in [
      const Size(1000, 1120),
      const Size(720, 1080),
      const Size(1280, 800),
      const Size(1000, 1120),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(find.byKey(const ValueKey('bottom-toolbar')), findsNothing,
          reason: '窗口 $size 不应重新出现底部功能栏');
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Enter survives focus loss and a child consuming the key', (tester) async {
    final room = await mount(tester);
    await tester.pumpWidget(MaterialApp(home: _ActionPage(
        GlobalKey<_SurfaceState>(), () {})));
    await tester.pump();
    await tester.tap(find.text('顶部操作'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 1);
    final node = FocusNode(onKeyEvent: (_, __) => KeyEventResult.handled);
    addTearDown(node.dispose);
    FocusScope.of(tester.element(find.text('顶部操作'))).requestFocus(node);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 2);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.composers, 2, reason: 'leaving the room unregisters Enter');
  });
  testWidgets('双击房间顶部空白，取消最大化后恢复1280乘720，单击无效', (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('window_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isMaximized') return true;
      if (call.method == 'isFullScreen') return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await mount(tester);
    final bar = tester.getRect(find.byType(AppBar));
    final blank = Offset(bar.left + 150, bar.center.dy);
    await tester.tapAt(blank);
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls.where((call) => call.method == 'setBounds'), isEmpty);
    await tester.tapAt(blank);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    final resize = calls.where((call) => call.method == 'setBounds');
    expect(resize, hasLength(1));
    expect((resize.single.arguments as Map)['width'], 1280);
    expect((resize.single.arguments as Map)['height'], 720);
    expect(calls.map((call) => call.method), contains('unmaximize'));
  });
  testWidgets('顶部操作按钮仍可连续点击，不被空白区域的双击抢走', (tester) async {
    final nativeCalls = <String>[];
    const channel = MethodChannel('window_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call.method);
      if (call.method == 'isFullScreen' || call.method == 'isMaximized') {
        return false;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await mount(tester);
    var clicks = 0;
    await tester.pumpWidget(MaterialApp(
        home: _ActionPage(GlobalKey<_SurfaceState>(), () => clicks++)));
    await tester.pump();
    await tester.tap(find.text('顶部操作'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('顶部操作'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(clicks, 2);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('直播间R刷新一次，按住不连刷，松开后可再次刷新', (tester) async {
    final room = await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 2);
    room.fullScreenState.value = true;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 3);
  });
  testWidgets('房间页面取得焦点时D开关弹幕，F反复进入退出全屏', (tester) async {
    final room = await mount(tester);
    final initial = room.showDanmakuState.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(room.showDanmakuState.value, !initial);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(room.showDanmakuState.value, initial);
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(room.fullScreenState.value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(room.fullScreenState.value, isFalse);
    }
    expect(room.enters, 5);
    expect(room.exits, 5);
  });
  testWidgets('点击顶部按钮后DFR仍有效，不需要先点视频', (tester) async {
    final room = await mount(tester);
    await tester.pumpWidget(
        MaterialApp(home: _ActionPage(GlobalKey<_SurfaceState>(), () {})));
    await tester.pump();
    await tester.tap(find.text('顶部操作'));
    await tester.pump();
    final initial = room.showDanmakuState.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(room.showDanmakuState.value, !initial);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(room.fullScreenState.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 1);
  });
  testWidgets('点选评论后DFR继续有效，只读评论不当作输入框', (tester) async {
    final room = await mount(tester);
    await tester
        .pumpWidget(MaterialApp(home: _ChatPage(GlobalKey<_SurfaceState>())));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selectable-chat')));
    await tester.pump();
    final initial = room.showDanmakuState.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(room.showDanmakuState.value, !initial);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(room.refreshes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(room.fullScreenState.value, isTrue);
  });

  testWidgets('输入框中DFR与Ctrl组合键不触发播放快捷键', (tester) async {
    final room = await mount(tester, input: true);
    final initial = room.showDanmakuState.value;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final key in [
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyR
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(room.refreshes, 0);
    await tester.tap(find.byKey(const ValueKey('chat-input')));
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyR
    ]) {
      await tester.sendKeyEvent(key);
    }
    expect(room.refreshes, 0);
    expect(room.enters, 0);
    expect(room.exits, 0);
    expect(room.showDanmakuState.value, initial);
  });
  for (final size in [const Size(480, 720), const Size(960, 640)]) {
    testWidgets('窗口 $size 连续全屏切换不迁移视频子树', (tester) async {
      Get.testMode = true;
      final room = _Room();
      Get.put<LiveRoomController>(room);
      final key = GlobalKey<_SurfaceState>();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });
      await tester.pumpWidget(MaterialApp(home: _Page(key)));
      await tester.pump();
      final original = key.currentState!;
      for (var i = 0; i < 30; i++) {
        // 同时覆盖布局先更新和尺寸通知先到达的时序。
        if (i.isEven) {
          room.fullScreenState.value = true;
          await tester.pump();
        }
        tester.view.physicalSize = const Size(1920, 1080);
        await tester.pump();
        room.fullScreenState.value = true;
        await tester.pump();
        expect(key.currentState, same(original));
        expect(tester.getSize(find.byType(_Surface)), const Size(1920, 1080));
        expect(find.byType(AppBar), findsNothing);
        expect(find.text('关注'), findsNothing);
        room.fullScreenState.value = false;
        await tester.pump();
        tester.view.physicalSize = size;
        await tester.pump();
        expect(key.currentState, same(original));
        expect(find.byType(AppBar), findsOneWidget);
      }
      expect(original.deactivations, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
