import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  Future<void> _editSyncServer() async {
    final customUrl = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final optionUrls = <String, String>{
      SignalRService.kDefaultServerOption: SignalRService.kDefaultUrl,
      SignalRService.kCloudflareServerOption: SignalRService.kCloudflareUrl,
      SignalRService.kCustomServerOption: customUrl,
    };
    final probeResults = <String, ValueNotifier<SyncServerProbeResult?>>{
      for (final entry in optionUrls.entries)
        entry.key: ValueNotifier(
          entry.value.isEmpty
              ? const SyncServerProbeResult.notConfigured()
              : null,
        ),
    };
    for (final entry in optionUrls.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      SignalRService.probeServer(entry.value).then((result) {
        probeResults[entry.key]?.value = result;
      });
    }

    final option = await Utils.showOptionDialog<String>(
      SignalRService.kServerOptions,
      SignalRService.configuredServerOption,
      title: "选择同步服务",
      titleBuilder: (value) => _buildSyncServerOptionTitle(
        value,
        probeResults[value]!,
      ),
      subtitleBuilder: (value) => Text(
        _syncServerOptionDescription(value, optionUrls[value]!),
      ),
    );
    if (option == null) {
      return;
    }
    if (option == SignalRService.kDefaultServerOption) {
      await SignalRService.setConfiguredUrl("");
      SmartDialog.showToast("已切换到自建服务器");
    } else if (option == SignalRService.kCloudflareServerOption) {
      await SignalRService.setConfiguredUrl(SignalRService.kCloudflareUrl);
      SmartDialog.showToast("已切换到 Cloudflare Worker");
    } else {
      final saved = await _editCustomSyncServerUrl();
      if (!saved) {
        return;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildSyncServerOptionTitle(
    String option,
    ValueNotifier<SyncServerProbeResult?> probeResult,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(option, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<SyncServerProbeResult?>(
          valueListenable: probeResult,
          builder: (context, result, _) {
            if (result == null) {
              return const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text("检测中"),
                ],
              );
            }
            final color = result.isReachable
                ? Colors.green
                : result.label == "未配置"
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Colors.red;
            return Text(result.label, style: TextStyle(color: color));
          },
        ),
      ],
    );
  }

  String _syncServerOptionDescription(String option, String url) {
    if (option == SignalRService.kDefaultServerOption) {
      return "$url\n默认直连；设置代理端口后使用本地代理";
    }
    if (option == SignalRService.kCloudflareServerOption) {
      return "$url\n备用服务，部分网络需要代理";
    }
    final address = url.isEmpty ? "选择后填写 ws:// 或 wss:// 地址" : url;
    return "$address\n按当前同步代理端口设置检测";
  }

  Future<bool> _editCustomSyncServerUrl() async {
    final current = SignalRService.configuredServerOption ==
            SignalRService.kCustomServerOption
        ? SignalRService.configuredUrl
        : "";
    final value = await Utils.showEditTextDialog(
      current,
      title: "自定义同步服务",
      hintText: "wss://example.com/sync",
      validate: (text) {
        if (!SignalRService.isValidServerUrl(text)) {
          SmartDialog.showToast("请输入 ws:// 或 wss:// 开头的同步服务地址");
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return false;
    }
    await SignalRService.setConfiguredUrl(value);
    SmartDialog.showToast("已保存自定义同步服务");
    return true;
  }

  Future<void> _editSyncProxyPort() async {
    final value = await Utils.showEditTextDialog(
      SignalRService.configuredProxyUrl,
      title: "同步代理端口",
      hintText: "留空直连，例如 ${SignalRService.kDefaultLocalProxy}",
      validate: (text) {
        final value = text.trim();
        if (!SignalRService.isValidProxyConfig(value)) {
          SmartDialog.showToast("请输入 1-65535 的本地代理端口，留空为直连");
          return false;
        }
        return true;
      },
    );
    if (value == null) {
      return;
    }
    await SignalRService.setConfiguredProxyUrl(value);
    SmartDialog.showToast(
      value.trim().isEmpty ? "已切换为直连" : "已保存本地代理端口",
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("数据同步"),
        actions: [
          Visibility(
            visible: GetPlatform.isAndroid || GetPlatform.isIOS,
            child: TextButton.icon(
              onPressed: () async {
                var result = await Get.toNamed(RoutePath.kSyncScan);
                if (result == null || result.isEmpty) {
                  return;
                }
                if (result.length == SignalRService.kRoomIdLength) {
                  Get.toNamed(RoutePath.kRemoteSyncRoom, arguments: result);
                } else {
                  Get.toNamed(RoutePath.kLocalSync, arguments: result);
                }
              },
              icon: const Icon(Remix.qr_scan_line),
              label: const Text("扫一扫"),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "远程同步",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                SettingsAction(
                  leading: const Icon(Remix.cloud_line),
                  title: "同步服务",
                  subtitle:
                      "${SignalRService.configuredUrl}\n两台设备必须选择相同服务；自建服务器与 Cloudflare 的房间不互通。",
                  value: SignalRService.configuredServerLabel,
                  onTap: _editSyncServer,
                ),
                AppStyle.divider,
                SettingsAction(
                  leading: const Icon(Remix.link_m),
                  title: "连接方式",
                  subtitle: "留空为直连；填写本地代理端口后，远程同步统一走该端口",
                  value: SignalRService.proxyDisplayName,
                  onTap: _editSyncProxyPort,
                ),
              ],
            ),
          ),
          AppStyle.vGap12,
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text("配置包导入导出"),
                  leading: const Icon(Remix.file_transfer_line),
                  subtitle: const Text("跨平台迁移设置、关注、历史和屏蔽数据"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kProfileBackup);
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("创建房间"),
                  leading: const Icon(Remix.home_wifi_line),
                  subtitle: const Text("其他设备可以通过房间号加入"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kRemoteSyncRoom);
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("加入房间"),
                  leading: const Icon(Remix.add_circle_line),
                  subtitle: const Text("加入其他设备创建的房间"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    var input = await Utils.showEditTextDialog(
                      "",
                      title: "加入房间",
                      hintText: "请输入房间号,不区分大小写",
                      validate: (text) {
                        if (text.isEmpty) {
                          SmartDialog.showToast("房间号不能为空");
                          return false;
                        }
                        if (text.trim().length !=
                            SignalRService.kRoomIdLength) {
                          SmartDialog.showToast(
                              "请输入${SignalRService.kRoomIdLength}位房间号");
                          return false;
                        }
                        return true;
                      },
                    );
                    if (input != null && input.isNotEmpty) {
                      Get.toNamed(RoutePath.kRemoteSyncRoom,
                          arguments: input.trim().toUpperCase());
                    }
                  },
                ),
                AppStyle.divider,
                ListTile(
                  title: const Text("WebDAV"),
                  leading: const Icon(Icons.cloud_upload_outlined),
                  subtitle: const Text("通过WebDAV同步数据"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kRemoteSyncWebDav);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "局域网同步",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text("局域网同步"),
                  subtitle: const Text("在局域网内同步数据"),
                  leading: const Icon(Remix.device_line),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Get.toNamed(RoutePath.kLocalSync);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
