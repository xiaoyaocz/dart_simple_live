import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'package:simple_live_core/simple_live_core.dart';

class _Settings extends AppSettingsController {
  // 测试不初始化持久化设置。
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Room extends LiveRoomController {
  _Room() : super(pSite: Sites.allSites['huya']!, pRoomId: '1');
  int scrolls = 0;
  @override
  void chatScrollToBottom() => scrolls++;
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.count, Listenable repaint) : super(repaint: repaint);
  final VoidCallback count;
  @override
  void paint(Canvas canvas, Size size) {
    count();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

// 仅用于记录测试期间的构造和重绘次数。
// ignore: must_be_immutable
class _Page extends LiveRoomPage {
  _Page(this.room);
  final _Room room;
  final videoTick = ValueNotifier(0);
  final chatTick = ValueNotifier(0);
  int videoBuilds = 0;
  int chatBuilds = 0;
  int videoPaints = 0;
  int chatPaints = 0;
  @override
  LiveRoomController get controller => room;
  @override
  List<Widget> buildAppbarActions(BuildContext context) => [];
  @override
  Widget buildUserProfile(BuildContext context) => const SizedBox(height: 60);
  @override
  Widget buildBottomActions(BuildContext context) => const SizedBox(height: 48);
  @override
  Widget buildMediaPlayer() {
    videoBuilds++;
    return CustomPaint(
      key: const ValueKey('video'),
      painter: _PaintCounter(() => videoPaints++, videoTick),
      child: const SizedBox.expand(),
    );
  }

  @override
  Widget buildMessageArea() {
    chatBuilds++;
    return Expanded(
      child: CustomPaint(
        key: const ValueKey('chat'),
        painter: _PaintCounter(() => chatPaints++, chatTick),
        child: const SizedBox.expand(),
      ),
    );
  }
}

void main() {
  setUp(() => Get.put<AppSettingsController>(_Settings()));
  tearDown(() => Get.reset());

  testWidgets('Windows 五种浅色材质下聊天文字对比度稳定', (tester) async {
    final room = _Room();
    addTearDown(room.scrollController.dispose);
    final page = _Page(room);
    final settings = Get.find<AppSettingsController>();
    settings.chatTextSize.value = 18;
    settings.chatBubbleStyle.value = true;
    final appearance = WindowAppearanceController(isWindows: true);
    final theme = ThemeData(platform: TargetPlatform.windows);
    final systemMessage = LiveMessage(
      type: LiveMessageType.chat,
      userName: 'LiveSysMessage',
      message: '弹幕已连接',
      color: LiveMessageColor.white,
    );
    final chatMessage = LiveMessage(
      type: LiveMessageType.chat,
      userName: '观众',
      message: '多行弹幕正文',
      color: LiveMessageColor.white,
    );
    final chatList = Builder(
      builder: (context) => Column(
        children: [
          page.buildMessageItem(context, systemMessage),
          page.buildMessageItem(context, chatMessage),
        ],
      ),
    );
    double contrast(Color foreground, Color background) =>
        (background.computeLuminance() + .05) /
        (foreground.computeLuminance() + .05);

    for (final material in WindowMaterial.values) {
      appearance.effective.value = material;
      await tester.pumpWidget(MaterialApp(
        theme: appearance.theme(theme),
        home: ColoredBox(
          color: appearance.tint(theme),
          child: page.buildOfficialChatArea(chatList),
        ),
      ));
      final panel = tester.widget<ColoredBox>(
        find
            .ancestor(
                of: find.byWidget(chatList), matching: find.byType(ColoredBox))
            .first,
      );
      final content = find.byType(LiveMessageContent);
      final bubble = tester.widget<Container>(
        find.ancestor(of: content, matching: find.byType(Container)).first,
      );
      final bubbleColor = (bubble.decoration! as BoxDecoration).color!;
      final rich = tester.widget<Text>(
        find.descendant(of: content, matching: find.byType(Text)),
      );
      final span = rich.textSpan! as TextSpan;
      final nickname = span.style!;
      final body = (span.children!.single as TextSpan).style!;
      final system = tester.widget<Text>(find.text('弹幕已连接')).style!;
      expect(panel.color.a, 1);
      expect(bubbleColor.a, 1);
      for (final background in [panel.color, bubbleColor]) {
        expect(
            contrast(nickname.color!, background), greaterThanOrEqualTo(4.5));
        expect(contrast(body.color!, background), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(system.color!, panel.color), greaterThanOrEqualTo(4.5));
      expect(nickname.fontSize, 18);
      expect(nickname.height, greaterThan(1.2));
    }
    settings.chatBubbleStyle.value = false;
    await tester.pump();
    expect(
        find.ancestor(
          of: find.byType(LiveMessageContent),
          matching: find.byType(Container),
        ),
        findsNothing);
  });

  Future<_Page> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final page = _Page(_Room());
    addTearDown(page.videoTick.dispose);
    addTearDown(page.chatTick.dispose);
    await tester.pumpWidget(GetMaterialApp(
        home: Builder(
      builder: (_) => page.buildPageUI(),
    )));
    await tester.pumpAndSettle();
    return page;
  }

  testWidgets('连续缩放只重新布局，不重复构造视频和聊天区', (tester) async {
    final page = await mount(tester);
    final initialVideo = page.videoBuilds;
    final initialChat = page.chatBuilds;
    for (var i = 1; i <= 30; i++) {
      tester.view.physicalSize = Size(1200 + i * 10, 800 + i * 2);
      await tester.pump(const Duration(milliseconds: 16));
      final videoRect = tester.getRect(find.byKey(const ValueKey('video')));
      final chatRect = tester.getRect(find.byKey(const ValueKey('chat')));
      expect(videoRect.right, chatRect.left);
      expect(chatRect.width, 300);
      expect(videoRect.bottom, chatRect.bottom);
    }
    // 输出计数便于比较优化前后的实际构造次数。
    debugPrint(
        '30 次 resize：视频 ${page.videoBuilds - initialVideo} 次，聊天 ${page.chatBuilds - initialChat} 次');
    expect(page.videoBuilds, initialVideo);
    expect(page.chatBuilds, initialChat);
  });

  testWidgets('视频帧与聊天更新分别重绘，互不带动另一侧重绘', (tester) async {
    final page = await mount(tester);
    final chatPaints = page.chatPaints;
    page.videoTick.value++;
    await tester.pump();
    expect(page.chatPaints, chatPaints);

    final videoPaints = page.videoPaints;
    page.chatTick.value++;
    await tester.pump();
    expect(page.videoPaints, videoPaints);
  });

  testWidgets('跨横竖布局边界时仍更新布局，再缩放不重复构造', (tester) async {
    final page = await mount(tester);
    tester.view.physicalSize = const Size(600, 900);
    await tester.pumpAndSettle();
    final videoRect = tester.getRect(find.byKey(const ValueKey('video')));
    final chatRect = tester.getRect(find.byKey(const ValueKey('chat')));
    expect(videoRect.width, 600);
    expect(videoRect.height, closeTo(600 / (16 / 9), 0.01));
    expect(chatRect.top, greaterThan(videoRect.bottom));
    final builds = page.videoBuilds;
    tester.view.physicalSize = const Size(620, 920);
    await tester.pumpAndSettle();
    expect(page.videoBuilds, builds);
  });

  testWidgets('同一帧多条聊天消息只安排一次自动滚动，消息完整保留', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final room = _Room();
    for (var i = 0; i < 40; i++) {
      room.onWSMessage(LiveMessage(
        type: LiveMessageType.chat,
        userName: '用户',
        message: '$i',
        color: LiveMessageColor.white,
      ));
    }
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(room.messages.length, 40);
    debugPrint('40 条聊天消息：滚动回调 ${room.scrolls} 次');
    expect(room.scrolls, 1);
    room.onWSMessage(LiveMessage(
      type: LiveMessageType.chat,
      userName: '用户',
      message: '下一帧',
      color: LiveMessageColor.white,
    ));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(room.scrolls, 2);
    room.disableAutoScroll.value = true;
    room.onWSMessage(LiveMessage(
      type: LiveMessageType.chat,
      userName: '用户',
      message: '手动上拉后继续收消息',
      color: LiveMessageColor.white,
    ));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(room.scrolls, 2);
    expect(room.messages.length, 42);
  });
}
