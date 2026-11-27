import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/settings/play_settings_page.dart';

class _Settings extends AppSettingsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  testWidgets('直播间设置只显示观看偏好，性能策略没有开关', (tester) async {
    Get.put<AppSettingsController>(_Settings());
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
    } finally {
      Get.reset();
    }
  });
}
