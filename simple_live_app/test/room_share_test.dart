import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/services/windows_share_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const sharePlusChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const windowsShareChannel = WindowsShareService.channel;

  final sharePlusCalls = <Map<Object?, Object?>>[];
  final windowsShareCalls = <Map<Object?, Object?>>[];

  setUp(() {
    sharePlusCalls.clear();
    windowsShareCalls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(sharePlusChannel,
        (call) async {
      sharePlusCalls.add(Map<Object?, Object?>.from(call.arguments as Map));
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(windowsShareChannel,
        (call) async {
      expect(call.method, 'shareRoom');
      windowsShareCalls.add(Map<Object?, Object?>.from(call.arguments as Map));
      return <String, Object>{
        'status': 'opened',
        'code': '',
        'hresult': '0x00000000',
        'dataRequested': true,
        'elevated': false,
        'cdpDisabled': false,
        'message': '',
      };
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(sharePlusChannel, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(windowsShareChannel, null);
    Get.reset();
  });

  const urls = {
    'huya': 'https://www.huya.com/546540',
    'douyin': 'https://live.douyin.com/580056875446',
    'bilibili': 'https://live.bilibili.com/7734200',
    'douyu': 'https://www.douyu.com/24422',
  };

  LiveRoomController createController({
    required String siteId,
    required String url,
    String title = '直播测试 🎮',
    String userName = '主播',
  }) {
    final controller =
        LiveRoomController(pSite: Sites.allSites[siteId]!, pRoomId: 'test');
    addTearDown(controller.scrollController.dispose);
    controller.detail.value = LiveRoomDetail(
      roomId: 'test',
      title: title,
      cover: '',
      userName: userName,
      userAvatar: '',
      online: 0,
      status: true,
      url: url,
    );
    return controller;
  }

  for (final entry in urls.entries) {
    for (final title in ['直播测试 🎮', '   ']) {
      testWidgets(
        'Windows ${entry.key} 默认打开应用内分享：$title',
        (tester) async {
          await tester.pumpWidget(GetMaterialApp(
            builder: FlutterSmartDialog.init(),
            home: const Scaffold(),
          ));
          final controller = createController(
            siteId: entry.key,
            url: entry.value,
            title: title,
          );
          final share = controller.share();
          await tester.pumpAndSettle();

          expect(windowsShareCalls, isEmpty);
          expect(sharePlusCalls, isEmpty);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text(entry.value), findsOneWidget);

          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          await share;
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  for (final entry in urls.entries) {
    for (final title in ['直播测试 🎮', '   ']) {
      testWidgets(
        '移动端 ${entry.key} 保持 share_plus 系统分享：$title',
        (tester) async {
          final controller = createController(
            siteId: entry.key,
            url: entry.value,
            title: title,
          );
          await controller.share();

          expect(sharePlusCalls, hasLength(1));
          expect(windowsShareCalls, isEmpty);
          expect(
              (sharePlusCalls.single['title'] as String?)?.trim(), isNotEmpty);
          expect((sharePlusCalls.single['subject'] as String?)?.trim(),
              isNotEmpty);
          expect(sharePlusCalls.single['text'], contains(entry.value));
          expect(sharePlusCalls.single['uri'], isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('Windows 复制、重复打开及系统分享失败后仍能复制', (tester) async {
    var failCopy = true;
    final copied = <String>[];
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failCopy) throw PlatformException(code: 'clipboard_busy');
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    messenger.setMockMethodCallHandler(windowsShareChannel, (call) async {
      windowsShareCalls.add(Map<Object?, Object?>.from(call.arguments as Map));
      return {'status': 'opened', 'dataRequested': true};
    });

    await tester.pumpWidget(GetMaterialApp(
      builder: FlutterSmartDialog.init(),
      home: const Scaffold(),
    ));
    final url = urls['huya']!;
    final controller = createController(siteId: 'huya', url: url);
    final share = controller.share();
    await controller.share();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(windowsShareCalls, isEmpty);

    await tester.tap(find.text('Windows 系统分享'));
    await tester.pumpAndSettle();
    expect(windowsShareCalls.single['text'], '直播测试 🎮\n$url');
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(find.text('复制失败，可手动选中链接'), findsOneWidget);
    failCopy = false;
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制标题和链接'));
    await tester.pumpAndSettle();
    expect(copied, [url, '直播测试 🎮\n$url']);
    expect(find.text('已复制标题和链接'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await share;
    final reopened = controller.share();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await reopened;
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  test('未加载房间详情不调用系统分享', () async {
    final controller =
        LiveRoomController(pSite: Sites.allSites['huya']!, pRoomId: 'test');
    addTearDown(controller.scrollController.dispose);
    await controller.share();
    expect(windowsShareCalls, isEmpty);
    expect(sharePlusCalls, isEmpty);
  });

  for (final url in ['', 'not a link', 'file:///C:/private']) {
    testWidgets('无效链接不打开分享面板：$url', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(),
      ));
      final controller = createController(
        siteId: 'huya',
        url: url,
        title: '',
        userName: '',
      );
      await controller.share();
      await tester.pump();
      expect(windowsShareCalls, isEmpty);
      expect(sharePlusCalls, isEmpty);
      expect(find.text('直播间链接无效，暂时无法分享'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    '移动端系统分享异常被捕获并提示，不产生未处理异常',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(),
      ));
      binding.defaultBinaryMessenger.setMockMethodCallHandler(sharePlusChannel,
          (_) async {
        throw PlatformException(code: 'share_failed');
      });
      final controller = createController(
        siteId: 'huya',
        url: urls['huya']!,
        title: '',
        userName: '',
      );
      await controller.share();
      await tester.pump();
      expect(find.text('无法打开系统分享，请尝试“复制链接”'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
