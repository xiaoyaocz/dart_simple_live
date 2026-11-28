import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';
import 'package:simple_live_app/widgets/settings/window_material_settings.dart';

class _Storage extends LocalStorageService {
  final values = <dynamic, dynamic>{};
  @override
  T getValue<T>(dynamic key, T fallback) => (values[key] ?? fallback) as T;
  @override
  Future<void> setValue<T>(dynamic key, T value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late List<MethodCall> effects;
  var build = 22621;
  var transparency = true;
  var fail = false;
  setUp(() {
    storage = Get.put<LocalStorageService>(_Storage()) as _Storage;
    effects = [];
    build = 22621;
    transparency = true;
    fail = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('simple_live/window'), (call) async {
      if (call.method == 'appearanceCapabilities') {
        return {'build': build, 'transparency': transparency};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.alexmercerind/flutter_acrylic'), (call) async {
      if (call.method == 'SetEffect') {
        if (fail) throw PlatformException(code: 'unsupported');
        effects.add(call);
      }
      return null;
    });
  });
  tearDown(() => Get.reset());
  test('重复系统主题通知不重复配置原生效果', () async {
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    final initial = effects.length;
    await controller.apply();
    await controller.apply();
    expect(effects.length, initial);
  });
  test('原生材质失效后相同配置也恢复，不改深色和材质偏好', () async {
    storage.values[LocalStorageService.kThemeMode] = 2;
    storage.values['WindowMaterial'] = WindowMaterial.acrylic.index;
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    final initial = effects.length;
    await controller.apply(force: true);
    expect(effects.length, initial + 1);
    expect(effects.last.arguments['dark'], isTrue);
    expect(controller.selected.value, WindowMaterial.acrylic);
    expect(controller.effective.value, WindowMaterial.acrylic);
    expect(controller.theme(ThemeData.dark()).scaffoldBackgroundColor,
        Colors.transparent);
    await controller.apply();
    expect(effects.length, initial + 1);
    expect(storage.values['WindowMaterial'], WindowMaterial.acrylic.index);
  });
  test('系统透明效果恢复后重新应用原选择，不停留在纯色', () async {
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    await controller.setMaterial(WindowMaterial.acrylic);
    transparency = false;
    await controller.apply();
    expect(controller.effective.value, WindowMaterial.solid);
    transparency = true;
    await controller.apply(force: true);
    expect(controller.effective.value, WindowMaterial.acrylic);
    expect(controller.selected.value, WindowMaterial.acrylic);
  });
  test('连续选择以最后一项为准，不遗留旧材质', () async {
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    await Future.wait([
      controller.setMaterial(WindowMaterial.mica),
      controller.setMaterial(WindowMaterial.acrylic),
      controller.setMaterial(WindowMaterial.micaAlt),
    ]);
    expect(controller.selected.value, WindowMaterial.micaAlt);
    expect(controller.effective.value, WindowMaterial.micaAlt);
    expect(storage.values['WindowMaterial'], WindowMaterial.micaAlt.index);
  });
  testWidgets('窄窗口保留五种材质，移除边框开关，选择立即保存', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = Get.put(WindowAppearanceController(isWindows: true));
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
        body: SingleChildScrollView(child: WindowMaterialSettings()))));
    await tester.tap(find.byType(DropdownButtonFormField<WindowMaterial>));
    await tester.pumpAndSettle();
    for (final material in WindowMaterial.values) {
      expect(find.text(material.label), findsWidgets);
    }
    await tester.tap(find.text('云母 Alt').last);
    await tester.pumpAndSettle();
    expect(storage.values['WindowMaterial'], WindowMaterial.micaAlt.index);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('边框'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('默认轻薄亚克力，所有材质均能切换且重启恢复偏好', () async {
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    expect(controller.effective.value, WindowMaterial.lightAcrylic);
    for (final material in WindowMaterial.values) {
      await controller.setMaterial(material);
      expect(controller.effective.value, material);
      expect(storage.values['WindowMaterial'], material.index);
    }
    await controller.setMaterial(WindowMaterial.micaAlt);
    final restored = WindowAppearanceController(isWindows: true);
    await restored.initialize();
    expect(restored.selected.value, WindowMaterial.micaAlt);
    expect(restored.effective.value, WindowMaterial.micaAlt);
    expect(effects.last.arguments['dark'], isFalse);
  });
  test('旧系统降级材质但保留用户选择', () async {
    build = 19045;
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    await controller.setMaterial(WindowMaterial.micaAlt);
    expect(controller.selected.value, WindowMaterial.micaAlt);
    expect(controller.effective.value, WindowMaterial.acrylic);
    transparency = false;
    await controller.apply();
    expect(controller.effective.value, WindowMaterial.solid);
    expect(storage.values['WindowMaterial'], WindowMaterial.micaAlt.index);
  });
  test('系统或原生效果失败时使用不透明背景', () async {
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    fail = true;
    await controller.setMaterial(WindowMaterial.mica);
    expect(controller.effective.value, WindowMaterial.solid);
    expect(controller.theme(ThemeData.light()).scaffoldBackgroundColor.a, 1);
  });
  test('旧边框偏好不影响材质，深浅色更新不改变选择', () async {
    storage.values['WindowBorder'] = false;
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    await controller.apply(brightness: Brightness.dark);
    expect(effects.last.arguments['dark'], isTrue);
    expect(controller.selected.value, WindowMaterial.lightAcrylic);
  });
  test('移动端不调用窗口插件也不改变原有主题', () async {
    final controller = WindowAppearanceController(isWindows: false);
    await controller.initialize();
    final theme = ThemeData.light();
    expect(identical(controller.theme(theme), theme), isTrue);
    expect(effects, isEmpty);
  });
  test('非法存储回退默认，轻薄和标准亚克力有不同背景浓度', () async {
    storage.values['WindowMaterial'] = 999;
    final controller = WindowAppearanceController(isWindows: true);
    await controller.initialize();
    final light = controller.tint(ThemeData.light());
    await controller.setMaterial(WindowMaterial.acrylic);
    expect(controller.tint(ThemeData.light()).a, greaterThan(light.a));
    final theme = controller.theme(ThemeData.light());
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(theme.navigationRailTheme.backgroundColor!.a, lessThan(1));
  });
}
