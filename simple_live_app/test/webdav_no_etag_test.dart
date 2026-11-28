import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'webdav_merge_upload_test.dart' as fixture;

void main() {
  late HttpServer server;
  late DAVClient client;
  late Uint8List baseline;
  final files = <String, Uint8List>{};
  var weakEtag = false;
  var strongEtag = false;
  var reverseListing = false;
  var rootLast = false;
  final modified = <String, String>{};
  var listingStatus = 207;
  var uploadStatus = 201;
  var baseWrites = 0;
  var corruptUpload = false;
  final uploadHeaders = <String?>[];
  var slowSnapshots = false;
  var activeSnapshots = 0;
  var peakSnapshots = 0;

  setUp(() async {
    baseline = fixture.zip({
      fixture.follows: fixture.data([fixture.user('huya_1', '云端原有')])
    });
    files.clear();
    files['backup.zip'] = baseline;
    weakEtag = false;
    listingStatus = 207;
    uploadStatus = 201;
    baseWrites = 0;
    strongEtag = false;
    reverseListing = false;
    rootLast = false;
    modified.clear();
    corruptUpload = false;
    uploadHeaders.clear();
    slowSnapshots = false;
    activeSnapshots = 0;
    peakSnapshots = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final name = request.uri.pathSegments.where((s) => s.isNotEmpty).last;
      switch (request.method) {
        case 'OPTIONS':
          request.response.statusCode = 200;
        case 'MKCOL':
          request.response.statusCode = 405;
        case 'PROPFIND':
          request.response.statusCode = listingStatus;
          if (listingStatus == 207) {
            request.response.headers.contentType =
                ContentType('application', 'xml', charset: 'utf-8');
            final xml = '''<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">
              <d:response><d:href>/dav/simple_live_app/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
              ${(reverseListing ? files.entries.toList().reversed : files.entries).map((e) => '<d:response><d:href>/dav/simple_live_app/${e.key}</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>${e.value.length}</d:getcontentlength>${modified.containsKey(e.key) ? '<d:getlastmodified>${modified[e.key]}</d:getlastmodified>' : ''}</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>').join()}
              </d:multistatus>''';
            const self =
                '<d:response><d:href>/dav/simple_live_app/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
            request.response.write(rootLast
                ? xml
                    .replaceFirst(self, '')
                    .replaceFirst('</d:multistatus>', '$self</d:multistatus>')
                : xml);
          }
        case 'GET':
          if (slowSnapshots &&
              name.startsWith('backup-add-') &&
              name.endsWith('.zip')) {
            activeSnapshots++;
            if (activeSnapshots > peakSnapshots) {
              peakSnapshots = activeSnapshots;
            }
            // Different completion order must not change conflict precedence.
            final index = int.tryParse(name.substring(30, 31)) ?? 0;
            await Future<void>.delayed(
                Duration(milliseconds: 120 + (7 - index) * 5));
            activeSnapshots--;
          }
          final bytes = files[name];
          request.response.statusCode = bytes == null ? 404 : 200;
          if (weakEtag) request.response.headers.set('etag', 'W/"weak"');
          if (strongEtag) request.response.headers.set('etag', '"strong"');
          if (bytes != null) request.response.add(bytes);
        case 'PUT':
          if (name == 'backup.zip') baseWrites++;
          uploadHeaders.add(request.headers.value('if-none-match'));
          final bytes =
              await request.fold<List<int>>([], (a, b) => a..addAll(b));
          request.response.statusCode = uploadStatus;
          if (uploadStatus < 300) {
            files[name] = Uint8List.fromList(bytes);
            if (corruptUpload && name.endsWith('.zip')) files[name]![0] ^= 1;
          }
        default:
          request.response.statusCode = 405;
      }
      await request.response.close();
    });
    client = DAVClient('http://127.0.0.1:${server.port}/dav/', '', '');
    expect(await client.pingCompleter.future, isTrue);
  });
  tearDown(() async {
    client.client.c.close(force: true);
    await server.close(force: true);
  });

  void seedSnapshots() {
    for (var i = 0; i < 8; i++) {
      final name =
          'backup-add-2026110100000000000$i-11111111-1111-4111-8111-111111111111.zip';
      files[name] = fixture.zip({
        fixture.follows: fixture.data([fixture.user('huya_2', '顺序$i')])
      });
      files['$name.${sha256.convert(files[name]!)}.commit'] = Uint8List(0);
    }
  }

  for (final upload in [false, true]) {
    test('${upload ? "上传合并" : "下载"}有界并行读取增量，保持顺序和校验', () async {
      seedSnapshots();
      slowSnapshots = true;
      final watch = Stopwatch()..start();
      if (upload) {
        await client.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_3', '新上传')])
        }));
      } else {
        final result = Uint8List.fromList(await client.recovery());
        expect(fixture.rows(result, fixture.follows).last['userName'], '顺序0');
      }
      watch.stop();
      // ignore: avoid_print
      print('WebDAV ${upload ? "upload merge" : "download"}: '
          '${watch.elapsedMilliseconds} ms, peak=$peakSnapshots, 8 delayed snapshots');
      expect(peakSnapshots, inInclusiveRange(2, 4));
      if (upload) {
        slowSnapshots = false;
        final result = Uint8List.fromList(await client.recovery());
        expect(fixture.rows(result, fixture.follows).map((e) => e['id']),
            ['huya_1', 'huya_2', 'huya_3']);
        expect(fixture.rows(result, fixture.follows)[1]['userName'], '顺序0');
      }
    });
  }

  test('增量批次损坏时上传失败，不提交新备份', () async {
    seedSnapshots();
    slowSnapshots = true;
    final first = files.keys.firstWhere((key) => key.startsWith('backup-add-'));
    files[first]![0] ^= 1;
    await expectLater(
        client.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_3', '新增')])
        })),
        throwsStateError);
    expect(uploadHeaders, isEmpty);
    expect(baseWrites, 0);
    expect(files['backup.zip'], baseline);
  });

  for (final strong in [false, true]) {
    test('${strong ? "强" : "无"}ETag相同内容重复上传不再PUT或新增全量增量', () async {
      strongEtag = strong;
      final incoming = fixture.zip({
        fixture.follows: fixture.data([fixture.user('huya_2', '新增')])
      });
      await client.backup(incoming);
      final count = files.length;
      uploadHeaders.clear();
      baseWrites = 0;
      await client.backup(incoming);
      expect(uploadHeaders, isEmpty);
      expect(baseWrites, 0);
      expect(files.length, count);
      final result = Uint8List.fromList(await client.recovery());
      expect(fixture.rows(result, fixture.follows).map((e) => e['id']),
          ['huya_1', 'huya_2']);
    });
  }

  for (final weak in [false, true]) {
    test('${weak ? "弱" : "无"}ETag也能上传，旧备份不改，另一设备下载得到并集', () async {
      weakEtag = weak;
      final cloudUser = fixture.user('huya_1', '云端原有');
      await client.backup(fixture.zip({
        fixture.follows: fixture.data(
            [fixture.user('huya_1', '不可覆盖'), fixture.user('huya_2', '手机新增')])
      }));
      expect(baseWrites, 0);
      expect(files['backup.zip'], orderedEquals(baseline));
      expect(files.length, 3);
      expect(uploadHeaders, ['*', '*']);
      final other = DAVClient('http://127.0.0.1:${server.port}/dav/', '', '');
      try {
        final downloaded = await other.recovery();
        expect(fixture.rows(Uint8List.fromList(downloaded), fixture.follows),
            [cloudUser, fixture.user('huya_2', '手机新增')]);
      } finally {
        other.client.c.close(force: true);
      }
    });
  }

  test('两台设备无ETag并发上传不会互相覆盖新增关注', () async {
    final other = DAVClient('http://127.0.0.1:${server.port}/dav/', '', '');
    try {
      await Future.wait([
        client.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_2', '电脑')])
        })),
        other.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_3', '手机')])
        })),
      ]);
      expect(baseWrites, 0);
      expect(files.length, 5);
      final downloaded = Uint8List.fromList(await client.recovery());
      expect(fixture.rows(downloaded, fixture.follows).map((e) => e['id']),
          unorderedEquals(['huya_1', 'huya_2', 'huya_3']));
    } finally {
      other.client.c.close(force: true);
    }
  });

  test('上传失败或列目录失败不能显示成功，也不修改原备份', () async {
    listingStatus = 503;
    await expectLater(
        client.backup(fixture.zip({fixture.follows: fixture.data([])})),
        throwsA(anything));
    expect(files.length, 1);
    listingStatus = 207;
    uploadStatus = 507;
    await expectLater(
        client.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_2', '待上传')])
        })),
        throwsA(anything));
    expect(files['backup.zip'], orderedEquals(baseline));
    expect(files.length, 1);
  });

  test('没有主备份时仍能从增量备份恢复，忽略其他同目录文件', () async {
    const name =
        'backup-add-20261101000000000000-11111111-1111-4111-8111-111111111111.zip';
    files[name] = fixture.zip({
      fixture.follows: fixture.data([fixture.user('huya_4', '增量')])
    });
    files['$name.${sha256.convert(files[name]!)}.commit'] = Uint8List(0);
    files.remove('backup.zip');
    files['unrelated.zip'] = Uint8List.fromList(utf8.encode('not a backup'));
    final downloaded = Uint8List.fromList(await client.recovery());
    expect(fixture.rows(downloaded, fixture.follows).single['id'], 'huya_4');
  });
  test('未通过上传校验的半成品不阻塞重试，也不会作为成功数据下载', () async {
    corruptUpload = true;
    await expectLater(
        client.backup(fixture.zip({
          fixture.follows: fixture.data([fixture.user('huya_2', '失败上传')])
        })),
        throwsA(anything));
    expect(files.keys.any((name) => name.endsWith('.commit')), isFalse);
    corruptUpload = false;
    await client.backup(fixture.zip({
      fixture.follows: fixture.data([fixture.user('huya_3', '成功上传')])
    }));
    final recovered = Uint8List.fromList(await client.recovery());
    expect(fixture.rows(recovered, fixture.follows).map((e) => e['id']),
        ['huya_1', 'huya_3']);
    expect(files['backup.zip'], orderedEquals(baseline));
  });
  test('服务器恢复强ETag后上传仍保留之前增量中的关注字段', () async {
    final prior = fixture.user('huya_2', '已上传原值');
    await client.backup(fixture.zip({
      fixture.follows: fixture.data([prior])
    }));
    strongEtag = true;
    await client.backup(fixture.zip({
      fixture.follows: fixture
          .data([fixture.user('huya_2', '不可覆盖'), fixture.user('huya_3', '新增')])
    }));
    expect(baseWrites, 1);
    final recovered = Uint8List.fromList(await client.recovery());
    expect(
        fixture
            .rows(recovered, fixture.follows)
            .firstWhere((e) => e['id'] == 'huya_2'),
        prior);
  });
  test('目录顺序与部分缺失mtime不影响合并结果，空提交标记正常恢复', () async {
    for (var i = 0; i < 3; i++) {
      final name =
          'backup-add-2026110100000000000$i-11111111-1111-4111-8111-111111111111.zip';
      files[name] = fixture.zip({
        fixture.follows: fixture.data([fixture.user('huya_2', '顺序$i')])
      });
      final receipt = '$name.${sha256.convert(files[name]!)}.commit';
      files[receipt] = Uint8List(0);
      if (i != 1) modified[receipt] = 'Sun, 01 Nov 2026 19:0${9 - i}:00 GMT';
    }
    final first = fixture.rows(
        Uint8List.fromList(await client.recovery()), fixture.follows);
    reverseListing = true;
    rootLast = true;
    final second = fixture.rows(
        Uint8List.fromList(await client.recovery()), fixture.follows);
    expect(second, first);
    expect(first.last['userName'], '顺序0');
  });
}
