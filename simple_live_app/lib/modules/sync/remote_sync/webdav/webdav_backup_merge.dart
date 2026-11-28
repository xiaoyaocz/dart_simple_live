import 'dart:convert';

import 'package:archive/archive.dart';

const webDavFollowsFile = 'SimpleLive_follows.json';
const webDavTagsFile = 'SimpleLive_Tags.json';
const _historiesFile = 'SimpleLive_histories.json';
const _blockedFile = 'SimpleLive_blocked_word.json';
const _settingsFile = 'SimpleLive_Settings.json';
const _accountFile = 'SimpleLive_bilibili_account.json';

Archive decodeWebDavBackup(List<int> bytes) {
  // ZipDecoder accepts some truncated/non-ZIP input as an empty archive.
  if (bytes.length < 22 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
    throw const FormatException('备份不是有效的ZIP文件');
  }
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  // archive 4.x currently ignores verify; check every entry before merging,
  // including unknown files, so re-encoding cannot conceal damaged cloud data.
  for (final file in archive) {
    if (file.isFile && getCrc32(file.content) != file.crc32) {
      throw FormatException('备份文件CRC校验失败：${file.name}');
    }
  }
  if (archive.findFile(webDavFollowsFile) == null) {
    throw const FormatException('备份中缺少关注列表');
  }
  return archive;
}

Map<String, dynamic> _document(ArchiveFile file) {
  if (!file.isFile) throw FormatException('${file.name}不是文件');
  final value = jsonDecode(utf8.decode(file.content));
  if (value is! Map<String, dynamic> || !value.containsKey('data')) {
    throw FormatException('${file.name}缺少data字段');
  }
  return value;
}

List<Map<String, dynamic>> _records(dynamic data, String name) {
  if (data is! List) throw FormatException('$name列表格式错误');
  final result = <Map<String, dynamic>>[];
  for (final row in data) {
    if (row is! Map<String, dynamic> ||
        row['id'] is! String ||
        (row['id'] as String).isEmpty) {
      throw FormatException('$name条目缺少有效ID');
    }
    if (name == webDavFollowsFile) {
      for (final key in ['roomId', 'siteId', 'userName', 'face', 'addTime']) {
        if (row[key] is! String) throw FormatException('关注条目$key格式错误');
      }
      if (DateTime.tryParse(row['addTime']) == null ||
          (row['tag'] != null && row['tag'] is! String) ||
          (row['categoryName'] != null && row['categoryName'] is! String)) {
        throw const FormatException('关注条目时间或标签格式错误');
      }
    } else if (name == webDavTagsFile) {
      if (row['tag'] is! String ||
          row['userId'] is! List ||
          (row['userId'] as List).any((id) => id is! String)) {
        throw const FormatException('关注标签格式错误');
      }
    }
    result.add(Map<String, dynamic>.from(row));
  }
  return result;
}

dynamic _validate(String name, dynamic data) {
  switch (name) {
    case webDavFollowsFile:
    case webDavTagsFile:
    case _historiesFile:
      return _records(data, name);
    case _blockedFile:
      if (data is! List || data.any((word) => word is! String)) {
        throw const FormatException('屏蔽词列表格式错误');
      }
      return List<String>.from(data);
    case _settingsFile:
    case _accountFile:
      if (data is! Map<String, dynamic>) {
        throw FormatException('$name数据格式错误');
      }
      return Map<String, dynamic>.from(data);
    default:
      return data;
  }
}

/// Destination wins every conflict; append only absent records, in input order.
/// Used in both directions: cloud is destination on upload, local on download.
/// O(total ZIP bytes + records); ZIP decoding/encoding is the memory bottleneck.
Archive mergeWebDavBackups(Archive destination, Archive incoming) {
  const known = {
    webDavFollowsFile,
    webDavTagsFile,
    _historiesFile,
    _blockedFile,
    _settingsFile,
    _accountFile
  };
  final documents = <String, Map<String, dynamic>>{};
  final source = <String, Map<String, dynamic>>{};
  for (final (archive, target) in [
    (destination, documents),
    (incoming, source)
  ]) {
    for (final file in archive) {
      if (!known.contains(file.name)) continue;
      final document = _document(file);
      target[file.name] = {
        ...document,
        'data': _validate(file.name, document['data'])
      };
    }
  }

  final oldFollows = List<Map<String, dynamic>>.from(
      documents[webDavFollowsFile]?['data'] ?? []);
  final followIds = oldFollows.map((row) => row['id'] as String).toSet();
  final addedFollows = <String, Map<String, dynamic>>{};
  for (final row in (source[webDavFollowsFile]?['data'] ?? []) as List) {
    if (followIds.add(row['id'])) {
      oldFollows.add(row);
      addedFollows[row['id']] = row;
    }
  }
  if (documents.containsKey(webDavFollowsFile) ||
      source.containsKey(webDavFollowsFile)) {
    documents[webDavFollowsFile] = {
      ...?source[webDavFollowsFile],
      ...?documents[webDavFollowsFile],
      'data': oldFollows,
    };
  }

  final mergedTags =
      List<Map<String, dynamic>>.from(documents[webDavTagsFile]?['data'] ?? []);
  final byId = {for (final row in mergedTags) row['id']: row};
  final byName = {for (final row in mergedTags) row['tag']: row};
  for (final row in (source[webDavTagsFile]?['data'] ?? []) as List) {
    final members = (row['userId'] as List)
        .where((id) =>
            addedFollows.containsKey(id) &&
            addedFollows[id]!['tag'] == row['tag'])
        .toList();
    if (members.isEmpty) continue;
    final existing = byId[row['id']] ?? byName[row['tag']];
    if (existing != null) {
      // A shared tag may have been renamed on only one device. Keep the
      // destination name and map only NEW follows, preventing dangling groups.
      for (final id in members) {
        addedFollows[id]!['tag'] = existing['tag'];
      }
      // Never import membership of an already-followed user, or reorder members.
      existing['userId'] = [
        ...existing['userId'] as List,
        ...members
            .where((id) => !(existing['userId'] as List).contains(id))
            .toSet()
      ];
    } else if (!byId.containsKey(row['id'])) {
      final added = Map<String, dynamic>.from(row)
        ..['userId'] = members.toSet().toList();
      mergedTags.add(added);
      byId[row['id']] = added;
      byName[row['tag']] = added;
    }
  }
  if (documents.containsKey(webDavTagsFile) ||
      source.containsKey(webDavTagsFile)) {
    documents[webDavTagsFile] = {
      ...?source[webDavTagsFile],
      ...?documents[webDavTagsFile],
      'data': mergedTags,
    };
  }

  for (final name in known.difference({webDavFollowsFile, webDavTagsFile})) {
    final from = source[name];
    final to = documents[name];
    if (from == null) continue;
    if (to == null) {
      documents[name] = from;
    } else if (name == _historiesFile) {
      final rows = to['data'] as List;
      final ids = rows.map((row) => row['id']).toSet();
      to['data'] = [
        ...rows,
        ...(from['data'] as List).where((row) => ids.add(row['id']))
      ];
    } else if (name == _blockedFile) {
      to['data'] = {...to['data'] as List, ...from['data'] as List}.toList();
    } else {
      to['data'] = {...from['data'] as Map, ...to['data'] as Map};
    }
  }

  final merged = Archive();
  // Reuse untouched entries including future-version files; never extract paths.
  for (final file in destination) {
    if (!known.contains(file.name)) merged.addFile(file);
  }
  for (final file in incoming) {
    if (!known.contains(file.name) && merged.findFile(file.name) == null) {
      merged.addFile(file);
    }
  }
  for (final entry in documents.entries) {
    final bytes = utf8.encode(jsonEncode(entry.value));
    merged.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return merged;
}
