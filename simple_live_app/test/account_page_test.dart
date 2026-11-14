import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/modules/mine/account/account_page.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';

class _FakeBiliBiliAccountService extends BiliBiliAccountService {
  // The fake intentionally skips storage and network initialization.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeDouyuAccountService extends DouyuAccountService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeDouyinAccountService extends DouyinAccountService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeKuaishouAccountService extends KuaishouAccountService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.put<BiliBiliAccountService>(_FakeBiliBiliAccountService());
    Get.put<DouyuAccountService>(_FakeDouyuAccountService());
    Get.put<DouyinAccountService>(_FakeDouyinAccountService());
    Get.put<KuaishouAccountService>(_FakeKuaishouAccountService());
    Get.put(AccountController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('account page builds every platform row without an error box',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: AccountPage(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('哔哩哔哩'), findsOneWidget);
    expect(find.text('斗鱼直播'), findsOneWidget);
    expect(find.text('虎牙直播'), findsOneWidget);
    expect(find.text('抖音直播'), findsOneWidget);
    expect(find.text('快手直播'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);

    await tester.tap(find.text('斗鱼直播'));
    await tester.pumpAndSettle();

    // 斗鱼入口先弹账号菜单（扫码登录 / 手动配置 Cookie），再进 Cookie 对话框
    expect(find.text('扫码登录'), findsOneWidget);
    expect(find.text('手动配置 Cookie'), findsOneWidget);
    await tester.tap(find.text('手动配置 Cookie'));
    await tester.pumpAndSettle();

    final cookieField = tester.widget<TextField>(find.byType(TextField));
    expect(cookieField.decoration?.alignLabelWithHint, isTrue);
    expect(
      cookieField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
  });
}
