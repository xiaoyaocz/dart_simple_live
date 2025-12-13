import 'dart:async';
import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart';

class DAVClient {
  late Client client;
  Completer<bool> pingCompleter = Completer();
  // 强制统一
  String root = "/simple_live_app";

  DAVClient(String webDAVUri, String webDAVUser, String webDAVPassword,
      {String webDAVDirectory = "/simple_live_app"}) {
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
    root = webDAVDirectory;
  }

  Future<bool> _ping() async {
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get backupFile => "$root/backup.zip";

  Future<bool> backup(Uint8List data) async {
    await client.mkdir(root);
    await client.write(backupFile, data);
    return true;
  }

  Future<List<int>> recovery() async {
    await client.mkdir(root);
    final data = await client.read(backupFile);
    return data;
  }
}
