import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/services/iptv_service.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("账号管理")),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          const Text("IPTV 源管理", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          AppStyle.vGap12,
          Obx(() {
            final service = IptvService.instance;
            return Column(
              children: [
                ...service.sourcePool.map((source) {
                  final enabled = service.enabledSourceNames.contains(source.name);
                  final isCustom = source.author == "自定义";
                  return Card(
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
                                    Text(source.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    Text("作者：${source.author} · ${source.description}"),
                                  ],
                                ),
                              ),
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
                          AppStyle.vGap8,
                          const Text("镜像地址：", style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ...source.urls.map((url) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(url, style: const TextStyle(fontSize: 12))),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: url));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("链接已复制")),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  );
                }),
                AppStyle.vGap12,
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("添加自定义源"),
                  onPressed: () => _showAddDialog(context),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
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
