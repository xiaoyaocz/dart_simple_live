import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
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
    var address = addressController.text;
    if (address.isEmpty) {
      SmartDialog.showToast("请输入地址");
      return;
    }
    if (address.startsWith('http')) {
      var uri = Uri.tryParse(address);
      if (uri != null) {
        address = uri.host;
      }
    } else if (address.contains(':')) {
      var parts = address.split(":");
      address = parts.first;
    }

    var client = SyncClinet(
      id: 'manual',
      address: address,
      port: SyncService.httpPort,
      name: "手动输入",
      type: Platform.operatingSystem,
    );
    connectClient(client);
  }

  void connectClient(SyncClinet client) async {
    try {
      SmartDialog.showLoading(msg: "连接中...");
      var info = await request.getClientInfo(client);
      AppNavigator.toSyncDevice(client, info);
    } catch (e) {
      SmartDialog.showToast("连接失败:$e");
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
    Utils.showBottomSheet(
      title: "本机信息",
      child: Column(
        children: [
          Visibility(
            visible: SyncService.instance.httpRunning.value,
            child: GestureDetector(
              onTap: () {
                Get.back();
              },
              child: QrImageView(
                data: SyncService.instance.ipAddress.value,
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
              '服务已启动：${SyncService.instance.ipAddress.value.split(';').map((e) => '$e:${SyncService.httpPort}').join('；')}',
              textAlign: TextAlign.center,
            ),
          ),
          Visibility(
            visible: !SyncService.instance.httpRunning.value,
            child: Text(
              'HTTP服务未启动：${SyncService.instance.httpErrorMsg}，请尝试重启应用',
              textAlign: TextAlign.center,
            ),
          ),
          AppStyle.vGap12,
          Visibility(
            visible: SyncService.instance.httpRunning.value,
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
