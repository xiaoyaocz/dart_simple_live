import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/auto_switch_item.dart';
import 'package:simple_live_tv_app/modules/auto_switch_list/auto_switch_list_controller.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

/// 自动换台轮播列表管理页（#154）
class AutoSwitchListPage extends StatelessWidget {
  const AutoSwitchListPage({super.key});

  AutoSwitchListController get controller => Get.find<AutoSwitchListController>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: () => Get.back(),
              ),
              AppStyle.hGap32,
              Text(
                "轮播列表管理",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              Obx(
                () => Text(
                  "自动换台将按此列表点名在播直播间（当前${controller.service.items.length}个）",
                  style: AppStyle.subTextStyleWhite,
                ),
              ),
              const Spacer(),
            ],
          ),
          AppStyle.vGap24,
          Row(
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.playlist_add,
                text: "添加关注",
                onTap: _showFollowPicker,
              ),
              AppStyle.hGap24,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.label_outline,
                text: "按标签导入",
                onTap: _showTagImport,
              ),
              AppStyle.hGap24,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.clear_all,
                text: "清空",
                onTap: _showClearConfirm,
              ),
            ],
          ),
          AppStyle.vGap24,
          Expanded(
            child: Obx(
              () {
                final items = controller.service.items;
                if (items.isEmpty) {
                  return Padding(
                    padding: AppStyle.edgeInsetsA48,
                    child: Text(
                      "列表为空：可通过“添加关注”多选加入，或用“按标签导入”一键导入整个标签",
                      style: AppStyle.subTextStyleWhite,
                    ),
                  );
                }
                return ListView.builder(
                  padding: AppStyle.edgeInsetsH48,
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildItemRow(items[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(AutoSwitchListItem item, int index) {
    final siteName = Sites.allSites[item.siteId]?.name ?? item.siteId;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${index + 1}. ${item.userName}（$siteName）",
              style: AppStyle.textStyleWhite,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.arrow_upward,
            text: "上移",
            onTap: index == 0 ? null : () => controller.moveItem(index, -1),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.arrow_downward,
            text: "下移",
            onTap: index == controller.service.items.length - 1
                ? null
                : () => controller.moveItem(index, 1),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.delete_outline,
            text: "删除",
            onTap: () => controller.removeItem(item.id),
          ),
        ],
      ),
    );
  }

  /// 多选已有关注加入轮播列表（已在列表内的不显示）
  Future<void> _showFollowPicker() async {
    final candidates = FollowUserService.instance.allList
        .where(
          (item) => !controller.service.contains(item.siteId, item.roomId),
        )
        .toList();
    if (candidates.isEmpty) {
      SmartDialog.showToast("没有可添加的关注");
      return;
    }
    final selected = <String>{};
    await Utils.showSystemRightDialog(
      width: 760.w,
      child: StatefulBuilder(
        builder: (context, setState) {
          return ListView(
            padding: AppStyle.edgeInsetsA24,
            children: [
              Text("添加关注到轮播列表", style: AppStyle.titleStyleWhite),
              AppStyle.vGap16,
              Text(
                "点按选择或取消，可多选（已在列表内的不会显示）",
                style: AppStyle.subTextStyleWhite,
              ),
              AppStyle.vGap16,
              ...candidates.map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 12.w),
                  child: HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: selected.contains(item.id)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    text: item.userName,
                    selected: selected.contains(item.id),
                    onTap: () {
                      setState(() {
                        if (!selected.remove(item.id)) {
                          selected.add(item.id);
                        }
                      });
                    },
                  ),
                ),
              ),
              AppStyle.vGap24,
              Row(
                children: [
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.check,
                    text: "加入(${selected.length})",
                    onTap: selected.isEmpty
                        ? null
                        : () {
                            final follows = candidates
                                .where((e) => selected.contains(e.id))
                                .toList();
                            final added = controller.importFollows(follows);
                            SmartDialog.showToast("已添加 $added 个关注到轮播列表");
                            Get.back();
                          },
                  ),
                  AppStyle.hGap12,
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.close,
                    text: "取消",
                    onTap: () => Get.back(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 选择标签一键导入其成员
  Future<void> _showTagImport() async {
    final tags = FollowUserService.instance.followTagList;
    if (tags.isEmpty) {
      SmartDialog.showToast("还没有自定义标签");
      return;
    }
    await Utils.showSystemRightDialog(
      width: 760.w,
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsA24,
          children: [
            Text("按标签导入", style: AppStyle.titleStyleWhite),
            AppStyle.vGap16,
            Text(
              "选择要导入的标签，成员将按标签当前顺序追加到轮播列表（自动去重）",
              style: AppStyle.subTextStyleWhite,
            ),
            AppStyle.vGap16,
            Wrap(
              spacing: 16.w,
              runSpacing: 16.w,
              children: tags
                  .map(
                    (tag) => HighlightButton(
                      focusNode: AppFocusNode(),
                      iconData: Icons.label_outline,
                      text: "${tag.tag}（${tag.userId.length}）",
                      onTap: () {
                        final added = controller.importTag(tag);
                        SmartDialog.showToast("已从「${tag.tag}」导入 $added 个关注");
                        Get.back();
                      },
                    ),
                  )
                  .toList(),
            ),
            AppStyle.vGap24,
            HighlightButton(
              focusNode: AppFocusNode(),
              iconData: Icons.close,
              text: "取消",
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearConfirm() async {
    if (controller.service.items.isEmpty) {
      SmartDialog.showToast("列表已为空");
      return;
    }
    final result = await Utils.showAlertDialog(
      "确定清空轮播列表吗？",
      title: "清空轮播列表",
    );
    if (!result) {
      return;
    }
    controller.clearAll();
    SmartDialog.showToast("轮播列表已清空");
  }
}
