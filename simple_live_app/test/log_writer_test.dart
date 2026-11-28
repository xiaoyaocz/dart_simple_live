import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/settings/other/other_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('log-writer-test-');
  });

  tearDown(() async {
    await Log.disposeWriter();
    Get.reset();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Log.i 只写一次，且按长度截断并在 5 秒窗口内折叠重复日志', () async {
    var clock = DateTime(2026, 11, 27, 22, 0, 0);
    final writer = LogFileWriter(
      directory: tempDir,
      maxFileBytes: 64 * 1024,
      maxFiles: 5,
      maxEntryChars: 40,
      dedupeWindow: const Duration(seconds: 5),
      now: () => clock,
      writeSystemMetadata: false,
    );
    await writer.ready;
    Log.logFileWriter = writer;

    Log.i('单次普通信息');
    for (var i = 0; i < 4; i++) {
      clock = clock.add(const Duration(seconds: 1));
      Log.i('刷屏重复消息');
    }
    clock = clock.add(const Duration(seconds: 10));
    Log.i('X' * 100);
    await writer.close();

    final files = tempDir.listSync().whereType<File>().toList();
    expect(files.length, 1);
    final lines = files.single.readAsLinesSync();
    expect(lines.where((l) => l.contains('单次普通信息')).length, 1);
    expect(lines.where((l) => l.contains('刷屏重复消息')).length, 1);
    expect(lines.any((l) => l.contains('重复 3 次')), isTrue);
    final truncated = lines.singleWhere((l) => l.contains('...[truncated]'));
    expect(truncated.length, lessThan(85));
  });

  test('超出单文件上限自动轮转，且保留最多 maxFiles 个日志文件', () async {
    var clock = DateTime(2026, 11, 27, 22, 10, 0);
    final writer = LogFileWriter(
      directory: tempDir,
      maxFileBytes: 120,
      maxFiles: 3,
      now: () => clock,
      writeSystemMetadata: false,
    );
    await writer.ready;

    for (var i = 0; i < 12; i++) {
      clock = clock.add(const Duration(seconds: 1));
      writer.write('第 $i 条测试日志数据_${'A' * 60}');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await writer.close();

    final files = tempDir.listSync().whereType<File>().toList();
    expect(files.length, lessThanOrEqualTo(3));
    expect(files.length, greaterThanOrEqualTo(2));
  });

  test('OtherSettingsController.setLogEnable(false) 关闭文件写入器并保存状态', () async {
    Hive.init(tempDir.path);
    await Get.put(LocalStorageService()).init();
    Get.put(AppSettingsController());
    final controller = OtherSettingsController();

    controller.setLogEnable(false);
    expect(AppSettingsController.instance.logEnable.value, isFalse);
    expect(Log.logFileWriter, isNull);
  });
}
