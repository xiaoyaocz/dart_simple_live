import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/utils.dart';

class Log {
  static LogFileWriter? logFileWriter;
  static void initWriter() {
    final previous = logFileWriter;
    logFileWriter = LogFileWriter();
    if (previous != null) {
      unawaited(previous.close());
    }
  }

  static Future<void> disposeWriter() async {
    final writer = logFileWriter;
    logFileWriter = null;
    await writer?.close();
  }

  static void writeLog(content, [Level level = Level.info]) {
    final text = content.toString();
    logFileWriter?.write(
      "[${level.name.toUpperCase()}] $_currentTime：$text",
      dedupeKey: "${level.name}:$text",
    );
  }

  static RxList<DebugLogModel> debugLogs = <DebugLogModel>[].obs;

  static void addDebugLog(String content, Color? color) {
    if (kReleaseMode) {
      return;
    }
    if (content.contains("请求响应")) {
      content = content.split("\n").join('\n💡 ');
    }
    try {
      debugLogs.insert(0, DebugLogModel(DateTime.now(), content, color: color));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  static Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  static void d(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.orange);
      logger.d("${DateTime.now().toString()}\n$message");
    }
    if (writeFile) {
      writeLog(message, Level.debug);
    }
  }

  static void i(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.blue);
      logger.i("${DateTime.now().toString()}\n$message");
    }
    if (writeFile) {
      writeLog(message, Level.info);
    }
  }

  static void e(String message, StackTrace stackTrace,
      [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
      logger.e("${DateTime.now().toString()}\n$message", stackTrace: stackTrace);
    }
    if (writeFile) {
      writeLog("$message\n$stackTrace", Level.error);
    }
  }

  static void w(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.pink);
      logger.w("${DateTime.now().toString()}\n$message");
    }
    if (writeFile) {
      writeLog(message, Level.warning);
    }
  }

  static void logPrint(dynamic obj, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(obj.toString(), Colors.red);
    }
    if (writeFile) {
      writeLog(obj, Level.info);
    }
    if (kDebugMode) {
      print(obj);
    }
  }

  static String get _currentTime => Utils.timeFormat.format(DateTime.now());
}

class LogFileWriter {
  static const int defaultMaxFileBytes = 5 * 1024 * 1024;
  static const int defaultMaxFiles = 5;
  static const int defaultMaxEntryChars = 2048;
  static const Duration defaultDedupeWindow = Duration(seconds: 5);

  LogFileWriter({
    Directory? directory,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxFiles = defaultMaxFiles,
    this.maxEntryChars = defaultMaxEntryChars,
    this.dedupeWindow = defaultDedupeWindow,
    DateTime Function()? now,
    this.writeSystemMetadata = true,
  })  : _directoryOverride = directory,
        _now = now ?? DateTime.now {
    fileName = _nextFileName();
    _ready = initFile();
  }

  final Directory? _directoryOverride;
  final int maxFileBytes;
  final int maxFiles;
  final int maxEntryChars;
  final Duration dedupeWindow;
  final DateTime Function() _now;
  final bool writeSystemMetadata;

  late String fileName;
  late Future<void> _ready;
  Future<void> get ready => _ready;

  Directory? _logDir;
  IOSink? fileWriter;
  int _currentBytes = 0;
  int _sequence = 0;
  bool _closed = false;
  Future<void> _pendingIo = Future<void>.value();

  String? _lastKey;
  DateTime? _lastWriteAt;
  int _repeatCount = 0;

  String _nextFileName() {
    final dt = DateFormat("yyyy-MM-dd HH-mm-ss").format(_now());
    final seq = _sequence++;
    return seq == 0 ? "$dt.log" : "$dt-$seq.log";
  }

  Future<void> initFile() async {
    final logDir = _directoryOverride ??
        Directory("${(await getApplicationSupportDirectory()).path}/log");
    _logDir = logDir;
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    await _pruneOldFiles(reserveSlots: 1);
    if (_closed) return;
    final logFile = File("${logDir.path}/$fileName");
    _currentBytes = await logFile.exists() ? await logFile.length() : 0;
    fileWriter = logFile.openWrite(mode: FileMode.append);
    if (writeSystemMetadata) {
      unawaited(writeSystemInfo());
    }
  }

  Future<void> _pruneOldFiles({int reserveSlots = 0}) async {
    final logDir = _logDir;
    if (logDir == null || !await logDir.exists()) return;
    final keep = (maxFiles - reserveSlots).clamp(0, maxFiles);
    final entries = <({File file, DateTime modified})>[];
    await for (final entity in logDir.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.log')) {
        continue;
      }
      if (entity.path.endsWith('/$fileName') ||
          entity.path.endsWith('\\$fileName')) {
        continue;
      }
      try {
        entries.add((file: entity, modified: await entity.lastModified()));
      } catch (_) {}
    }
    if (entries.length <= keep) return;
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    for (final stale in entries.skip(keep)) {
      try {
        await stale.file.delete();
      } catch (_) {}
    }
  }

  String _truncate(String content) {
    if (content.length <= maxEntryChars) return content;
    return "${content.substring(0, maxEntryChars)}...[truncated]";
  }

  void write(String content, {String? dedupeKey}) {
    if (_closed) return;
    final sink = fileWriter;
    if (sink == null) return;
    final normalized = _truncate(content);
    final key = dedupeKey ?? normalized;
    final now = _now();
    if (_lastKey == key &&
        _lastWriteAt != null &&
        now.difference(_lastWriteAt!) < dedupeWindow) {
      _repeatCount++;
      return;
    }
    _flushRepeatSummary();
    _lastKey = key;
    _lastWriteAt = now;
    _repeatCount = 0;
    _writeLine(normalized);
  }

  void _flushRepeatSummary() {
    if (_repeatCount <= 0) return;
    final summary =
        "[以上日志在 ${dedupeWindow.inSeconds} 秒内重复 $_repeatCount 次]";
    _repeatCount = 0;
    _writeLine(summary);
  }

  void _writeLine(String line) {
    final sink = fileWriter;
    final logDir = _logDir;
    if (sink == null) return;
    final lineBytes = utf8.encode(line).length + 2;
    if (logDir != null &&
        _currentBytes > 0 &&
        _currentBytes + lineBytes > maxFileBytes) {
      _rotate(logDir);
    }
    final activeSink = fileWriter;
    if (activeSink == null) return;
    activeSink.write(line);
    activeSink.write("\r\n");
    _currentBytes += lineBytes;
  }

  void _rotate(Directory logDir) {
    final oldSink = fileWriter;
    fileName = _nextFileName();
    final nextFile = File("${logDir.path}/$fileName");
    fileWriter = nextFile.openWrite(mode: FileMode.append);
    _currentBytes = 0;
    _pendingIo = _pendingIo.then((_) async {
      try {
        await oldSink?.flush();
        await oldSink?.close();
      } catch (_) {}
      await _pruneOldFiles(reserveSlots: 1);
    });
  }

  Future<void> flush() async {
    await _ready;
    _flushRepeatSummary();
    await _pendingIo;
    await fileWriter?.flush();
  }

  Future close() async {
    if (_closed) return;
    _closed = true;
    await _ready;
    _flushRepeatSummary();
    await _pendingIo;
    final sink = fileWriter;
    fileWriter = null;
    try {
      await sink?.flush();
    } catch (_) {}
    await sink?.close();
  }

  Future<void> writeSystemInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      _writeLine("System Info:");
      _writeLine("Current Time: ${_now()}");
      _writeLine("Platform: ${Platform.operatingSystem}");
      _writeLine("Version: ${Platform.operatingSystemVersion}");
      _writeLine("Local: ${Platform.localeName}");
      _writeLine(
          "App Version: ${Utils.packageInfo.version}+${Utils.packageInfo.buildNumber}");
      if (Platform.isAndroid) {
        _writeLine((await deviceInfo.androidInfo).data.toString());
      } else if (Platform.isIOS) {
        _writeLine((await deviceInfo.iosInfo).data.toString());
      } else if (Platform.isLinux) {
        _writeLine((await deviceInfo.linuxInfo).data.toString());
      } else if (Platform.isMacOS) {
        _writeLine((await deviceInfo.macOsInfo).data.toString());
      } else if (Platform.isWindows) {
        _writeLine((await deviceInfo.windowsInfo).data.toString());
      }
      _writeLine("End System Info");
    } catch (_) {}
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
