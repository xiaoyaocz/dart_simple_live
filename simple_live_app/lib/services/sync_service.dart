import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/remote_sync_connection.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';
import 'package:udp/udp.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SyncService extends GetxService {
  static SyncService get instance => Get.find<SyncService>();

  UDP? udp;
  RxList<SyncClinet> scanClients = <SyncClinet>[].obs;
  static const int udpPort = 23235;
  static const int httpPort = 23234;
  static const List<int> fallbackHttpPorts = [
    23234,
    23236,
    23237,
    23238,
    23239,
    23240,
    23241,
    23242,
    23243,
    23244,
  ];
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  NetworkInfo networkInfo = NetworkInfo();
  HttpServer? server;
  var ipAddress = "".obs;
  var serverPort = httpPort.obs;
  var httpRunning = false.obs;
  var httpErrorMsg = "".obs;

  var deviceId = "";

  /// 供扫码和远程中转使用的本机地址列表；非默认端口时附带端口号。
  String get qrAddress {
    final ips = ipAddress.value
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ips.isEmpty) return '';
    if (serverPort.value == httpPort) return ips.join(';');
    return ips.map((ip) => '$ip:${serverPort.value}').join(';');
  }

  @override
  void onInit() {
    Log.d('TVService init');
    deviceId = (const Uuid().v4()).split('-').first;
    listenUDP();
    initServer();
    super.onInit();
  }

  /// 监听其他端UDP广播的回复
  void listenUDP() async {
    try {
      udp = await UDP.bind(Endpoint.any(port: const Port(udpPort)));
    } catch (e) {
      Log.d('UDP 默认端口 $udpPort 被占用，回退随机端口以保留主动发现能力：$e');
      try {
        udp = await UDP.bind(Endpoint.any());
      } catch (fallbackError) {
        Log.logPrint(fallbackError);
        return;
      }
    }
    udp?.asStream().listen(listenUdp, onError: (Object e) {
      Log.d('UDP 监听异常：$e');
    });
  }

  void listenUdp(Datagram? datagram) {
    if (datagram == null) return;
    try {
      var str = utf8.decode(datagram.data, allowMalformed: true);
      Log.i("Received: $str from ${datagram.address}:${datagram.port}");
      if (str.startsWith('{') && str.endsWith('}')) {
        var data = json.decode(str);
        if (data is! Map) return;
        //如果是自己的广播，就不处理
        if (data['id'] == deviceId) {
          return;
        }
        //处理Hello的广播
        if (data["type"] == "hello") {
          //如果http服务已经启动，就回复自己的信息
          if (httpRunning.value) {
            sendInfo(datagram.address, datagram.port);
          }
          return;
        }
        // 处理其他端的广播
        // 地址直接从datagram中获取，能收到回复说明地址是可以连通的
        var address = datagram.address.address;
        var port = (data['port'] is int)
            ? data['port'] as int
            : int.tryParse(data['port']?.toString() ?? '') ?? httpPort;
        final discovered = SyncClinet(
          id: data['id']?.toString() ?? '',
          name: data['name']?.toString() ?? address,
          address: address,
          port: port,
          type: data['type']?.toString() ?? 'unknown',
        );
        //检查是否已经存在（按地址+端口区分，支持同机双版本共存）
        var index = scanClients.indexWhere(
          (element) => element.address == address && element.port == port,
        );
        if (index == -1) {
          scanClients.add(discovered);
        } else {
          scanClients[index] = discovered;
        }
      }
    } catch (e) {
      Log.d('解析 UDP 广播失败：$e');
    }
  }

  /// 发送UDP广播至其他端
  void sendHello() async {
    if (udp == null) return;
    try {
      await udp!.send(
        utf8.encode(json.encode({
          "id": deviceId,
          "type": "hello",
        })),
        Endpoint.broadcast(
          port: const Port(udpPort),
        ),
      );
      Log.i("send udp: hello");
    } catch (e) {
      Log.d('发送 UDP hello 失败：$e');
    }
  }

  /// 向发现请求的设备回复自身信息
  void sendInfo(InternetAddress address, int port) async {
    if (udp == null) return;
    try {
      var name = await getDeviceName();

      var data = {
        "id": deviceId,
        "type": Platform.operatingSystem,
        "name": name,
        "port": serverPort.value,
      };

      await udp!.send(
        utf8.encode(json.encode(data)),
        Endpoint.unicast(address, port: Port(port)),
      );
      Log.i("send udp info: $data");
    } catch (e) {
      Log.d('发送 UDP info 失败：$e');
    }
  }

  Future<String> getDeviceName() async {
    var name = "SimpleLive-${Platform.operatingSystem}";
    try {
      if (Platform.isAndroid) {
        var info = await deviceInfo.androidInfo;
        name = info.model;
      } else if (Platform.isIOS) {
        var info = await deviceInfo.iosInfo;
        name = info.name;
      } else if (Platform.isMacOS) {
        var info = await deviceInfo.macOsInfo;
        name = info.computerName;
      } else if (Platform.isLinux) {
        var info = await deviceInfo.linuxInfo;
        name = info.name;
      } else if (Platform.isWindows) {
        var info = await deviceInfo.windowsInfo;
        name = info.userName;
      }
    } catch (e) {
      Log.d('读取设备名称失败：$e');
    }
    return name;
  }

  void refreshClients() {
    scanClients.clear();
    sendHello();
  }

  /// 读取本地IP
  /// - 如果是wifi，直接获取wifi的IP
  /// - 如果是有线，获取所有的IP，找到全部的IP
  Future<String> getLocalIP() async {
    String? ip = "";
    try {
      ip = await networkInfo.getWifiIP();
    } catch (e) {
      Log.logPrint(e);
    }
    try {
      if (ip == null || ip.isEmpty) {
        var interfaces = await NetworkInterface.list();
        var ipList = <String>[];
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type.name == 'IPv4' &&
                !addr.address.startsWith('127') &&
                !addr.isMulticast &&
                !addr.isLoopback) {
              ipList.add(addr.address);
              break;
            }
          }
        }
        ip = ipList.join(';');
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return ip ?? "";
  }

  Router buildSyncRouter() {
    var serverRouter = Router();
    serverRouter.get('/', _helloRequest);
    serverRouter.get('/info', _infoRequest);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      serverRouter.get('/sync-relay', webSocketHandler(_relayRemoteSync));
    }
    serverRouter.post('/sync/follow', _syncFollowUserReuqest);
    serverRouter.post('/sync/tag', _syncFollowUserTagRequest);
    serverRouter.post('/sync/history', _syncHistoryReuqest);
    serverRouter.post('/sync/blocked_word', _syncBlockedWordReuqest);
    serverRouter.post('/sync/account/bilibili', _syncBiliAccountReuqest);

    // 双向同步：允许新设备主动从对方拉取数据
    serverRouter.get('/sync/follow', _exportFollowUserRequest);
    serverRouter.get('/sync/tag', _exportFollowUserTagRequest);
    serverRouter.get('/sync/history', _exportHistoryRequest);
    serverRouter.get('/sync/blocked_word', _exportBlockedWordRequest);
    serverRouter.get('/sync/account/bilibili', _exportBiliAccountRequest);
    return serverRouter;
  }

  /// 初始化HTTP服务
  void initServer() async {
    try {
      var serverRouter = buildSyncRouter();
      Object? lastError;
      for (final candidatePort in fallbackHttpPorts) {
        try {
          server = await shelf_io.serve(
            serverRouter.call,
            InternetAddress.anyIPv4,
            candidatePort,
          );
          break;
        } catch (e) {
          lastError = e;
        }
      }
      if (server == null) {
        throw lastError ?? const SocketException('无法绑定局域网同步 HTTP 端口');
      }

      // Enable content compression
      server!.autoCompress = true;
      serverPort.value = server!.port;
      httpRunning.value = true;
      httpErrorMsg.value = '';

      var ip = await getLocalIP();
      ipAddress.value = ip;

      Log.d('Serving at http://$ip:${server!.port}');
    } catch (e) {
      httpErrorMsg.value = e.toString();
      Log.logPrint(e);
    }
  }

  void _relayRemoteSync(WebSocketChannel client) async {
    try {
      final upstream =
          await RemoteSyncConnection().connect(Constant.kRemoteSyncUrl);
      client.stream.listen(
        upstream.add,
        onDone: upstream.close,
        onError: (Object error) => upstream.close(),
      );
      upstream.listen(
        client.sink.add,
        onDone: client.sink.close,
        onError: (Object error) => client.sink.close(),
      );
    } catch (error) {
      Log.logPrint('远程同步转接失败：$error');
      await client.sink.close(1011, '同步服务连接失败');
    }
  }

  /// 测试服务能否正常访问
  shelf.Response _helloRequest(shelf.Request request) {
    return toJsonResponse({
      'status': true,
      'message': 'http server is running...',
      "version":
          'SimpeLive ${Platform.operatingSystem} v${Utils.packageInfo.version}',
      'port': serverPort.value,
    });
  }

  /// 发送自己的信息
  Future<shelf.Response> _infoRequest(shelf.Request request) async {
    var name = await getDeviceName();
    return toJsonResponse({
      "id": deviceId,
      'type': Platform.operatingSystem,
      'name': name,
      'version': Utils.packageInfo.version,
      'address': ipAddress.value,
      'port': serverPort.value,
    });
  }

  Future<shelf.Response> _exportFollowUserRequest(shelf.Request request) async {
    final users = DBService.instance.getFollowList();
    return toJsonResponse({
      'status': true,
      'data': users.map((e) => e.toJson()).toList(),
    });
  }

  Future<shelf.Response> _exportFollowUserTagRequest(
      shelf.Request request) async {
    final tags = DBService.instance.getFollowTagList();
    return toJsonResponse({
      'status': true,
      'data': tags.map((e) => e.toJson()).toList(),
    });
  }

  Future<shelf.Response> _exportHistoryRequest(shelf.Request request) async {
    final histories = DBService.instance.getHistores();
    return toJsonResponse({
      'status': true,
      'data': histories.map((e) => e.toJson()).toList(),
    });
  }

  Future<shelf.Response> _exportBlockedWordRequest(
      shelf.Request request) async {
    final settings = AppSettingsController.instance;
    return toJsonResponse({
      'status': true,
      'data': settings.shieldList.toList(),
      'users': settings.shieldUserList.toList(),
    });
  }

  Future<shelf.Response> _exportBiliAccountRequest(
      shelf.Request request) async {
    return toJsonResponse({
      'status': true,
      'cookie': BiliBiliAccountService.instance.cookie,
    });
  }

  /// 同步关注用户列表
  Future<shelf.Response> _syncFollowUserReuqest(shelf.Request request) async {
    try {
      var body = await request.readAsString();
      Log.d('_syncFollowUserReuqest: $body');
      var jsonBody = json.decode(body) as List;
      var added = 0;
      var updated = 0;
      for (var item in jsonBody) {
        var user = FollowUser.fromJson(Map<String, dynamic>.from(item as Map));
        final existing = DBService.instance.followBox.get(user.id);
        if (existing == null) {
          await DBService.instance.followBox.put(user.id, user);
          added++;
        } else {
          var changed = false;
          if (user.userName.isNotEmpty && existing.userName != user.userName) {
            existing.userName = user.userName;
            changed = true;
          }
          if (user.face.isNotEmpty && existing.face != user.face) {
            existing.face = user.face;
            changed = true;
          }
          if (existing.tag == "全部" && user.tag.isNotEmpty && user.tag != "全部") {
            existing.tag = user.tag;
            changed = true;
          }
          if ((existing.categoryName == null ||
                  existing.categoryName!.isEmpty) &&
              user.categoryName != null &&
              user.categoryName!.isNotEmpty) {
            existing.categoryName = user.categoryName;
            changed = true;
          }
          if (changed) {
            await DBService.instance.followBox.put(user.id, existing);
            updated++;
          }
        }
      }

      if (added > 0 || updated > 0) {
        WebDavAutoSyncService.notifyLocalMutation();
      }
      SmartDialog.showToast(
        added > 0 || updated > 0
            ? '已接收关注列表（新增$added，更新$updated）'
            : '已同步关注用户列表（无新增）',
      );
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return toJsonResponse({
        'status': true,
        'message': 'success',
        'added': added,
        'updated': updated,
        'total': jsonBody.length,
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  /// 同步标签列表
  Future<shelf.Response> _syncFollowUserTagRequest(
      shelf.Request request) async {
    try {
      var body = await request.readAsString();
      Log.d('_syncFollowUserTagRequest: $body');
      final jsonBody = json.decode(body) as List;
      final tags = jsonBody
          .map((item) =>
              FollowUserTag.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final db = DBService.instance;
      var changedCount = 0;
      await db.normalizeFollowTags();
      // LAN sync shares the tag mutation queue with migration and WebDAV.
      // Keep read + union + write together so a migration cannot erase or
      // overwrite a tag received concurrently from another device.
      await db.runFollowTagMutation(() async {
        for (final tag in tags) {
          final localTag = db.tagBox.get(tag.id);
          if (localTag == null) {
            await db.tagBox.put(tag.id, tag);
            changedCount++;
          } else {
            final userIds = {...localTag.userId, ...tag.userId}.toList();
            if (userIds.length != localTag.userId.length) {
              await db.tagBox.put(
                tag.id,
                localTag.copyWith(userId: userIds),
              );
              changedCount++;
            }
          }
        }
      });
      await db.normalizeFollowTags();

      if (changedCount > 0) {
        WebDavAutoSyncService.notifyLocalMutation();
      }
      SmartDialog.showToast('已同步标签列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      return toJsonResponse({
        'status': true,
        'message': 'success',
        'changed': changedCount,
        'total': tags.length,
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  /// 同步观看记录
  Future<shelf.Response> _syncHistoryReuqest(shelf.Request request) async {
    try {
      var body = await request.readAsString();
      Log.d('_syncHistoryReuqest: $body');
      var jsonBody = json.decode(body) as List;
      var added = 0;
      var updated = 0;
      for (var item in jsonBody) {
        var history = History.fromJson(Map<String, dynamic>.from(item as Map));
        final existing = DBService.instance.historyBox.get(history.id);
        if (existing == null) {
          await DBService.instance.addOrUpdateHistory(history);
          added++;
        } else if (history.updateTime.isAfter(existing.updateTime)) {
          await DBService.instance.addOrUpdateHistory(history);
          updated++;
        }
      }

      SmartDialog.showToast(
        added > 0 || updated > 0
            ? '已接收观看记录（新增$added，更新$updated）'
            : '已同步观看记录（无新增）',
      );
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
      return toJsonResponse({
        'status': true,
        'message': 'success',
        'added': added,
        'updated': updated,
        'total': jsonBody.length,
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  /// 同步弹幕屏蔽词（兼容纯数组与含屏蔽用户的对象格式）
  Future<shelf.Response> _syncBlockedWordReuqest(shelf.Request request) async {
    try {
      var body = await request.readAsString();
      Log.d('_syncBlockedWordReuqest: $body');
      var jsonBody = json.decode(body);
      var addedWords = 0;
      var addedUsers = 0;
      final settings = AppSettingsController.instance;
      if (jsonBody is List) {
        for (var keyword in jsonBody) {
          final text = keyword.toString().trim();
          if (text.isNotEmpty && !settings.shieldList.contains(text)) {
            settings.addShieldList(text);
            addedWords++;
          }
        }
      } else if (jsonBody is Map) {
        final words = jsonBody['words'];
        if (words is List) {
          for (var keyword in words) {
            final text = keyword.toString().trim();
            if (text.isNotEmpty && !settings.shieldList.contains(text)) {
              settings.addShieldList(text);
              addedWords++;
            }
          }
        }
        final users = jsonBody['users'];
        if (users is List) {
          for (var user in users) {
            final text = user.toString().trim();
            if (text.isNotEmpty && !settings.shieldUserList.contains(text)) {
              settings.addShieldUser(text);
              addedUsers++;
            }
          }
        }
      }
      SmartDialog.showToast(
        addedWords > 0 || addedUsers > 0
            ? '已接收弹幕屏蔽（新增词$addedWords，用户$addedUsers）'
            : '已同步弹幕屏蔽词（无新增）',
      );
      return toJsonResponse({
        'status': true,
        'message': 'success',
        'addedWords': addedWords,
        'addedUsers': addedUsers,
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  /// 同步哔哩哔哩账号
  Future<shelf.Response> _syncBiliAccountReuqest(shelf.Request request) async {
    try {
      var body = await request.readAsString();
      Log.d('_syncBiliAccountReuqest: $body');
      var jsonBody = json.decode(body);
      var cookie = jsonBody['cookie'];
      var updated = false;
      if (cookie is String && cookie.isNotEmpty) {
        if (BiliBiliAccountService.instance.cookie != cookie) {
          BiliBiliAccountService.instance.setCookie(cookie);
          BiliBiliAccountService.instance.loadUserInfo();
          updated = true;
          SmartDialog.showToast('已同步哔哩哔哩账号');
        } else {
          SmartDialog.showToast('哔哩哔哩账号已是最新');
        }
      }
      return toJsonResponse({
        'status': true,
        'message': 'success',
        'updated': updated,
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  shelf.Response toJsonResponse(Map<String, dynamic> data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {
        'Content-Type': 'application/json',
      },
      encoding: Encoding.getByName('utf-8'),
    );
  }

  @override
  void onClose() {
    Log.d('SyncService close');
    udp?.close();
    server?.close(force: true);
    super.onClose();
  }
}

class SyncClinet {
  final String id;
  final String name;
  final String address;
  final int port;
  final String type;
  SyncClinet({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.type,
  });
}
