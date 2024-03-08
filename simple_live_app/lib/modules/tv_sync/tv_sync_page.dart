import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/tv_sync/tv_sync_controller.dart';
import 'package:simple_live_app/services/tv_service.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class TVSyncPage extends GetView<TVSyncController> {
  const TVSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV端数据同步'),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "手动连接",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller.addressController,
                    decoration: const InputDecoration(
                      labelText: 'TV端地址',
                      hintText: '请输入地址或扫码自动填写',
                      contentPadding: AppStyle.edgeInsetsH12,
                      border: OutlineInputBorder(),
                      // 暂不启用扫码功能
                      // suffixIcon: TextButton.icon(
                      //   onPressed: () {},
                      //   icon: const Icon(Remix.qr_scan_line),
                      //   label: const Text("扫一扫"),
                      // ),
                    ),
                  ),
                  AppStyle.vGap12,
                  ElevatedButton(
                    onPressed: () {
                      controller.connect();
                    },
                    child: const Text("连接TV端"),
                  ),
                ],
              ),
            ),
          ),
          AppStyle.vGap12,
          ListTile(
            title: Obx(
              () => Text(
                "已发现设备(${TVService.instance.clients.length})",
                style: Get.textTheme.titleSmall,
              ),
            ),
            visualDensity: VisualDensity.compact,
            contentPadding: AppStyle.edgeInsetsH12,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                TVService.instance.refreshClients();
              },
              icon: const Icon(Icons.refresh),
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (BuildContext context, int index) =>
                    AppStyle.divider,
                itemCount: TVService.instance.clients.length,
                itemBuilder: (BuildContext context, int index) {
                  var client = TVService.instance.clients[index];
                  return ListTile(
                    title: Text(client.deviceName),
                    subtitle: Text(client.deviceIp),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      controller.connectClient(client);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
