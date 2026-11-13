import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/iptv_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("账号管理")),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          shrinkWrap: false,
          physics: const ClampingScrollPhysics(),
          padding: AppStyle.pagePadding(top: 0),
          children: [
            const Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Text("哔哩哔哩账号需要登录才能看高清晰度的直播。", textAlign: TextAlign.center),
            ),
            // 原有直播平台账号入口，完整保留
            Obx(() => ListTile(
              leading: Image.asset('assets/images/bilibili_2.png', width: 36, height: 36),
              title: const Text("哔哩哔哩"),
              subtitle: Text(BiliBiliAccountService.instance.name.value),
              trailing: BiliBiliAccountService.instance.logined.value
                  ? const Icon(Icons.logout) : const Icon(Icons.chevron_right),
              onTap: controller.bilibiliTap,
            )),
            Obx(() => ListTile(
              leading: Image.asset('assets/images/douyu.png', width: 36, height: 36),
              title: const Text("斗鱼直播"),
              subtitle: Text(controller.getDouyuCookieSummaryText()),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.douyuTap,
            )),
            ListTile(
              leading: Image.asset('assets/images/huya.png', width: 36, height: 36),
              title: const Text("虎牙直播"),
              subtitle: const Text("无需登录"),
              enabled: false,
              trailing: const Icon(Icons.chevron_right),
            ),
            Obx(() => ListTile(
              leading: Image.asset('assets/images/douyin.png', width: 36, height: 36),
              title: const Text("抖音直播"),
              subtitle: Text(controller.getDouyinCookieSummaryText()),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.douyinTap,
            )),
            Obx(() => ListTile(
              leading: Image.asset('assets/images/kuaishou.png', width: 36, height: 36),
              title: const Text("快手直播"),
              subtitle: Text(controller.getKuaishouCookieSummaryText()),
              trailing: controller.canUseKuaishouWebLogin
                  ? TextButton(onPressed: controller.kuaishouWebLogin, child: const Text("网页登录"))
                  : const Icon(Icons.chevron_right),
              onTap: controller.kuaishouTap,
            )),
            const Divider(height: 32),
            const Padding(
              padding: AppStyle.edgeInsetsH12,
              child: Text("IPTV 公开直播源", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            AppStyle.vGap8,
            Obx(() {
              final service = IptvService.instance;
              return Column(
                children: [
                  ...service.sourcePool.map((source) {
                    final enabled = service.enabledSourceNames.contains(source.name);
                    final isCustom = source.author == "自定义";
                    return _buildSourceCard(context, source, enabled, isCustom, service);
                  }),
                  AppStyle.vGap8,
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("添加自定义源"),
                    onPressed: () => _showAddCustomDialog(context),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// IPTV源卡片，包含开关、完整镜像URL、复制按钮
  Widget _buildSourceCard(BuildContext context, source, bool enabled, bool isCustom, service) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: AppStyle.edgeInsetsA12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(source.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text("${source.author} · ${source.description}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (_) => service.toggleSourceEnabled(source),
                ),
                if (isCustom)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => service.deleteCustomSource(source),
                  ),
              ],
            ),
            AppStyle.vGap8,
            const Text("镜像地址：", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ...source.urls.map<Widget>((url) => Row(
              children: [
                Expanded(child: Text(url, style: const TextStyle(fontSize: 11))),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("链接已复制")));
                  },
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCustomDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("添加自定义源"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "源名称")),
            AppStyle.vGap12,
            TextField(controller: urlController, decoration: const InputDecoration(labelText: "M3U 地址")),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("取消")),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              await IptvService.instance.addCustomSource(name: name, url: url);
              Get.back();
            },
            child: const Text("添加"),
          ),
        ],
      ),
    );
  }
}
