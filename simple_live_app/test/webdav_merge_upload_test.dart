import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';

Uint8List zip(Map<String, dynamic> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = entry.value is List<int>
        ? entry.value as List<int>
        : utf8.encode(jsonEncode(entry.value));
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, dynamic> data(List<dynamic> rows) => {'data': rows};
Map<String, dynamic> user(String id, String name, {String tag = '全部'}) => {
      'id': id,
      'roomId': id.split('_').last,
      'siteId': 'huya',
      'userName': name,
      'face': '',
      'addTime': '2026-01-01 00:00:00.000',
      'tag': tag,
      'note': '$name备注',
      'sort': 7,
    };
Map<String, dynamic> tag(String id, String name, List<String> ids) => {
      'id': id,
      'tag': name,
      'userId': ids,
    };
List<dynamic> rows(Uint8List bytes, String name) => jsonDecode(utf8
    .decode(ZipDecoder().decodeBytes(bytes).findFile(name)!.content))['data'];

const follows = 'SimpleLive_follows.json';
const tags = 'SimpleLive_Tags.json';

void main() {
  late HttpServer server;
  late DAVClient client;
  Uint8List? remote;
  var getStatus = 200;
  var version = 1;
  var puts = 0;
  var gets = 0;
  var conflictOnce = false;
  var omitEtag = false;
  var listingStatus = 207;
  Uint8List? concurrent;
  final conditions = <String?>[];

  setUp(() async {
    remote = null;
    getStatus = 200;
    version = 1;
    puts = 0;
    gets = 0;
    conflictOnce = false;
    omitEtag = false;
    listingStatus = 207;
    conditions.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      switch (request.method) {
        case 'OPTIONS':
          request.response.statusCode = 200;
        case 'MKCOL':
          request.response.statusCode = 405;
        case 'PROPFIND':
          request.response.statusCode = listingStatus;
          if (listingStatus == 207) {
            request.response.headers.contentType = ContentType('application', 'xml');
            request.response.write('<d:multistatus xmlns:d="DAV:"><d:response><d:href>/dav/simple_live_app/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>');
          }
        case 'GET':
          gets++;
          request.response.statusCode = getStatus != 200
              ? getStatus
              : remote == null
                  ? 404
                  : 200;
          if (request.response.statusCode == 200) {
            if (!omitEtag) request.response.headers.set('etag', '"v$version"');
            request.response.add(remote!);
          }
        case 'PUT':
          puts++;
          final bytes =
              await request.fold<List<int>>([], (a, b) => a..addAll(b));
          final match = request.headers.value('if-match');
          final none = request.headers.value('if-none-match');
          conditions.add(match ?? none);
          if (conflictOnce) {
            conflictOnce = false;
            remote = concurrent;
            version++;
            request.response.statusCode = 412;
          } else if ((match != null && match != '"v$version"') ||
              (none == '*' && remote != null)) {
            request.response.statusCode = 412;
          } else {
            remote = Uint8List.fromList(bytes);
            version++;
            request.response.statusCode = 204;
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

  test('上传保留云端关注的备注标签顺序及未知文件，只追加本机未关注项', () async {
    final cloud = user('huya_1', '云端', tag: '原标签');
    remote = zip({
      follows: data([cloud]),
      tags: data([
        tag('t1', '原标签', ['huya_1'])
      ]),
      'future.bin': <int>[0, 255, 7],
      'future.json': {'future': true}
    });
    await client.backup(zip({
      follows: data([user('huya_1', '本机'), user('huya_2', '新增')]),
      tags: data([])
    }));
    expect(rows(remote!, follows), [cloud, user('huya_2', '新增')]);
    expect(ZipDecoder().decodeBytes(remote!).findFile('future.bin')!.content,
        [0, 255, 7]);
    expect(
        ZipDecoder().decodeBytes(remote!).findFile('future.json'), isNotNull);
    expect(conditions, ['"v1"']);
  });

  test('上传保留其他云端数据并按ID和设置键补充，不覆盖已有内容', () async {
    remote = zip({
      follows: data([]),
      'SimpleLive_histories.json': data([
        {'id': 'h1', 'note': 'old'}
      ]),
      'SimpleLive_Settings.json': {
        'data': {'theme': 'dark'}
      },
      'SimpleLive_bilibili_account.json': {
        'data': {'cookie': 'cloud'}
      },
      'SimpleLive_blocked_word.json': data(['原词'])
    });
    await client.backup(zip({
      follows: data([]),
      'SimpleLive_histories.json': data([
        {'id': 'h1', 'note': 'new'},
        {'id': 'h2'}
      ]),
      'SimpleLive_Settings.json': {
        'data': {'theme': 'light', 'extra': 3}
      },
      'SimpleLive_bilibili_account.json': {
        'data': {'cookie': 'local'}
      },
      'SimpleLive_blocked_word.json': data(['原词', '新增'])
    }));
    expect(rows(remote!, 'SimpleLive_histories.json'), [
      {'id': 'h1', 'note': 'old'},
      {'id': 'h2'}
    ]);
    final archive = ZipDecoder().decodeBytes(remote!);
    dynamic object(String name) =>
        jsonDecode(utf8.decode(archive.findFile(name)!.content))['data'];
    expect(object('SimpleLive_Settings.json'), {'theme': 'dark', 'extra': 3});
    expect(object('SimpleLive_bilibili_account.json'), {'cookie': 'cloud'});
    expect(rows(remote!, 'SimpleLive_blocked_word.json'), ['原词', '新增']);
  });

  test('新增标签只引用新增关注，同名或同ID目的端标签不被改写', () async {
    final originalTag = tag('t1', '已有', ['huya_1']);
    remote = zip({
      follows: data([user('huya_1', '原用户')]),
      tags: data([originalTag])
    });
    await client.backup(zip({
      follows: data([user('huya_1', '覆盖'), user('huya_2', '新用户', tag: '新标签')]),
      tags: data([
        tag('t1', '改名', ['huya_2']),
        tag('other-id', '已有', ['huya_2']),
        tag('t2', '新标签', ['huya_1', 'huya_2', 'not-present'])
      ])
    }));
    expect(rows(remote!, tags), [
      originalTag,
      tag('t2', '新标签', ['huya_2'])
    ]);
  });

  test('已有同名分组只向末尾补充新关注，不改原成员次序和扩展字段', () async {
    final first = user('huya_1', '保留', tag: '分组');
    remote = zip({
      follows: data([first, user('huya_2', '第二')]),
      tags: data([
        {
          ...tag('cloud-tag', '分组', ['huya_2', 'huya_1']),
          'note': '保留备注'
        }
      ])
    });
    await client.backup(zip({
      follows: data(
          [user('huya_1', '不能覆盖', tag: '别组'), user('huya_3', '新增', tag: '分组')]),
      tags: data([
        tag('phone-tag', '分组', ['huya_1', 'huya_3'])
      ])
    }));
    expect(rows(remote!, follows).first, first);
    expect(rows(remote!, tags), [
      {
        ...tag('cloud-tag', '分组', ['huya_2', 'huya_1', 'huya_3']),
        'note': '保留备注'
      }
    ]);
  });

  test('同ID标签在来源设备被重命名时仅新增关注映射目的标签名，不产生悬空标签', () async {
    final original = user('huya_1', '保留', tag: '云端组名');
    remote = zip({
      follows: data([original]),
      tags: data([
        {
          ...tag('shared-tag', '云端组名', ['huya_1']),
          'note': '保留'
        }
      ])
    });
    final incoming = zip({
      follows: data([
        user('huya_1', '不能覆盖', tag: '手机组名'),
        user('huya_2', '新增', tag: '手机组名')
      ]),
      tags: data([
        tag('shared-tag', '手机组名', ['huya_1', 'huya_2'])
      ])
    });
    await client.backup(incoming);
    expect(
        rows(remote!, follows), [original, user('huya_2', '新增', tag: '云端组名')]);
    expect(rows(remote!, tags), [
      {
        ...tag('shared-tag', '云端组名', ['huya_1', 'huya_2']),
        'note': '保留'
      }
    ]);
    await client.backup(incoming);
    expect(rows(remote!, follows).length, 2);
    expect(rows(remote!, tags).single['userId'], ['huya_1', 'huya_2']);
  });

  for (final status in [401, 403, 500]) {
    test('读取云端HTTP $status时终止，不当作首次备份覆盖', () async {
      remote = zip({
        follows: data([user('huya_1', '保留')])
      });
      final before = remote;
      getStatus = status;
      await expectLater(
          client.backup(zip({follows: data([])})), throwsA(anything));
      expect(puts, 0);
      expect(remote, before);
    });
  }

  test('损坏的云端ZIP终止上传', () async {
    remote = Uint8List.fromList([1, 2, 3]);
    await expectLater(
        client.backup(zip({follows: data([])})), throwsA(anything));
    expect(puts, 0);
  });

  test('ZIP中CRC不匹配也终止上传，不能重打包后掩盖云端损坏', () async {
    remote = zip({
      follows: data([user('huya_1', '保留')])
    });
    // Corrupt only checksum metadata; JSON remains perfectly readable.
    remote![14] ^= 1;
    for (var i = 0; i < remote!.length - 20; i++) {
      if (remote![i] == 0x50 &&
          remote![i + 1] == 0x4b &&
          remote![i + 2] == 0x01 &&
          remote![i + 3] == 0x02) {
        remote![i + 16] ^= 1;
        break;
      }
    }
    await expectLater(
        client.backup(zip({follows: data([])})), throwsA(anything));
    expect(puts, 0);
  });

  test('损坏的已知JSON终止上传而不丢失云端数据', () async {
    remote = zip({
      follows: {'data': 'bad'}
    });
    await expectLater(
        client.backup(zip({follows: data([])})), throwsA(anything));
    expect(puts, 0);
  });

  test('仅404触发首次备份，使用If-None-Match防止并发创建覆盖', () async {
    await client.backup(zip({
      follows: data([user('huya_2', '新增')])
    }));
    expect(gets, 1);
    expect(conditions, ['*']);
    expect(rows(remote!, follows), [user('huya_2', '新增')]);
  });

  test('ETag冲突重新读取合并，保留另一个设备刚上传的关注', () async {
    remote = zip({
      follows: data([user('huya_1', '云端')])
    });
    concurrent = zip({
      follows: data([user('huya_1', '云端'), user('huya_3', '手机')])
    });
    conflictOnce = true;
    await client.backup(zip({
      follows: data([user('huya_2', '电脑')])
    }));
    expect(rows(remote!, follows).map((e) => e['id']),
        ['huya_1', 'huya_3', 'huya_2']);
    expect(gets, 2);
    expect(conditions, ['"v1"', '"v2"']);
  });

  test('无ETag且目录读取失败时不能回退为无条件覆盖主备份', () async {
    remote = zip({
      follows: data([user('huya_1', '原有')])
    });
    omitEtag = true;
    listingStatus = 503;
    await expectLater(
        client.backup(zip({follows: data([])})), throwsA(anything));
    expect(puts, 0);
  });
}
