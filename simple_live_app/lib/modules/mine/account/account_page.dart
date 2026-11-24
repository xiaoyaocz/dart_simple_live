import 'dart:async';

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
                  Padding(
                    padding: AppStyle.edgeInsetsH12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text("恢复默认源"),
                          onPressed: () => service.restoreDefaultSources(),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text("进入IPTV页自动刷新"),
                    subtitle: const Text("关闭后进页只读缓存，更新靠手动刷新", style: TextStyle(fontSize: 12)),
                    value: controller.iptvAutoRefreshOnEnter.value,
                    onChanged: controller.setIptvAutoRefreshOnEnter,
                  ),
                  ...service.sourcePool.map((source) {
                    final enabled = service.enabledSourceNames.contains(source.name);
                    return _buildSourceCard(context, source, enabled, service);
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

  /// IPTV源卡片，包含开关、删除、完整镜像URL、复制按钮
  Widget _buildSourceCard(BuildContext context, source, bool enabled, service) {
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
                      Text("${service.sourceCategory(source)} · ${service.sourceHealthLabel(source)}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (_) => service.toggleSourceEnabled(source),
                ),
                if (source.author == "自定义")
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showEditCustomDialog(context, source, service),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _showDeleteConfirm(context, source, service),
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

  /// 删除源确认对话框，区分预置源与自定义源提示
  Future<void> _showDeleteConfirm(BuildContext context, source, service) async {
    final isCustom = source.author == "自定义";
    final content = isCustom
        ? "确定要删除自定义源「${source.name}」吗？删除后无法恢复，请谨慎操作。"
        : "确定要删除预置源「${source.name}」吗？删除后可通过「恢复默认源」找回。";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除源"),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("取消")),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text("删除")),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteSource(source);
    }
  }

  Future<void> _showAddCustomDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    // 校验中标记需放在 builder 外，避免 setState 重建时被重置
    var testing = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("添加自定义源"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "源名称")),
                AppStyle.vGap12,
                TextField(controller: urlController, decoration: const InputDecoration(labelText: "M3U 地址（http/https）")),
              ],
            ),
            actions: [
              TextButton(
                onPressed: testing ? null : Get.back,
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: testing
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        final error = _validateCustomInput(name, url, pool: IptvService.instance.sourcePool);
                        if (error != null) {
                          _showSnack(error);
                          return;
                        }
                        setState(() => testing = true);
                        try {
                          final count = await IptvService.instance.validateCustomSourceUrl(url);
                          await IptvService.instance.addCustomSource(name: name, url: url);
                          Get.back();
                          _showSnack("已添加「$name」，解析到 $count 个频道");
                        } catch (e) {
                          if (context.mounted) setState(() => testing = false);
                          _showSnack("源校验失败：${_errorText(e)}");
                        }
                      },
                child: testing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("添加"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 编辑自定义源对话框
  Future<void> _showEditCustomDialog(BuildContext context, source, service) async {
    final nameController = TextEditingController(text: source.name);
    final urlController = TextEditingController(text: source.urls.first);
    // 校验中标记需放在 builder 外，避免 setState 重建时被重置
    var testing = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("编辑自定义源"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "源名称")),
                AppStyle.vGap12,
                TextField(controller: urlController, decoration: const InputDecoration(labelText: "M3U 地址（http/https）")),
              ],
            ),
            actions: [
              TextButton(
                onPressed: testing ? null : Get.back,
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: testing
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        final error = _validateCustomInput(
                          name,
                          url,
                          pool: IptvService.instance.sourcePool,
                          ignore: source,
                        );
                        if (error != null) {
                          _showSnack(error);
                          return;
                        }
                        setState(() => testing = true);
                        try {
                          final count = await IptvService.instance.validateCustomSourceUrl(url);
                          await service.updateCustomSource(source, name: name, url: url);
                          Get.back();
                          _showSnack("已保存「$name」，解析到 $count 个频道");
                        } catch (e) {
                          if (context.mounted) setState(() => testing = false);
                          _showSnack("源校验失败：${_errorText(e)}");
                        }
                      },
                child: testing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("保存"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 校验自定义源名称与地址：格式、查重；返回错误文案，null 表示通过
  String? _validateCustomInput(
    String name,
    String url, {
    required List<IptvSourceMeta> pool,
    IptvSourceMeta? ignore,
  }) {
    if (name.isEmpty || url.isEmpty) return "请填写源名称与 M3U 地址";
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
      return "地址需以 http:// 或 https:// 开头";
    }
    if (pool.any((e) => e.name == name && e != ignore)) {
      return "源名称「$name」已存在";
    }
    for (final e in pool) {
      if (e == ignore) continue;
      if (e.urls.contains(url)) return "该地址已存在于「${e.name}」";
    }
    return null;
  }

  /// 压缩错误文案为可读提示
  String _errorText(Object e) {
    if (e is TimeoutException) return "连接超时（8秒），请检查地址或稍后再试";
    final text = e.toString().trim();
    return text.isEmpty ? "未知错误" : text;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(Get.context!).showSnackBar(SnackBar(content: Text(message)));
  }
}
