import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';
import 'package:simple_live_app/widgets/mobile_material_background.dart';
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
  late WindowAppearanceController controller;
  setUp(() async {
    storage = Get.put<LocalStorageService>(_Storage()) as _Storage;
    controller =
        Get.put(WindowAppearanceController(isWindows: false, isAndroid: true));
    await controller.initialize();
  });
  tearDown(Get.reset);

  test('Android五种材质立即生效，独立保存并重启恢复，不调用Windows通道', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('simple_live/window'), (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('simple_live/window'), null));
    storage.values['WindowMaterial'] = WindowMaterial.solid.index;
    for (final value in WindowMaterial.values) {
      await controller.setMaterial(value);
      expect(controller.effective.value, value);
      expect(storage.values['AndroidWindowMaterial'], value.index);
      final base = ThemeData.light();
      expect(
          controller.theme(base).scaffoldBackgroundColor,
          value == WindowMaterial.solid
              ? base.scaffoldBackgroundColor
              : Colors.transparent);
    }
    await controller.setMaterial(WindowMaterial.micaAlt);
    final restored =
        WindowAppearanceController(isWindows: false, isAndroid: true);
    await restored.initialize();
    expect(restored.selected.value, WindowMaterial.micaAlt);
    expect(restored.effective.value, WindowMaterial.micaAlt);
    expect(storage.values['WindowMaterial'], WindowMaterial.solid.index);
    expect(calls, isEmpty);
  });

  testWidgets('手机窄屏保留所有材质，无边框开关和Windows说明', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: WindowMaterialSettings()))));
    expect(find.textContaining('Windows 11'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<WindowMaterial>));
    await tester.pumpAndSettle();
    for (final material in WindowMaterial.values) {
      expect(find.text(material.label), findsWidgets);
    }
    await tester.tap(find.text('云母 Alt').last);
    await tester.pumpAndSettle();
    expect(controller.effective.value, WindowMaterial.micaAlt);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('边框'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('材质有不同背景、纯色可恢复，装饰不拦截点击且保留内容状态', (tester) async {
    var taps = 0;
    final contentKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: MobileMaterialBackground(
            controller: controller,
            child: Center(
                child: TextButton(
                    key: contentKey,
                    onPressed: () => taps++,
                    child: const Text('播放'))))));
    final state = contentKey.currentContext;
    final gradients = <Gradient>{};
    for (final value in WindowMaterial.values) {
      await controller.setMaterial(value);
      await tester.pump();
      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final backgrounds = boxes
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.gradient != null);
      if (value == WindowMaterial.solid) {
        expect(backgrounds, isEmpty);
      } else {
        gradients.add(backgrounds.first.gradient!);
      }
      expect(identical(contentKey.currentContext, state), isTrue);
      await tester.tap(find.text('播放'));
    }
    expect(gradients.length, 4);
    expect(taps, 5);
  });
}
