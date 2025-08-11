import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/follow_user/follow_info_setting/follow_info_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';

class FolloInfoPage extends GetView<FollowInfoController> {
  const FolloInfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注信息设置"),
      ),
      body: Obx(() {
        final follow = controller.followUser.value;
        if (follow == null) {
          return const Center(child: Text('未找到关注用户'));
        }
        final site = Sites.allSites[follow.siteId]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部：头像 + 平台+房间号
            Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(follow.face),
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          follow.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppStyle.vGap4,
                        Row(
                          children: [
                            Image.asset(site.logo, width: 18),
                            AppStyle.hGap8,
                            Flexible(
                              child: Text(
                                '${site.name}  房间号：${follow.roomId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: .7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 标签设置：底部弹出选择
            Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Obx(() {
                final items = controller.tagOptions;
                final selected = controller.selectedTag.value;
                final Map<String, String> valueMap = {
                  for (final t in items) t.tag: t.tag,
                };
                return SettingsMenu<String>(
                  title: '标签设置',
                  value: selected?.tag ?? '全部',
                  valueMap: valueMap,
                  onChanged: (value) {
                    final target = items.firstWhere(
                      (e) => e.tag == value,
                      orElse: () => items.first,
                    );
                    controller.changeTag(target);
                  },
                );
              }),
            ),
            const Divider(height: 1),
            // 平台迁移：输入链接解析
            Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Remix.link),
                      SizedBox(width: 8),
                      Text('平台迁移（输入直播链接进行解析）'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.migrationUrlController,
                          decoration: const InputDecoration(
                            hintText: '粘贴主播在新平台的直播间链接，如 https://... ',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => controller.parseAndMigrate(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '粘贴',
                        onPressed: controller.pasteFromClipboard,
                        icon: const Icon(Remix.clipboard_line),
                      ),
                      ElevatedButton.icon(
                        onPressed: controller.parseAndMigrate,
                        icon: const Icon(Remix.arrow_right_line),
                        label: const Text('迁移'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "other todo ...",
                    style: TextStyle(color: Colors.grey),
                  )
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
