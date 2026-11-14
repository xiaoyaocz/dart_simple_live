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
    // 仅设置必要头。GET 请求不能携带 Content-Type：
    // Alist 等网关代理到 OSS 签名直链时会把该头透传，
    // 与直链签名不一致导致 SignatureDoesNotMatch（HTTP 403→500）。
    // PROPFIND 所需的 XML Content-Type 由 webdav_client 内部自行设置。
    client.setHeaders(
      {
        'accept-charset': 'utf-8',
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

  // 强制统一
  get root => "/simple_live_app";

  get backupFile => "$root/backup.zip";

  backup(Uint8List data) async {
    try {
      await client.mkdir("$root");
    } catch (_) {}
    await client.write("$backupFile", data);
    return true;
  }

  Future<List<int>> recovery() async {
    try {
      await client.mkdir("$root");
    } catch (_) {}
    final data = await client.read(backupFile);
    return data;
  }
}
