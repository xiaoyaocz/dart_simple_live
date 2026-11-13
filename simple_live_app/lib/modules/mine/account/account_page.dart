import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: const Text("账号管理"),
      ),
      // Keep the account list as the only scrolling viewport.  On desktop,
      // an unconstrained ListView can inherit the route's remaining height
      // and leave later rows below an opaque platform surface.
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          shrinkWrap: false,
          physics: const ClampingScrollPhysics(),
          padding: AppStyle.pagePadding(top: 0),
          children: [
            const Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Text(
                "哔哩哔哩账号需要登录才能看高清晰度的直播。",
                textAlign: TextAlign.center,
              ),
            ),
            Obx(
              () => ListTile(
                leading: Image.asset(
                  'assets/images/bilibili_2.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text("哔哩哔哩"),
                subtitle: Text(BiliBiliAccountService.instance.name.value),
                trailing: BiliBiliAccountService.instance.logined.value
                    ? const Icon(Icons.logout)
                    : const Icon(Icons.chevron_right),
                onTap: controller.bilibiliTap,
              ),
            ),
            Obx(
              () => ListTile(
                leading: Image.asset('assets/images/douyu.png',
                    width: 36, height: 36),
                title: const Text("斗鱼直播"),
                subtitle: Text(controller.getDouyuCookieSummaryText()),
                trailing: const Icon(Icons.chevron_right),
                onTap: controller.douyuTap,
              ),
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/huya.png',
                width: 36,
                height: 36,
              ),
              title: const Text("虎牙直播"),
              subtitle: const Text("无需登录"),
              enabled: false,
              trailing: const Icon(Icons.chevron_right),
            ),
            Obx(
              () => ListTile(
                leading: Image.asset(
                  'assets/images/douyin.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text("抖音直播"),
                subtitle: Text(controller.getDouyinCookieSummaryText()),
                trailing: const Icon(Icons.chevron_right),
                onTap: controller.douyinTap,
              ),
            ),
            Obx(
              () => ListTile(
                leading: Image.asset(
                  'assets/images/kuaishou.png',
                  width: 36,
                  height: 36,
                ),
                title: const Text("快手直播"),
                subtitle: Text(controller.getKuaishouCookieSummaryText()),
                trailing: controller.canUseKuaishouWebLogin
                    ? TextButton(
                        onPressed: controller.kuaishouWebLogin,
                        child: const Text("网页登录"),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: controller.kuaishouTap,
              ),
            ),
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
                  ...IptvService.instance.sourcePool.map((source) {
                    final enabled = service.enabledSourceNames.contains(source.name);
                    final isCustom = source.author == "自定义";
                    return ListTile(
                      contentPadding: AppStyle.edgeInsetsH12,
                      title: Text(source.name),
                      subtitle: Text("${source.author} · ${source.description}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (_) => service.toggleSourceEnabled(source),
                          ),
                          if (isCustom)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => service.deleteCustomSource(source),
                            ),
                        ],
                      ),
                    );
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

  /// 弹出添加自定义源对话框，用户输入名称与URL
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
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "源名称",
                hintText: "例如：我的自建源",
              ),
            ),
            AppStyle.vGap12,
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: "M3U 地址",
                hintText: "https://example.com/live.m3u",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text("取消"),
          ),
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
