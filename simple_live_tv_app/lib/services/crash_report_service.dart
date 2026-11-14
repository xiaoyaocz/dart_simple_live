import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 全局崩溃/未捕获异常捕获，落盘到本地日志文件。
///
/// TV 端此前没有任何全局错误捕获，闪退不留任何证据；
/// 本服务把 Dart 层未捕获异常与 Flutter 框架异常写入
/// `<应用支持目录>/log/crash-*.log`，供用户反馈时取回排查。
class CrashReportService {
  CrashReportService._();

  static final CrashReportService instance = CrashReportService._();

  static const int _maxCrashFiles = 5;
  static const int _maxFileSize = 512 * 1024;

  Directory? _logDir;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      _logDir = Directory(p.join(appSupportDir.path, "log"));
      await _logDir!.create(recursive: true);
    } catch (_) {
      // 日志目录创建失败时静默降级，不影响启动
      return;
    }

    FlutterError.onError = (details) {
      _writeCrashLog("FLUTTER_ERROR", details.toString());
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _writeCrashLog(
        "UNCAUGHT_ERROR",
        "$error\n$stackTrace",
      );
      return true;
    };
  }

  void _writeCrashLog(String level, String detail) {
    final timestamp = DateTime.now();
    final buffer = StringBuffer()
      ..writeln("=== $level ${timestamp.toIso8601String()} ===")
      ..writeln(detail)
      ..writeln();
    // fire-and-forget：崩溃路径上不能阻塞
    unawaited(_appendLog(buffer.toString(), timestamp));
  }

  Future<void> _appendLog(String content, DateTime timestamp) async {
    final dir = _logDir;
    if (dir == null) {
      return;
    }
    try {
      final file = File(p.join(
        dir.path,
        "crash-${_fileStamp(timestamp)}.log",
      ));
      var size = 0;
      if (await file.exists()) {
        size = await file.length();
      }
      // 超过单文件上限则另起新文件
      final target = size >= _maxFileSize
          ? File(p.join(
              dir.path,
              "crash-${_fileStamp(DateTime.now())}.log",
            ))
          : file;
      await target.writeAsString(content,
          mode: FileMode.append, flush: true);
      await _cleanupOldLogs(dir);
    } catch (_) {
      // 崩溃写日志自身失败时静默
    }
  }

  Future<void> _cleanupOldLogs(Directory dir) async {
    final crashFiles = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path).startsWith("crash-") &&
          entity.path.endsWith(".log")) {
        crashFiles.add(entity);
      }
    }
    if (crashFiles.length <= _maxCrashFiles) {
      return;
    }
    crashFiles.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );
    for (final file in crashFiles.take(crashFiles.length - _maxCrashFiles)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  String _fileStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return "${time.year}$month$day";
  }
}
