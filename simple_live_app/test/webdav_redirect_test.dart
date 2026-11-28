import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'webdav_merge_upload_test.dart' as fixture;

void main() {
  late HttpServer origin;
  late HttpServer other;
  late DAVClient dav;
  late Uint8List bytes;
  var redirectStatus = 307;
  var target = 'object.zip';
  var objectStatus = 200;
  var getCount = 0;
  String? challenge;
  var challengeEveryGet = false;
  final seen = <String, List<String?>>{};

  Future<void> serve(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
    } else if (request.method == 'PROPFIND') {
      request.response.statusCode = 207;
      request.response.write('<d:multistatus xmlns:d="DAV:"/>');
    } else if (request.method == 'GET') {
      getCount++;
      seen[request.uri.path] = [
        request.headers.value('authorization'),
        request.headers.value('cookie')
      ];
      if (challenge != null &&
          request.connectionInfo!.localPort == origin.port &&
          (challengeEveryGet ||
              request.headers.value('authorization') == null)) {
        request.response.statusCode = 401;
        request.response.headers.set('www-authenticate', challenge!);
      } else if (request.uri.path.endsWith('backup.zip') ||
          request.uri.path.contains('/loop')) {
        request.response.statusCode = redirectStatus;
        request.response.headers
            .set('location', target == 'chain' ? '/loop$getCount' : target);
      } else {
        request.response.statusCode = objectStatus;
        if (objectStatus == 200) request.response.add(bytes);
      }
    }
    await request.response.close();
  }

  setUp(() async {
    bytes = fixture.zip({
      fixture.follows: fixture.data([fixture.user('huya_1', 'cloud')])
    });
    redirectStatus = 307;
    target = 'object.zip';
    objectStatus = 200;
    getCount = 0;
    challenge = null;
    challengeEveryGet = false;
    seen.clear();
    origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen(serve);
    other.listen(serve);
    dav = DAVClient('http://127.0.0.1:${origin.port}/dav/', '', '');
    await dav.pingCompleter.future;
    dav.client.c.options.headers
        .addAll({'Authorization': 'Bearer local-token', 'Cookie': 'sid=local'});
  });
  tearDown(() async {
    dav.client.c.close(force: true);
    await origin.close(force: true);
    await other.close(force: true);
  });

  for (final status in [301, 302, 303, 307, 308]) {
    test(
        'GET $status resolves relative Location and retains same-origin credentials',
        () async {
      redirectStatus = status;
      final result = Uint8List.fromList(await dav.recovery());
      expect(fixture.rows(result, fixture.follows).single['id'], 'huya_1');
      expect(seen['/dav/simple_live_app/object.zip'],
          ['Bearer local-token', 'sid=local']);
    });
  }
  for (final status in [302, 307]) {
    test('cross-origin $status strips Authorization and Cookie', () async {
      redirectStatus = status;
      target = 'http://127.0.0.1:${other.port}/object.zip';
      await dav.recovery();
      expect(seen['/object.zip'], [null, null]);
      expect(seen['/dav/simple_live_app/backup.zip'],
          ['Bearer local-token', 'sid=local']);
    });
  }
  test('GET negotiates Basic auth and retains it only on same origin',
      () async {
    dav.client.c.options.headers.clear();
    dav.client.auth = const webdav.Auth(user: 'alice', pwd: 'password');
    challenge = 'Basic realm="fixture"';
    await dav.recovery();
    expect(seen['/dav/simple_live_app/object.zip']!.first,
        'Basic YWxpY2U6cGFzc3dvcmQ=');
    target = 'http://127.0.0.1:${other.port}/object.zip';
    await dav.recovery();
    expect(seen['/object.zip'], [null, null]);
  });
  test('GET Digest authorization uses redirected resource path', () async {
    dav.client.c.options.headers.clear();
    dav.client.auth = const webdav.Auth(user: 'alice', pwd: 'password');
    challenge = 'Digest realm="fixture", nonce="nonce", qop="auth"';
    await dav.recovery();
    expect(seen['/dav/simple_live_app/object.zip']!.first,
        contains('uri="/dav/simple_live_app/object.zip"'));
  });
  test('repeated stale Digest challenges are bounded', () async {
    dav.client.c.options.headers.clear();
    dav.client.auth = const webdav.Auth(user: 'alice', pwd: 'password');
    challenge = 'Digest realm="fixture", nonce="nonce", qop="auth", stale=true';
    challengeEveryGet = true;
    await expectLater(dav.recovery(), throwsA(anything));
    expect(getCount, 3);
  });
  test('missing Location is an error', () async {
    target = '';
    await expectLater(
        dav.recovery(),
        throwsA(isA<StateError>()
            .having((e) => '$e', 'message', contains('Location'))));
  });
  test('cross-origin 401 does not negotiate DAV credentials', () async {
    target = 'http://127.0.0.1:${other.port}/object.zip';
    objectStatus = 401;
    await expectLater(dav.recovery(), throwsA(anything));
    expect(seen['/object.zip'], [null, null]);
  });
  test('redirect loop aborts before fetching an already visited URL', () async {
    target = 'backup.zip';
    await expectLater(
        dav.recovery(),
        throwsA(
            isA<StateError>().having((e) => '$e', 'message', contains('循环'))));
    expect(getCount, 1);
  });
  test('unbounded redirect chain is capped', () async {
    target = 'chain';
    await expectLater(
        dav.recovery(),
        throwsA(
            isA<StateError>().having((e) => '$e', 'message', contains('重定向'))));
    expect(getCount, lessThanOrEqualTo(6));
  });
  test('redirected HTTP 503 aborts, not an empty cloud snapshot', () async {
    objectStatus = 503;
    await expectLater(dav.recovery(), throwsA(anything));
  });
  test('redirected 404 preserves absent backup semantics', () async {
    objectStatus = 404;
    await expectLater(
        dav.recovery(),
        throwsA(isA<StateError>()
            .having((e) => '$e', 'message', contains('还没有备份'))));
  });
}
