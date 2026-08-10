import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/bulk_data_import_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/kuaishou_account_service.dart';
import 'package:simple_live_tv_app/widgets/sync_progress_dialog.dart';
import 'package:udp/udp.dart';
import 'package:uuid/uuid.dart';

class SyncService extends GetxService {
  static SyncService get instance => Get.find<SyncService>();

  static const int udpPort = 23235;
  static const int httpPort = 23234;

  UDP? udp;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final NetworkInfo networkInfo = NetworkInfo();
  HttpServer? server;

  final ipAddress = "".obs;
  final httpRunning = false.obs;
  final httpErrorMsg = "".obs;
  final udpRunning = false.obs;
  final udpErrorMsg = "".obs;

  var deviceId = "";

  @override
  void onInit() {
    Log.d('SyncService init');
    deviceId = (const Uuid().v4()).split('-').first;
    listenUDP();
    initServer();
    super.onInit();
  }

  void _finishSyncImport({
    required String successMessage,
    String? eventName,
  }) {
    if (eventName != null) {
      EventBus.instance.emit(eventName, 0);
    }
    SyncProgressDialog.dismiss();
    SmartDialog.showToast(successMessage);
  }

  void listenUDP() async {
    try {
      udp = await UDP.bind(Endpoint.any(port: const Port(udpPort)));
      udpRunning.value = true;
      udpErrorMsg.value = "";
      udp!.asStream().listen(
        (datagram) {
          final str = String.fromCharCodes(datagram!.data);
          Log.i("Received: $str from ${datagram.address}:${datagram.port}");
          if (str.startsWith('{') && str.endsWith('}')) {
            final data = json.decode(str);
            if (data["type"] == "hello") {
              if (httpRunning.value) {
                sendInfo();
              }
              return;
            }
          } else if (str == 'Who is SimpleLive?') {
            if (httpRunning.value) {
              sendInfo();
            }
          }
        },
        onError: (Object e, StackTrace stackTrace) {
          udpRunning.value = false;
          udpErrorMsg.value = _formatPortError(e, udpPort, "UDP发现服务");
          Log.e("UDP discovery stream failed: $e", stackTrace);
        },
      );
    } catch (e) {
      udpRunning.value = false;
      udpErrorMsg.value = _formatPortError(e, udpPort, "UDP发现服务");
      Log.e("UDP discovery bind failed: $e", StackTrace.current);
    }
  }

  void sendInfo() async {
    if (udp == null || !udpRunning.value) {
      Log.w("Skip UDP info broadcast: ${udpErrorMsg.value}");
      return;
    }
    final name = await getDeviceName();
    final data = {
      "id": deviceId,
      "type": "tv",
      "name": name,
    };

    await udp!.send(
      json.encode(data).codeUnits,
      Endpoint.broadcast(port: const Port(udpPort)),
    );
    Log.i("send udp info: $data");
  }

  Future<String> getLocalIP() async {
    var ip = await networkInfo.getWifiIP();
    if (ip == null || ip.isEmpty) {
      final interfaces = await NetworkInterface.list();
      final ipList = <String>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
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
    return ip;
  }

  Future<String> getDeviceName() async {
    var name = "SimpleLive-TV";
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      name = info.model;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      name = info.name;
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      name = info.computerName;
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      name = info.name;
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      name = info.userName;
    }
    return name;
  }

  void initServer() async {
    try {
      final serverRouter = Router()
        ..get('/', _helloRequest)
        ..get('/info', _infoRequest)
        ..post('/sync/follow', _syncFollowUserRequest)
        ..post('/sync/tag', _syncFollowUserTagRequest)
        ..post('/sync/history', _syncHistoryRequest)
        ..post('/sync/blocked_word', _syncBlockedWordRequest)
        ..post('/sync/account/bilibili', _syncBiliAccountRequest)
        ..post('/sync/account/douyin', _syncDouyinAccountRequest)
        ..post('/sync/account/kuaishou', _syncKuaishouAccountRequest);

      server = await shelf_io.serve(
        serverRouter,
        InternetAddress.anyIPv4,
        httpPort,
      );
      server!.autoCompress = true;

      httpRunning.value = true;
      ipAddress.value = await getLocalIP();

      Log.d('Serving at http://${ipAddress.value}:${server!.port}');
    } catch (e) {
      httpRunning.value = false;
      httpErrorMsg.value = _formatPortError(e, httpPort, "HTTP同步服务");
      Log.e("HTTP sync server bind failed: $e", StackTrace.current);
    }
  }

  String get lanErrorMsg {
    final messages = <String>[
      if (httpErrorMsg.value.trim().isNotEmpty) httpErrorMsg.value,
      if (udpErrorMsg.value.trim().isNotEmpty) udpErrorMsg.value,
    ];
    return messages.join("；");
  }

  String _formatPortError(Object error, int port, String serviceName) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (text.contains("10048") ||
        lower.contains("address already in use") ||
        lower.contains("failed to create server socket") ||
        lower.contains("only one usage of each socket address")) {
      return "$port 端口已被占用，请关闭其他 Simple Live / TV-Windows 窗口后重试";
    }
    return "$serviceName启动失败：$text";
  }

  shelf.Response _helloRequest(shelf.Request request) {
    return toJsonResponse({
      'status': true,
      'message': 'http server is running...',
      "version": 'Simple Live TV v${Utils.packageInfo.version}',
      "app": "Simple Live TV",
      "type": "tv",
      "platform": Platform.operatingSystem,
    });
  }

  Future<shelf.Response> _infoRequest(shelf.Request request) async {
    final name = await getDeviceName();
    return toJsonResponse({
      "id": deviceId,
      'type': 'tv',
      'name': name,
      'version': Utils.packageInfo.version,
      'address': ipAddress.value,
      'port': httpPort,
    });
  }

  Future<shelf.Response> _syncFollowUserRequest(shelf.Request request) async {
    try {
      final overlay =
          int.parse(request.requestedUri.queryParameters['overlay'] ?? '0');
      final chunk = _readSyncChunk(request);
      final body = await request.readAsString();

      SyncProgressDialog.show(_stageProgress("接收关注", chunk));
      final stopwatch = Stopwatch()..start();
      Log.d('_syncFollowUserRequest: ${body.length} bytes');

      final jsonBody = json.decode(body);
      if (jsonBody is! List) {
        throw const FormatException("关注列表格式不是数组");
      }

      final result = await BulkDataImportService.importFollowUsers(
        jsonBody,
        overwrite: overlay == 1,
        onProgress: _wrapChunkProgress(chunk),
      );

      stopwatch.stop();
      Log.i(
        "局域网同步关注完成：${result.logSummary} bytes=${body.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (chunk.isLastChunk) {
        _finishSyncImport(
          successMessage:
              '已同步关注用户列表（${chunk.itemTotal > 0 ? chunk.itemTotal : result.imported} 条）',
          eventName: Constant.kUpdateFollow,
        );
      }

      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      SyncProgressDialog.dismiss();
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncFollowUserTagRequest(
    shelf.Request request,
  ) async {
    try {
      final chunk = _readSyncChunk(request);
      final body = await request.readAsString();
      SyncProgressDialog.show(_stageProgress("接收标签", chunk));
      Log.d('_syncFollowUserTagRequest: ${body.length} bytes');

      final jsonBody = json.decode(body);
      if (jsonBody is! List) {
        throw const FormatException("标签列表格式不是数组");
      }

      SyncProgressDialog.update(
        SyncProgress(
          stage: "接收标签",
          current: chunk.itemEnd,
          total: chunk.itemTotal,
          message: "TV 端暂不使用关注标签",
        ),
      );

      if (chunk.isLastChunk) {
        SyncProgressDialog.dismiss();
      }

      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      SyncProgressDialog.dismiss();
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncHistoryRequest(shelf.Request request) async {
    try {
      final overlay =
          int.parse(request.requestedUri.queryParameters['overlay'] ?? '0');
      final chunk = _readSyncChunk(request);
      final body = await request.readAsString();

      SyncProgressDialog.show(_stageProgress("接收历史", chunk));
      final stopwatch = Stopwatch()..start();
      Log.d('_syncHistoryRequest: ${body.length} bytes');

      final jsonBody = json.decode(body);
      if (jsonBody is! List) {
        throw const FormatException("历史记录格式不是数组");
      }

      final result = await BulkDataImportService.importHistories(
        jsonBody,
        overwrite: overlay == 1,
        onProgress: _wrapChunkProgress(chunk),
      );

      stopwatch.stop();
      Log.i(
        "局域网同步历史完成：${result.logSummary} bytes=${body.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (chunk.isLastChunk) {
        _finishSyncImport(
          successMessage:
              '已同步观看记录（${chunk.itemTotal > 0 ? chunk.itemTotal : result.imported} 条）',
          eventName: Constant.kUpdateHistory,
        );
      }

      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      SyncProgressDialog.dismiss();
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncBlockedWordRequest(shelf.Request request) async {
    try {
      final overlay =
          int.parse(request.requestedUri.queryParameters['overlay'] ?? '0');
      final chunk = _readSyncChunk(request);
      final body = await request.readAsString();

      SyncProgressDialog.show(_stageProgress("接收屏蔽词", chunk));
      final stopwatch = Stopwatch()..start();
      Log.d('_syncBlockedWordRequest: ${body.length} bytes');

      final jsonBody = json.decode(body);
      if (jsonBody is! List) {
        throw const FormatException("屏蔽词格式不是数组");
      }

      final result = await BulkDataImportService.importShieldValues(
        jsonBody,
        overwrite: overlay == 1,
        onProgress: _wrapChunkProgress(chunk),
      );

      stopwatch.stop();
      Log.i(
        "局域网同步屏蔽词完成：${result.logSummary} bytes=${body.length} elapsed=${stopwatch.elapsedMilliseconds}ms",
      );

      if (chunk.isLastChunk) {
        _finishSyncImport(
          successMessage:
              '已同步弹幕屏蔽词（${chunk.itemTotal > 0 ? chunk.itemTotal : result.imported} 条）',
        );
      }

      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      SyncProgressDialog.dismiss();
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncBiliAccountRequest(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      Log.d('_syncBiliAccountRequest: $body');
      final jsonBody = json.decode(body);
      if (jsonBody is! Map) {
        throw const FormatException("账号数据格式不是对象");
      }

      final cookie = jsonBody['cookie']?.toString() ?? "";
      if (cookie.isEmpty) {
        throw const FormatException("账号 Cookie 为空");
      }

      BiliBiliAccountService.instance.setCookie(cookie);
      BiliBiliAccountService.instance.loadUserInfo();
      SmartDialog.showToast('已同步哔哩哔哩账号');
      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncDouyinAccountRequest(
    shelf.Request request,
  ) async {
    try {
      final body = await request.readAsString();
      Log.d('_syncDouyinAccountRequest');
      final jsonBody = json.decode(body);
      if (jsonBody is! Map) {
        throw const FormatException("账号数据格式不是对象");
      }

      final cookie = jsonBody['cookie']?.toString() ?? "";
      if (cookie.isEmpty) {
        throw const FormatException("账号 Cookie 为空");
      }

      DouyinAccountService.instance.setCookie(cookie);
      SmartDialog.showToast('已同步抖音账号');
      return toJsonResponse({
        'status': true,
        'message': 'success',
      });
    } catch (e) {
      return toJsonResponse({
        'status': false,
        'message': e.toString(),
      });
    }
  }

  Future<shelf.Response> _syncKuaishouAccountRequest(
    shelf.Request request,
  ) async {
    try {
      final body = await request.readAsString();
      final jsonBody = json.decode(body);
      if (jsonBody is! Map) {
        throw const FormatException("账号数据格式不是对象");
      }
      final cookie = jsonBody['cookie']?.toString() ?? '';
      if (cookie.isEmpty) {
        throw const FormatException("账号 Cookie 为空");
      }
      final kww = jsonBody['kww']?.toString() ?? '';
      final expiresAtMs = (jsonBody['cookieExpiresAt'] as num?)?.toInt() ?? 0;
      KuaishouAccountService.instance.setCookie(
        cookie,
        kww: kww.isEmpty ? null : kww,
        expiresAt: expiresAtMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
            : null,
      );
      SmartDialog.showToast('已同步快手账号');
      return toJsonResponse({'status': true, 'message': 'success'});
    } catch (e) {
      return toJsonResponse({'status': false, 'message': e.toString()});
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

  _SyncChunk _readSyncChunk(shelf.Request request) {
    final params = request.requestedUri.queryParameters;
    return _SyncChunk(
      chunkIndex: int.tryParse(params["chunkIndex"] ?? "") ?? 1,
      chunkTotal: int.tryParse(params["chunkTotal"] ?? "") ?? 1,
      itemStart: int.tryParse(params["itemStart"] ?? "") ?? 0,
      itemEnd: int.tryParse(params["itemEnd"] ?? "") ?? 0,
      itemTotal: int.tryParse(params["itemTotal"] ?? "") ?? 0,
    );
  }

  SyncProgress _stageProgress(String stage, _SyncChunk chunk) {
    final total = chunk.itemTotal > 0 ? chunk.itemTotal : chunk.chunkTotal;
    final current = chunk.itemTotal > 0 ? chunk.itemEnd : chunk.chunkIndex;
    return SyncProgress(
      stage: stage,
      current: current,
      total: total,
      message: chunk.chunkTotal > 1
          ? "接收第 ${chunk.chunkIndex}/${chunk.chunkTotal} 段"
          : stage,
    );
  }

  SyncProgressCallback _wrapChunkProgress(_SyncChunk chunk) {
    return (progress) {
      if (chunk.itemTotal <= 0) {
        SyncProgressDialog.update(progress);
        return;
      }
      final current = (chunk.itemStart + progress.current)
          .clamp(0, chunk.itemTotal)
          .toInt();
      SyncProgressDialog.update(
        SyncProgress(
          stage: progress.stage,
          current: current,
          total: chunk.itemTotal,
          message: "${progress.stage} $current/${chunk.itemTotal}",
        ),
      );
    };
  }

  @override
  void onClose() {
    Log.d('SyncService close');
    udp?.close();
    udpRunning.value = false;
    server?.close(force: true);
    httpRunning.value = false;
    super.onClose();
  }
}

class _SyncChunk {
  final int chunkIndex;
  final int chunkTotal;
  final int itemStart;
  final int itemEnd;
  final int itemTotal;

  const _SyncChunk({
    required this.chunkIndex,
    required this.chunkTotal,
    required this.itemStart,
    required this.itemEnd,
    required this.itemTotal,
  });

  bool get isLastChunk => chunkIndex >= chunkTotal;
}
