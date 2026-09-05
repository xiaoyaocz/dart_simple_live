import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';

import 'package:simple_live_app/services/sync_service.dart';

class LocalSyncController extends BaseController {
  final String? address;
  LocalSyncController(this.address);

  @override
  void onInit() {
    SyncService.instance.refreshClients();
    Future.delayed(Duration.zero, initConnect);
    super.onInit();
  }

  void initConnect() {
    if (address != null && address!.isNotEmpty) {
      addressController.text = address!;
      connect();
    }
  }

  TextEditingController addressController = TextEditingController();
  SyncClientRequest request = SyncClientRequest();

  void connect() async {
    final parsed = parseAddress(addressController.text);
    if (parsed == null) {
      SmartDialog.showToast("请输入地址");
      return;
    }

    var client = SyncClinet(
      id: 'manual',
      address: parsed.$1,
      port: parsed.$2,
      name: "手动输入",
      type: Platform.operatingSystem,
    );
    connectClient(client);
  }

  (String, int)? parseAddress(String rawAddress) {
    var address = rawAddress.trim();
    if (address.isEmpty) {
      return null;
    }
    if (!address.startsWith("http://") && !address.startsWith("https://")) {
      address = "http://$address";
    }
    final uri = Uri.tryParse(address);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    return (uri.host, uri.hasPort ? uri.port : SyncService.httpPort);
  }

  void connectClient(SyncClinet client) async {
    try {
      SmartDialog.showLoading(msg: "连接中...");
      var info = await request.getClientInfo(client);
      AppNavigator.toSyncDevice(client, info);
    } catch (e) {
      Log.e("局域网同步连接失败：$e", StackTrace.current);
      SmartDialog.dismiss();
      await Utils.showMessageDialog(
        "局域网同步只支持两台设备在同一 Wi-Fi/局域网内互相访问。"
        "如果两台设备不在同一局域网，需要先配置 VPN、端口转发或内网穿透；"
        "否则请改用远程房间同步或 WebDAV。\n\n"
        "错误详情：${exceptionToString(e)}",
        title: "连接失败",
        selectable: true,
      );
    } finally {
      SmartDialog.dismiss();
    }
  }

  void toScanQr() async {
    var result = await Get.toNamed(RoutePath.kSyncScan);
    if (result == null || result.isEmpty) {
      return;
    }
    var addressList = (result as String).split(";");
    if (addressList.length >= 2) {
      //弹窗选择
      showPickerAddress(addressList);
    } else {
      addressController.text = result;
      //connect();
    }
  }

  void showPickerAddress(List<String> addressList) {
    SmartDialog.showToast("扫描到多个地址，请选择一个连接");
    Utils.showBottomSheet(
      title: '请选择地址',
      child: ListView.builder(
        itemBuilder: (_, i) {
          return ListTile(
            title: Text(addressList[i]),
            onTap: () {
              Get.back();
              addressController.text = addressList[i];
              // connect();
            },
          );
        },
        itemCount: addressList.length,
      ),
    );
  }

  void showInfo() {
    final addresses = SyncService.instance.ipAddress.value
        .split(";")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => "$e:${SyncService.httpPort}")
        .join(";");
    Utils.showBottomSheet(
      title: "本机信息",
      child: Column(
        children: [
          Visibility(
            visible:
                SyncService.instance.httpRunning.value && addresses.isNotEmpty,
            child: GestureDetector(
              onTap: () {
                Get.back();
              },
              child: QrImageView(
                data: addresses,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                padding: AppStyle.edgeInsetsA12,
                size: 200,
              ),
            ),
          ),
          AppStyle.vGap24,
          Visibility(
            visible: SyncService.instance.httpRunning.value,
            child: Text(
              addresses.isEmpty
                  ? '服务已启动，但未获取到局域网 IP，请确认已连接同一局域网'
                  : '服务已启动：${addresses.replaceAll(";", "；")}',
              textAlign: TextAlign.center,
            ),
          ),
          Visibility(
            visible: !SyncService.instance.httpRunning.value,
            child: Text(
              SyncService.instance.lanErrorMsg.isEmpty
                  ? 'HTTP服务未启动，请尝试重启应用'
                  : SyncService.instance.lanErrorMsg,
              textAlign: TextAlign.center,
            ),
          ),
          Visibility(
            visible: SyncService.instance.httpRunning.value &&
                SyncService.instance.udpErrorMsg.value.isNotEmpty,
            child: Text(
              SyncService.instance.udpErrorMsg.value,
              textAlign: TextAlign.center,
            ),
          ),
          AppStyle.vGap12,
          Visibility(
            visible:
                SyncService.instance.httpRunning.value && addresses.isNotEmpty,
            child: const Text(
              "请使用其他Simple Live客户端扫描上方二维码\n建立连接后可选择需要同步的数据",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
