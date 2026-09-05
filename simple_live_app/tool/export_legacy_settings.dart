import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

const _keywordShieldPrefix = 'keyword:';
const _userShieldPrefix = 'user:';
const _globalUserShieldSiteId = '__all__';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dataDir = options['data-dir']?.trim();
  if (dataDir == null || dataDir.isEmpty) {
    stderr.writeln('Missing --data-dir <Simple Live Hive data directory>.');
    exitCode = 64;
    return;
  }

  final dir = Directory(dataDir);
  if (!dir.existsSync()) {
    stderr.writeln('Data directory does not exist: $dataDir');
    exitCode = 66;
    return;
  }

  final outPath = options['out']?.trim() ??
      'simple-live-settings-${DateTime.now().millisecondsSinceEpoch}.json';

  Hive
    ..init(dir.path)
    ..registerAdapter(LegacyFollowUserAdapter())
    ..registerAdapter(LegacyHistoryAdapter())
    ..registerAdapter(LegacyFollowUserTagAdapter());

  final settings = await _openOptionalBox(dir, 'LocalStorage');
  final shield = await _openOptionalBox<String>(dir, 'DanmuShield');
  final shieldPreset = await _openOptionalBox<String>(dir, 'DanmuShieldPreset');
  final follows = await _openOptionalBox<LegacyFollowUser>(dir, 'FollowUser');
  final tags =
      await _openOptionalBox<LegacyFollowUserTag>(dir, 'FollowUserTag');
  final histories = await _openOptionalBox<LegacyHistory>(dir, 'History');
  final legacyHistories = histories == null
      ? await _openOptionalBox<LegacyHistory>(dir, 'Hostiry')
      : null;

  final shieldExport = _exportShieldBox(shield);
  final payload = <String, dynamic>{
    'schema': 'simple_live_legacy_settings_export',
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'sourceDataDir': dir.absolute.path,
    'boxes': {
      'settings': _exportBoxMap(settings),
      'danmuShield': shieldExport,
      'danmuShieldPreset': _exportShieldPresets(shieldPreset),
      'followUsers':
          _exportValues(follows, (LegacyFollowUser item) => item.toJson()),
      'followUserTags':
          _exportValues(tags, (LegacyFollowUserTag item) => item.toJson()),
      'histories': _exportValues(
        histories ?? legacyHistories,
        (LegacyHistory item) => item.toJson(),
      ),
    },
    'summary': {
      'settingCount': settings?.length ?? 0,
      'keywordShieldCount': (shieldExport['keywords'] as List).length,
      'userShieldCount': (shieldExport['users'] as List).length,
      'followUserCount': follows?.length ?? 0,
      'followTagCount': tags?.length ?? 0,
      'historyCount': (histories ?? legacyHistories)?.length ?? 0,
    },
  };

  const encoder = JsonEncoder.withIndent('  ');
  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(encoder.convert(payload), encoding: utf8);
  await Hive.close();
  stdout.writeln(outFile.absolute.path);
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      continue;
    }
    final normalized = arg.substring(2);
    final equals = normalized.indexOf('=');
    if (equals >= 0) {
      result[normalized.substring(0, equals)] =
          normalized.substring(equals + 1);
      continue;
    }
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      result[normalized] = args[++i];
    } else {
      result[normalized] = 'true';
    }
  }
  return result;
}

Future<Box<T>?> _openOptionalBox<T>(Directory dir, String name) async {
  final fileName = '${name.toLowerCase()}.hive';
  if (!File(p.join(dir.path, fileName)).existsSync()) {
    return null;
  }
  try {
    return await Hive.openBox<T>(name);
  } catch (e) {
    stderr.writeln('Failed to open box $name: $e');
    return null;
  }
}

Map<String, dynamic> _exportBoxMap(Box<dynamic>? box) {
  if (box == null) {
    return {};
  }
  return {
    for (final entry in box.toMap().entries)
      entry.key.toString(): _safeJsonValue(entry.value),
  };
}

List<Map<String, dynamic>> _exportValues<T>(
  Box<T>? box,
  Map<String, dynamic> Function(T item) toJson,
) {
  if (box == null) {
    return [];
  }
  return box.values.map(toJson).toList();
}

Map<String, dynamic> _exportShieldBox(Box<String>? box) {
  final raw = box?.values.map((e) => e.toString()).toList() ?? const <String>[];
  final keywords = <String>{};
  final users = <String>{};
  final userGroups = <String, Set<String>>{};

  for (final item in raw) {
    final value = item.trim();
    if (value.isEmpty) {
      continue;
    }
    if (value.startsWith(_userShieldPrefix)) {
      final parsed = _parseUserShield(value);
      if (parsed != null) {
        users.add(parsed.user);
        userGroups
            .putIfAbsent(parsed.siteId, () => <String>{})
            .add(parsed.user);
      }
      continue;
    }
    if (value.startsWith(_keywordShieldPrefix)) {
      final keyword = value.substring(_keywordShieldPrefix.length).trim();
      if (keyword.isNotEmpty) {
        keywords.add(keyword);
      }
      continue;
    }
    keywords.add(value);
  }

  return {
    'raw': raw..sort(),
    'keywords': keywords.toList()..sort(),
    'users': users.toList()..sort(),
    'userGroups': {
      for (final entry in userGroups.entries)
        entry.key: entry.value.toList()..sort(),
    },
  };
}

_ParsedUserShield? _parseUserShield(String value) {
  final body = value.substring(_userShieldPrefix.length).trim();
  if (body.isEmpty) {
    return null;
  }
  final separator = body.indexOf(':');
  if (separator < 0) {
    return _ParsedUserShield(_globalUserShieldSiteId, body);
  }
  final siteId = body.substring(0, separator).trim();
  final user = body.substring(separator + 1).trim();
  if (user.isEmpty) {
    return null;
  }
  return _ParsedUserShield(
    siteId.isEmpty ? _globalUserShieldSiteId : siteId,
    user,
  );
}

List<Map<String, dynamic>> _exportShieldPresets(Box<String>? box) {
  if (box == null) {
    return [];
  }
  final result = <Map<String, dynamic>>[];
  for (final entry in box.toMap().entries) {
    final raw = entry.value.toString();
    dynamic parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      parsed = raw;
    }
    result.add({
      'name': entry.key.toString(),
      'value': _safeJsonValue(parsed),
    });
  }
  result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
  return result;
}

dynamic _safeJsonValue(dynamic value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Iterable) {
    return value.map(_safeJsonValue).toList();
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _safeJsonValue(entry.value),
    };
  }
  return value.toString();
}

class _ParsedUserShield {
  const _ParsedUserShield(this.siteId, this.user);

  final String siteId;
  final String user;
}

class LegacyFollowUser {
  const LegacyFollowUser({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.addTime,
    required this.tag,
  });

  final String id;
  final String roomId;
  final String siteId;
  final String userName;
  final String face;
  final DateTime addTime;
  final String tag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'addTime': addTime.toIso8601String(),
        'tag': tag,
      };
}

class LegacyHistory {
  const LegacyHistory({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.updateTime,
  });

  final String id;
  final String roomId;
  final String siteId;
  final String userName;
  final String face;
  final DateTime updateTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'updateTime': updateTime.toIso8601String(),
      };
}

class LegacyFollowUserTag {
  const LegacyFollowUserTag({
    required this.id,
    required this.tag,
    required this.userId,
  });

  final String id;
  final String tag;
  final List<String> userId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'userId': userId,
      };
}

class LegacyFollowUserAdapter extends TypeAdapter<LegacyFollowUser> {
  @override
  final int typeId = 1;

  @override
  LegacyFollowUser read(BinaryReader reader) {
    final fields = _readHiveFields(reader);
    return LegacyFollowUser(
      id: fields[0]?.toString() ?? '',
      roomId: fields[1]?.toString() ?? '',
      siteId: fields[2]?.toString() ?? '',
      userName: fields[3]?.toString() ?? '',
      face: fields[4]?.toString() ?? '',
      addTime: _asDateTime(fields[5]),
      tag: fields[6]?.toString() ?? '全部',
    );
  }

  @override
  void write(BinaryWriter writer, LegacyFollowUser obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.userName)
      ..writeByte(4)
      ..write(obj.face)
      ..writeByte(5)
      ..write(obj.addTime)
      ..writeByte(6)
      ..write(obj.tag);
  }
}

class LegacyHistoryAdapter extends TypeAdapter<LegacyHistory> {
  @override
  final int typeId = 2;

  @override
  LegacyHistory read(BinaryReader reader) {
    final fields = _readHiveFields(reader);
    return LegacyHistory(
      id: fields[0]?.toString() ?? '',
      roomId: fields[1]?.toString() ?? '',
      siteId: fields[2]?.toString() ?? '',
      userName: fields[3]?.toString() ?? '',
      face: fields[4]?.toString() ?? '',
      updateTime: _asDateTime(fields[5]),
    );
  }

  @override
  void write(BinaryWriter writer, LegacyHistory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.userName)
      ..writeByte(4)
      ..write(obj.face)
      ..writeByte(5)
      ..write(obj.updateTime);
  }
}

class LegacyFollowUserTagAdapter extends TypeAdapter<LegacyFollowUserTag> {
  @override
  final int typeId = 3;

  @override
  LegacyFollowUserTag read(BinaryReader reader) {
    final fields = _readHiveFields(reader);
    return LegacyFollowUserTag(
      id: fields[1]?.toString() ?? '',
      tag: fields[2]?.toString() ?? '',
      userId:
          (fields[3] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  @override
  void write(BinaryWriter writer, LegacyFollowUserTag obj) {
    writer
      ..writeByte(3)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.tag)
      ..writeByte(3)
      ..write(obj.userId);
  }
}

Map<int, dynamic> _readHiveFields(BinaryReader reader) {
  final fieldCount = reader.readByte();
  return {
    for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
  };
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
