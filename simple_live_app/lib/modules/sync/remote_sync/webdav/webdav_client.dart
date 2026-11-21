import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart';
// v1.2.2 readDir assumes the collection is the FIRST response. DAV does not.
// Reuse its existing parser with that assumption disabled.
// ignore: implementation_imports
import 'package:webdav_client/src/xml.dart' show WebdavXml, fileXmlStr;
import 'webdav_backup_merge.dart';

class DAVClient {
  late Client client;
  Completer<bool> pingCompleter = Completer();

  DAVClient(
    String webDAVUri,
    String webDAVUser,
    String webDAVPassword,
  ) {
    client = newClient(
      webDAVUri,
      user: webDAVUser,
      password: webDAVPassword,
    );
    client.setHeaders(
      {
        'accept-charset': 'utf-8',
        'Content-Type': 'text/xml',
      },
    );
    client.setConnectTimeout(8000);
    client.setSendTimeout(8000);
    client.setReceiveTimeout(8000);
    pingCompleter.complete(_ping());
  }

  Future<bool> _ping() async {
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  // 强制统一
  String get root => "/simple_live_app";

  String get backupFile => "$root/backup.zip";

  Future<bool> backup(Uint8List data) async {
    final local = decodeWebDavBackup(data);
    // Validate the snapshot before any request, even for a first upload.
    mergeWebDavBackups(Archive(), local);
    for (var attempt = 0; attempt < 3; attempt++) {
      final response = await _readBackup();
      final absent = response.statusCode == 404;
      final etag = response.headers.value('etag');
      final cloud = await _mergeIncrementals(
          absent ? Archive() : decodeWebDavBackup(response.data!));
      final merged = mergeWebDavBackups(cloud, local);
      // Compare decoded entries, not ZIP metadata/compression timestamps. Only
      // skip after every committed contribution has been fetched and verified.
      // In particular, do not create another full snapshot on no-ETag servers
      // when this device has nothing new to contribute.
      if (!absent && _sameBackupContents(cloud, merged)) return true;
      if (!absent &&
          (etag == null || !etag.startsWith('"') || !etag.endsWith('"'))) {
        // Many WebDAV services omit GET ETags or expose only weak validators.
        // Do NOT turn that into either a hard failure or an unconditional PUT
        // of backup.zip. Independent, immutable contributions need no server
        // compare-and-swap and two devices cannot overwrite one another.
        // Store the merged snapshot, not conflicting local records. Even if a
        // device clock is behind, reading its snapshot first retains all cloud
        // values the device had already observed before it uploaded.
        await _uploadIncremental(
            Uint8List.fromList(ZipEncoder().encode(merged)));
        return true;
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(merged));
      if (absent) await client.mkdir(root);
      final result = await client.c.req(
        client, 'PUT', backupFile,
        // A replayable byte body also survives a digest-auth challenge.
        data: bytes,
        optionsHandler: (options) {
          options.headers?['content-type'] = 'application/zip';
          options.headers?['content-length'] = bytes.length;
          options.headers?[absent ? 'If-None-Match' : 'If-Match'] =
              absent ? '*' : etag;
        },
      );
      if ([200, 201, 204].contains(result.statusCode)) return true;
      if (result.statusCode == 412) continue;
      throw StateError('上传备份失败（HTTP ${result.statusCode}）');
    }
    throw StateError('云端备份被其他设备更新，请稍后重试；没有覆盖云端数据');
  }

  Future<List<int>> recovery() async {
    final response = await _readBackup();
    final baseline = response.statusCode == 404
        ? Archive()
        : decodeWebDavBackup(response.data!);
    final combined = await _mergeIncrementals(baseline);
    if (combined.findFile(webDavFollowsFile) == null) {
      throw StateError('云端还没有备份');
    }
    return ZipEncoder().encode(combined);
  }

  static final _incrementalReceipt = RegExp(
      r'^(backup-add-\d{20}-[0-9a-f-]{36}\.zip)\.([0-9a-f]{64})\.commit$');

  bool _sameBackupContents(Archive first, Archive second) {
    if (first.length != second.length) return false;
    for (final file in first) {
      final other = second.findFile(file.name);
      if (other == null ||
          file.isFile != other.isFile ||
          !const ListEquality<int>().equals(file.content, other.content)) {
        return false;
      }
    }
    return true;
  }

  Future<Archive> _mergeIncrementals(Archive baseline) async {
    List<File> entries;
    try {
      final response =
          await client.c.wdPropfind(client, '$root/', true, fileXmlStr);
      entries = WebdavXml.toFiles('$root/', response.data, skipSelf: false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 && baseline.isEmpty) {
        return baseline;
      }
      rethrow;
    }
    // A receipt is published only AFTER the immutable ZIP was read back and
    // verified. Failed/partial uploads have no receipt and cannot poison sync.
    final snapshots = entries.where((entry) {
      final name = entry.name ?? '';
      return entry.isDir != true && _incrementalReceipt.hasMatch(name);
    }).toList()
      // One immutable sort key; mixed/missing WebDAV mTime cannot create a
      // non-transitive comparator and different devices see the same order.
      ..sort((a, b) => a.name!.compareTo(b.name!));
    var merged = baseline;
    // Bound downloads to four ZIPs per batch instead of serial network RTTs.
    // Future.wait preserves input order, not completion order; conflicts must
    // still be resolved using the immutable sorted receipt names.
    // Keep contributions: deleting/compacting them without server CAS would
    // reintroduce the same lost-update problem on no-ETag servers.
    const concurrency = 4;
    for (var start = 0; start < snapshots.length; start += concurrency) {
      final batch = snapshots.skip(start).take(concurrency);
      final archives = await Future.wait(batch.map((snapshot) async {
        final match = _incrementalReceipt.firstMatch(snapshot.name!)!;
        final response = await _readFile('$root/${match.group(1)}');
        if (response.statusCode != 200 ||
            sha256.convert(response.data!).toString() != match.group(2)) {
          throw StateError('云端增量备份发生变化，请重试：${snapshot.name}');
        }
        return decodeWebDavBackup(response.data!);
      }));
      for (final archive in archives) {
        merged = mergeWebDavBackups(merged, archive);
      }
    }
    return merged;
  }

  Future<void> _uploadIncremental(Uint8List data) async {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'\D'), '')
        .padRight(20, '0');
    final path = '$root/backup-add-$timestamp-${const Uuid().v4()}.zip';
    final result = await client.c.req(client, 'PUT', path, data: data,
        optionsHandler: (options) {
      options.headers?['content-type'] = 'application/zip';
      options.headers?['content-length'] = data.length;
      options.headers?['If-None-Match'] = '*';
    });
    if (![200, 201, 204].contains(result.statusCode)) {
      throw StateError('上传增量备份失败（HTTP ${result.statusCode}）');
    }
    final verified = await _readFile(path);
    if (verified.statusCode != 200 ||
        sha256.convert(verified.data!).toString() !=
            sha256.convert(data).toString()) {
      throw StateError('增量备份上传校验失败，请重试');
    }
    final digest = sha256.convert(data).toString();
    // The digest is part of the immutable resource NAME, not parsed from the
    // marker body. Truncation/stripping of its body cannot poison future sync.
    // Use one byte for services that do not accept zero-length uploads.
    final receiptPath = '$path.$digest.commit';
    final committed = await client.c.req(client, 'PUT', receiptPath,
        data: Uint8List.fromList([49]), optionsHandler: (options) {
      options.headers?['content-type'] = 'text/plain';
      options.headers?['content-length'] = 1;
      options.headers?['If-None-Match'] = '*';
    });
    if (![200, 201, 204].contains(committed.statusCode)) {
      throw StateError('确认增量备份失败（HTTP ${committed.statusCode}）');
    }
    final confirmation = await _readFile(receiptPath);
    if (confirmation.statusCode != 200) {
      throw StateError('增量备份确认校验失败，请重试');
    }
  }

  Future<Response<List<int>>> _readBackup() async {
    return _readFile(backupFile);
  }

  Future<Response<List<int>>> _readFile(String path) async {
    // req() recursively follows 302 without a bound or origin check. Use its
    // transport directly and handle GET redirects/auth challenges explicitly.
    var uri = Uri.parse('${client.uri.replaceFirst(RegExp(r'/+$'), '')}/'
        '${path.replaceFirst(RegExp(r'^/+'), '')}');
    final visited = <Uri>{};
    var credentialsAllowed = true;
    Dio? anonymous;
    try {
      for (var redirects = 0;; redirects++) {
        uri = uri.removeFragment();
        if (!visited.add(uri)) throw StateError('读取云端备份失败：重定向循环');
        if (uri.scheme != 'http' && uri.scheme != 'https' ||
            !uri.hasAuthority ||
            uri.userInfo.isNotEmpty) {
          throw StateError('读取云端备份失败：无效的重定向地址');
        }
        final headers = Map<String, dynamic>.from(client.c.options.headers);
        if (!credentialsAllowed) {
          headers.removeWhere((key, _) => const {
                'authorization',
                'cookie',
                'proxy-authorization',
                'host'
              }.contains(key.toLowerCase()));
          // Separate transport: inherited interceptors/cookies/auth defaults
          // must not reintroduce credentials on an external object store.
          anonymous ??= Dio(BaseOptions(
            connectTimeout: client.c.options.connectTimeout,
            sendTimeout: client.c.options.sendTimeout,
            receiveTimeout: client.c.options.receiveTimeout,
          ));
        }
        headers['cache-control'] = 'no-cache';
        final transport = credentialsAllowed ? client.c : anonymous!;
        late Response<List<int>> response;
        for (var challenge = 0;; challenge++) {
          final resource = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
          final authorization = credentialsAllowed
              ? client.auth.authorize('GET', resource)
              : null;
          if (authorization != null) {
            headers
                .removeWhere((key, _) => key.toLowerCase() == 'authorization');
            headers['authorization'] = authorization;
          }
          response = await transport.requestUri<List<int>>(uri,
              options: Options(
                  method: 'GET',
                  responseType: ResponseType.bytes,
                  followRedirects: false,
                  validateStatus: (_) => true,
                  headers: headers));
          if (response.statusCode != 401 ||
              !credentialsAllowed ||
              challenge >= 2) {
            break;
          }
          final authenticate = response.headers.value('www-authenticate');
          final lower = authenticate?.toLowerCase() ?? '';
          final auth = client.auth;
          if ((auth.type == AuthType.NoAuth || lower.contains('stale=true')) &&
              lower.startsWith('digest ')) {
            client.auth = DigestAuth(
                user: auth.user,
                pwd: auth.pwd,
                dParts: DigestParts(authenticate));
          } else if (auth.type == AuthType.NoAuth &&
              lower.startsWith('basic ')) {
            client.auth = BasicAuth(user: auth.user, pwd: auth.pwd);
          } else {
            break;
          }
        }
        if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
          if (redirects >= 5) throw StateError('读取云端备份失败：重定向次数过多');
          final location = response.headers.value('location');
          if (location == null || location.trim().isEmpty) {
            throw StateError('读取云端备份失败：重定向缺少Location');
          }
          final next = uri.resolve(location);
          if (uri.origin != next.origin) credentialsAllowed = false;
          uri = next;
          continue;
        }
        // Only an actual GET 404 means absent. Never swallow HTTP failures.
        if (response.statusCode != 200 && response.statusCode != 404) {
          throw StateError('读取云端备份失败（HTTP ${response.statusCode}）');
        }
        return response;
      }
    } finally {
      anonymous?.close(force: true);
    }
  }
}
