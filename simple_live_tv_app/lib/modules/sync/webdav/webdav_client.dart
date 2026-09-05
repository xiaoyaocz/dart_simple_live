import 'dart:async';
import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart';

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
    client.setConnectTimeout(15000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
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

  get root => "/simple_live_app";

  get backupFile => "$root/backup.zip";

  Future<bool> backup(Uint8List data) async {
    try {
      await client.mkdir(root);
    } catch (_) {}
    await client.write(backupFile, data);
    return true;
  }
}
