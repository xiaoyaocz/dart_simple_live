import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/iptv/playlist/iptv_source_manage_controller.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/app_text_field.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';

/// IPTV 直播源管理页：预置源启停/删除，自定义源增删改查，地址经校验后写入
class IptvSourceManagePage extends StatelessWidget {
  const IptvSourceManagePage({super.key});

  IptvSourceManageController get controller =>
      Get.find<IptvSourceManageController>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStyle.vGap32,
          _buildHeader(),
          AppStyle.vGap16,
          _buildToolbar(),
          AppStyle.vGap16,
          Expanded(child: Obx(_buildBody)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AppStyle.hGap48,
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.arrow_back,
          text: "返回",
          autofocus: true,
          onTap: Get.back,
        ),
        AppStyle.hGap32,
        Text(
          "直播源管理",
          style: AppStyle.titleStyleWhite.copyWith(fontSize: 36.w, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Obx(() => Text(
              "共${controller.service.sourcePool.length}个源 · 已启用${controller.service.enabledSourceNames.length}个",
              style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
            )),
        AppStyle.hGap48,
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: Row(
        children: [
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.add,
            text: "添加自定义源",
            onTap: () => _showEditDialog(),
          ),
          AppStyle.hGap16,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.restore,
            text: "恢复默认源",
            onTap: _restoreDefault,
          ),
          AppStyle.hGap16,
          Obx(() => HighlightButton(
                focusNode: AppFocusNode(),
                iconData: controller.autoRefreshOnEnter.value
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                text: "进页自动刷新",
                selected: controller.autoRefreshOnEnter.value,
                onTap: () async {
                  await controller.setAutoRefreshOnEnter(!controller.autoRefreshOnEnter.value);
                  SmartDialog.showToast(
                    controller.autoRefreshOnEnter.value ? "进页自动刷新已开启" : "进页自动刷新已关闭",
                  );
                },
              )),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final pool = controller.service.sourcePool;
    if (pool.isEmpty) {
      return Center(child: Text("暂无直播源", style: AppStyle.textStyleWhite));
    }
    return ListView.builder(
      padding: AppStyle.edgeInsetsH48,
      itemCount: pool.length,
      itemBuilder: (_, index) => _buildSourceRow(pool[index]),
    );
  }

  /// 源卡片行：名称/作者/地址 + 启用开关 + 编辑（自定义）+ 删除
  Widget _buildSourceRow(IptvSourceMeta source) {
    final enabled = controller.service.enabledSourceNames.contains(source.name);
    final isCustom = source.author == "自定义";
    final statusSuffix = enabled ? "" : "（已停用）";
    return Padding(
      padding: EdgeInsets.only(bottom: 16.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: AppFocusNode(),
              title: "${source.name}$statusSuffix",
              subtitle: "${source.author} · ${source.description}\n${controller.service.sourceCategory(source)} · ${controller.service.sourceHealthLabel(source)}\n${source.urls.join("\n")}",
              onTap: () => _toggleEnabled(source, enabled),
            ),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            text: enabled ? "已启用" : "已停用",
            selected: enabled,
            onTap: () => _toggleEnabled(source, enabled),
          ),
          if (isCustom) ...[
            AppStyle.hGap12,
            HighlightButton(
              focusNode: AppFocusNode(),
              iconData: Icons.edit_outlined,
              text: "编辑",
              onTap: () => _showEditDialog(source: source),
            ),
          ],
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.delete_outline,
            text: "删除",
            onTap: () => _deleteSource(source),
          ),
        ],
      ),
    );
  }

  /// 启停切换：至少保留一个启用源
  Future<void> _toggleEnabled(IptvSourceMeta source, bool enabled) async {
    if (enabled && controller.service.enabledSourceNames.length == 1) {
      SmartDialog.showToast("至少保留一个启用源");
      return;
    }
    await controller.toggleSourceEnabled(source);
    SmartDialog.showToast(enabled ? "已停用「${source.name}」" : "已启用「${source.name}」");
  }

  /// 删除源确认，区分预置源与自定义源提示
  Future<void> _deleteSource(IptvSourceMeta source) async {
    final isCustom = source.author == "自定义";
    final content = isCustom
        ? "确定要删除自定义源「${source.name}」吗？删除后无法恢复，请谨慎操作。"
        : "确定要删除预置源「${source.name}」吗？删除后可通过「恢复默认源」找回。";
    final confirmed = await Utils.showAlertDialog(content, title: "删除源");
    if (!confirmed) return;
    await controller.deleteSource(source);
    SmartDialog.showToast("已删除「${source.name}」");
  }

  /// 恢复默认源确认
  Future<void> _restoreDefault() async {
    final confirmed = await Utils.showAlertDialog(
      "将清空自定义源并恢复全部预置源为启用状态，确定继续吗？",
      title: "恢复默认源",
    );
    if (!confirmed) return;
    await controller.restoreDefaultSources();
    SmartDialog.showToast("已恢复默认源");
  }

  /// 添加/编辑自定义源对话框：名称 + 地址，确定时先做格式查重校验，再实测拉取解析
  Future<void> _showEditDialog({IptvSourceMeta? source}) async {
    final isEdit = source != null;
    final nameController = TextEditingController(text: isEdit ? source.name : "");
    final urlController = TextEditingController(text: isEdit ? source.urls.first : "");
    // 校验中标记需放在 builder 外，避免 setState 重建时被重置
    var testing = false;
    await Utils.showSystemRightDialog(
      width: 760.w,
      child: StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: AppStyle.edgeInsetsA32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? "编辑自定义源" : "添加自定义源",
                  style: AppStyle.titleStyleWhite.copyWith(fontSize: 32.w, fontWeight: FontWeight.bold),
                ),
                AppStyle.vGap24,
                Text("源名称", style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w)),
                AppStyle.vGap8,
                AppTextField(
                  controller: nameController,
                  autofocus: !isEdit,
                  hintText: "例如：我收藏的直播源",
                ),
                AppStyle.vGap24,
                Text("M3U 地址", style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w)),
                AppStyle.vGap8,
                AppTextField(
                  controller: urlController,
                  autofocus: isEdit,
                  hintText: "https://example.com/iptv.m3u",
                ),
                AppStyle.vGap16,
                Text(
                  "保存前会自动拉取校验，不可达或解析为空的地址不会写入",
                  style: AppStyle.textStyleWhite.copyWith(fontSize: 20.w, color: Colors.white54),
                ),
                AppStyle.vGap24,
                Row(
                  children: [
                    HighlightButton(
                      focusNode: AppFocusNode(),
                      text: testing ? "校验中..." : (isEdit ? "保存" : "添加"),
                      selected: true,
                      onTap: testing
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final url = urlController.text.trim();
                              final error = controller.validateInput(
                                name,
                                url,
                                ignore: isEdit ? source : null,
                              );
                              if (error != null) {
                                SmartDialog.showToast(error);
                                return;
                              }
                              setState(() => testing = true);
                              try {
                                final count = await controller.validateCustomSourceUrl(url);
                                if (isEdit) {
                                  await controller.updateCustomSource(source, name: name, url: url);
                                } else {
                                  await controller.addCustomSource(name, url);
                                }
                                Get.back();
                                SmartDialog.showToast("已保存「$name」，解析到 $count 个频道");
                              } catch (e) {
                                setState(() => testing = false);
                                SmartDialog.showToast("源校验失败：$e");
                              }
                            },
                    ),
                    AppStyle.hGap16,
                    HighlightButton(
                      focusNode: AppFocusNode(),
                      text: "取消",
                      onTap: Get.back,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
