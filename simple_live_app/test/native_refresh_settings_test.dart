import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/settings/play_settings_page.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void setWindowsSuperResolution(bool e) => windowsSuperResolution.value = e;

  @override
  void setWindowsInterpolation(bool e) => windowsInterpolation.value = e;

  @override
  void setWindowsAudioExclusive(bool e) => windowsAudioExclusive.value = e;

  @override
  void setMobileDeband(bool e) => mobileDeband.value = e;

  @override
  void setMobileInterpolation(bool e) => mobileInterpolation.value = e;
}

void main() {
  testWidgets('直播间设置只显示观看偏好，性能策略没有开关', (tester) async {
    final settings = Get.put<AppSettingsController>(_Settings());
    try {
      await tester.pumpWidget(const GetMaterialApp(home: PlaySettingsPage()));
      expect(find.text('画面尺寸'), findsOneWidget);
      expect(find.text('进入后台自动暂停'), findsOneWidget);
      for (final title in [
        '屏幕刷新率',
        '系统管理',
        '硬件解码',
        '原生高帧率优先',
        '播放器缓冲上限',
        '缓冲策略',
        '直播延迟自动追帧',
        '卡顿自动降清晰度',
        '开播线路测速优选',
        '默认清晰度',
        '数据网络清晰度',
      ]) {
        expect(find.text(title), findsNothing);
      }

      if (Platform.isWindows) {
        final superRes = find.text('AI 超分增强（FSRCNNX）');
        await tester.scrollUntilVisible(superRes, 120);
        expect(superRes, findsOneWidget);
        expect(find.text('动态画面平滑（补帧）'), findsOneWidget);
        expect(find.text('WASAPI 音频独占'), findsOneWidget);

        await tester.tap(superRes);
        await tester.pump();
        expect(settings.windowsSuperResolution.value, isFalse);

        final interp = find.text('动态画面平滑（补帧）');
        await tester.scrollUntilVisible(interp, 120);
        await tester.tap(interp);
        await tester.pump();
        expect(settings.windowsInterpolation.value, isTrue);

        final exclusive = find.text('WASAPI 音频独占');
        await tester.scrollUntilVisible(exclusive, 120);
        await tester.tap(exclusive);
        await tester.pump();
        expect(settings.windowsAudioExclusive.value, isTrue);
      }
    } finally {
      Get.reset();
    }
  });

  testWidgets('手机端直播间设置展示去色带与高刷画面平滑开关并隐藏桌面独有项', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings = Get.put<AppSettingsController>(_Settings());
    try {
      await tester.pumpWidget(const GetMaterialApp(home: PlaySettingsPage()));
      expect(find.text('AI 超分增强（FSRCNNX）'), findsNothing);
      expect(find.text('WASAPI 音频独占'), findsNothing);

      final deband = find.text('画面去色带（Deband）');
      await tester.scrollUntilVisible(deband, 120);
      expect(deband, findsOneWidget);
      await tester.tap(deband);
      await tester.pump();
      expect(settings.mobileDeband.value, isFalse);

      final smooth = find.text('高刷动态画面平滑（补帧）');
      await tester.scrollUntilVisible(smooth, 120);
      expect(smooth, findsOneWidget);
      await tester.tap(smooth);
      await tester.pump();
      expect(settings.mobileInterpolation.value, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      Get.reset();
    }
  });
}
