import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/models/db/follow_user_tag.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';

class FollowUserPage extends StatefulWidget {
  const FollowUserPage({super.key});

  @override
  State<FollowUserPage> createState() => _FollowUserPageState();
}

class _FollowUserPageState extends State<FollowUserPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, AppFocusNode> _focusNodes = <String, AppFocusNode>{};
  final AppFocusNode _pageFocusNode = AppFocusNode();

  /// 上一次触发封面补齐的发布修订号：避免每次重建都发起网络请求
  int _lastPreviewRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enterPage());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageFocusNode.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  Future<void> _enterPage() async {
    await FollowUserService.instance.onFollowPageEntered();
    _focusCurrentRoom();
  }

  AppFocusNode _focusNodeFor(String key) {
    return _focusNodes.putIfAbsent(key, AppFocusNode.new);
  }

  _TvFollowLayoutSpec _layoutSpec() {
    final style = AppSettingsController.instance.followDisplayStyle.value;
    final showLiveCover =
        AppSettingsController.instance.followShowLiveCover.value;
    if (style == "compact") {
      return _TvFollowLayoutSpec(
        displayStyle: AnchorCardDisplayStyle.compact,
        crossAxisCount: 4,
        mainAxisExtent: showLiveCover ? 178.w : 118.w,
        mainAxisSpacing: showLiveCover ? 20.w : 16.w,
        crossAxisSpacing: 24.w,
      );
    }
    if (style == "card") {
      return _TvFollowLayoutSpec(
        displayStyle: AnchorCardDisplayStyle.card,
        crossAxisCount: 2,
        // 卡片内容高度接近固定值，留足余量，避免设备字体缩放导致底部被裁切
        mainAxisExtent: showLiveCover ? 300.w : 268.w,
        mainAxisSpacing: 24.w,
        crossAxisSpacing: 28.w,
      );
    }
    return _TvFollowLayoutSpec(
      displayStyle: AnchorCardDisplayStyle.defaultList,
      crossAxisCount: 3,
      mainAxisExtent: showLiveCover ? 210.w : 140.w,
      mainAxisSpacing: showLiveCover ? 24.w : 18.w,
      crossAxisSpacing: 28.w,
    );
  }

  void _focusCurrentRoom() {
    final currentKey = CurrentRoomService.instance.currentKey;
    if (currentKey.isEmpty) {
      return;
    }
    final layout = _layoutSpec();
    final index = FollowUserService.instance.list
        .indexWhere((item) => "${item.siteId}_${item.roomId}" == currentKey);
    if (index < 0) {
      return;
    }
    final row = index ~/ layout.crossAxisCount;
    final targetOffset = row * (layout.mainAxisExtent + layout.mainAxisSpacing);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
    final item = FollowUserService.instance.list[index];
    _focusNodeFor(item.id).requestFocus();
  }

  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !FollowUserService.instance.paginationEnabled.value) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final altPressed = HardwareKeyboard.instance.isAltPressed;
    if (key == LogicalKeyboardKey.pageDown ||
        (altPressed && key == LogicalKeyboardKey.arrowRight)) {
      FollowUserService.instance.goToNextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp ||
        (altPressed && key == LogicalKeyboardKey.arrowLeft)) {
      FollowUserService.instance.goToPreviousPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Focus(
        autofocus: true,
        focusNode: _pageFocusNode,
        onKeyEvent: _handleShortcutKey,
        child: Column(
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
                  autofocus: true,
                  onTap: Get.back,
                ),
                AppStyle.hGap24,
                Text(
                  "我的关注",
                  style: AppStyle.titleStyleWhite.copyWith(
                    fontSize: 36.w,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppStyle.hGap24,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.search,
                  text: "搜索",
                  onTap: _showSearchDialog,
                ),
                AppStyle.hGap16,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.tune,
                  text: "显示/筛选",
                  onTap: _showDisplayDialog,
                ),
                AppStyle.hGap16,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.label_outline,
                  text: "标签",
                  onTap: _showTagDialog,
                ),
                const Spacer(),
                Obx(
                  () => HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.sync,
                    text: FollowUserService.instance.refreshTagLabel,
                    onTap: FollowUserService.instance.refreshAllStatus,
                  ),
                ),
                AppStyle.hGap24,
                AppStyle.hGap48,
              ],
            ),
            Obx(() => _buildActiveFilterBar()),
            Obx(() => _buildRefreshProgress()),
            AppStyle.vGap24,
            Expanded(
              child: Stack(
                children: [
                  Obx(() {
                    // 订阅发布修订号；取不可变快照供 GridView 使用
                    final revision =
                        FollowUserService.instance.dataRevision.value;
                    final layout = _layoutSpec();
                    final items = FollowUserService.instance.list
                        .toList(growable: false);
                    if (AppSettingsController
                            .instance.followShowLiveCover.value &&
                        !FollowUserService.instance.updating.value &&
                        revision != _lastPreviewRevision) {
                      _lastPreviewRevision = revision;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        unawaited(
                          FollowUserService.instance
                              .refreshVisiblePreviews(items),
                        );
                      });
                    }
                    return GridView.builder(
                      controller: _scrollController,
                      primary: false,
                      cacheExtent: 1200.w,
                      padding: EdgeInsets.only(
                        left: 48.w,
                        right: 48.w,
                        bottom:
                            FollowUserService.instance.paginationEnabled.value
                                ? 120.w
                                : 24.w,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: layout.crossAxisCount,
                        crossAxisSpacing: layout.crossAxisSpacing,
                        mainAxisSpacing: layout.mainAxisSpacing,
                        mainAxisExtent: layout.mainAxisExtent,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final isCurrent = "${item.siteId}_${item.roomId}" ==
                            CurrentRoomService.instance.currentKey;
                        return AnchorCard(
                          face: item.face,
                          name: item.userName,
                          roomTitle: item.roomTitle,
                          roomCover: item.roomCover,
                          siteId: item.siteId,
                          liveStatus: item.liveStatus.value,
                          roomId: item.roomId,
                          playing: isCurrent,
                          showLiveCover: AppSettingsController
                              .instance.followShowLiveCover.value,
                          displayStyle: layout.displayStyle,
                          autofocus: isCurrent,
                          focusNode: _focusNodeFor(item.id),
                          onTap: () async {
                            final resolved = await FollowUserService.instance
                                .resolveFollowBeforeEnter(item);
                            final site = Sites.allSites[resolved.siteId];
                            if (site == null) {
                              return;
                            }
                            AppNavigator.toLiveRoomDetail(
                              site: site,
                              roomId: resolved.roomId,
                            );
                          },
                        );
                      },
                    );
                  }),
                  Obx(
                    () => FollowUserService.instance.paginationEnabled.value
                        ? Positioned(
                            left: 48.w,
                            right: 48.w,
                            bottom: 24.w,
                            child: _buildFloatingPaginationBar(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar() {
    final settings = AppSettingsController.instance;
    final labels = <String>[
      "样式：${_displayStyleLabel(settings.followDisplayStyle.value)}",
      if (FollowUserService.instance.selectedTagName.value !=
          FollowUserService.allTagName)
        "标签：${FollowUserService.instance.selectedTagName.value}",
      if (settings.followOnlyLive.value) "仅显示开播",
      if (settings.followRefreshOnEnter.value) "进页刷新",
      if (FollowUserService.instance.searchKeyword.value.isNotEmpty)
        "搜索：${FollowUserService.instance.searchKeyword.value}",
    ];
    if (labels.length == 1 &&
        labels.first ==
            "样式：${_displayStyleLabel(settings.followDisplayStyle.value)}") {
      return Padding(
        padding: EdgeInsets.only(top: 16.w, left: 48.w, right: 48.w),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            labels.first,
            style: AppStyle.subTextStyleWhite,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 16.w, left: 48.w, right: 48.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 10.w,
          runSpacing: 10.w,
          children: labels
              .map(
                (label) => Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.w),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(label, style: AppStyle.subTextStyleWhite),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _displayStyleLabel(String value) {
    switch (value) {
      case "compact":
        return "紧凑";
      case "card":
        return "卡片";
      default:
        return "默认";
    }
  }

  Future<void> _showSearchDialog() async {
    final result = await Utils.showEditTextDialog(
      FollowUserService.instance.searchKeyword.value,
      title: "搜索主播",
      hintText: "只按主播名字本地搜索",
      confirm: "搜索",
      validate: (_) => true,
    );
    if (result == null) {
      return;
    }
    FollowUserService.instance.setSearchKeyword(result);
  }

  void _showTagDialog() {
    Utils.showSystemRightDialog(
      width: 760.w,
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsA24,
          children: [
            Text("关注标签", style: AppStyle.titleStyleWhite),
            AppStyle.vGap24,
            Wrap(
              spacing: 16.w,
              runSpacing: 16.w,
              children: FollowUserService.instance.tagOptions
                  .map(
                    (tag) => HighlightButton(
                      focusNode: AppFocusNode(),
                      iconData: tag == FollowUserService.allTagName
                          ? Icons.all_inclusive
                          : Icons.label_outline,
                      text: tag,
                      selected:
                          FollowUserService.instance.selectedTagName.value ==
                              tag,
                      onTap: () {
                        FollowUserService.instance.setSelectedTagName(tag);
                        Get.back();
                      },
                    ),
                  )
                  .toList(),
            ),
            AppStyle.vGap24,
            Text("标签管理", style: AppStyle.titleStyleWhite.copyWith(fontSize: 26.w)),
            AppStyle.vGap16,
            Wrap(
              spacing: 16.w,
              runSpacing: 16.w,
              children: [
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.add,
                  text: "新增标签",
                  onTap: _showAddTagDialog,
                ),
              ],
            ),
            AppStyle.vGap16,
            ...FollowUserService.instance.followTagList
                .map((tag) => _buildTagManageRow(tag))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTagManageRow(FollowUserTag tag) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${tag.tag}（${tag.userId.length}）",
              style: AppStyle.textStyleWhite,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.playlist_add,
            text: "添加关注",
            onTap: () => _showFollowPickerForTag(tag),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.edit,
            text: "改名",
            onTap: () => _showRenameTagDialog(tag),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.delete_outline,
            text: "删除",
            onTap: () => _showDeleteTagDialog(tag),
          ),
        ],
      ),
    );
  }

  /// 批量把已有关注加入标签：多选关注后一次性加入
  Future<void> _showFollowPickerForTag(FollowUserTag tag) async {
    final candidates = FollowUserService.instance.allList
        .where((item) => item.tag.trim() != tag.tag.trim())
        .toList();
    if (candidates.isEmpty) {
      SmartDialog.showToast("该标签已包含全部关注");
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
              Text("添加关注到「${tag.tag}」", style: AppStyle.titleStyleWhite),
              AppStyle.vGap16,
              Text(
                "点按选择或取消，可多选（已在该标签内的不会显示）",
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
                        : () async {
                            final added = await FollowUserService.instance
                                .moveFollowsToTag(
                              selected.toList(),
                              tag,
                            );
                            SmartDialog.showToast(
                              "已添加 $added 个关注到「${tag.tag}」",
                            );
                            Get.back();
                            Get.back();
                            _showTagDialog();
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

  Future<void> _showAddTagDialog() async {
    final result = await Utils.showEditTextDialog(
      "",
      title: "新增标签",
      hintText: "最多${DBService.followTagMaxLength}个字符",
      confirm: "添加",
      validate: (e) => e.trim().length <= DBService.followTagMaxLength,
    );
    if (result == null) {
      return;
    }
    await FollowUserService.instance.addTag(result);
  }

  Future<void> _showRenameTagDialog(FollowUserTag tag) async {
    final result = await Utils.showEditTextDialog(
      tag.tag,
      title: "修改标签名",
      hintText: "最多${DBService.followTagMaxLength}个字符",
      confirm: "确定",
      validate: (e) => e.trim().length <= DBService.followTagMaxLength,
    );
    if (result == null) {
      return;
    }
    await FollowUserService.instance.renameTag(tag, result);
    Get.back();
    _showTagDialog();
  }

  Future<void> _showDeleteTagDialog(FollowUserTag tag) async {
    final result = await Utils.showAlertDialog(
      "确定删除标签“${tag.tag}”吗？\n该标签下的关注将移回“${FollowUserService.allTagName}”。",
      title: "删除标签",
    );
    if (!result) {
      return;
    }
    await FollowUserService.instance.deleteTag(tag);
    Get.back();
    _showTagDialog();
  }

  void _showDisplayDialog() {
    Utils.showSystemRightDialog(
      width: 760.w,
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsA24,
          children: [
            Text("显示与筛选", style: AppStyle.titleStyleWhite),
            AppStyle.vGap24,
            Text(
              "显示样式",
              style: AppStyle.titleStyleWhite.copyWith(fontSize: 26.w),
            ),
            AppStyle.vGap16,
            Wrap(
              spacing: 16.w,
              runSpacing: 16.w,
              children: [
                _buildStyleButton("default", "默认"),
                _buildStyleButton("compact", "紧凑"),
                _buildStyleButton("card", "卡片"),
              ],
            ),
            AppStyle.vGap32,
            Text(
              "直播封面",
              style: AppStyle.titleStyleWhite.copyWith(fontSize: 26.w),
            ),
            AppStyle.vGap16,
            _buildToggleButton(
              label: AppSettingsController.instance.followShowLiveCover.value
                  ? "展示直播封面：开"
                  : "展示直播封面：关",
              onTap: () {
                FollowUserService.instance.setShowLiveCover(
                  !AppSettingsController.instance.followShowLiveCover.value,
                );
              },
            ),
            AppStyle.vGap32,
            Text(
              "筛选",
              style: AppStyle.titleStyleWhite.copyWith(fontSize: 26.w),
            ),
            AppStyle.vGap16,
            _buildToggleButton(
              label: AppSettingsController.instance.followOnlyLive.value
                  ? "仅显示开播：开"
                  : "仅显示开播：关",
              onTap: () {
                FollowUserService.instance.setOnlyLive(
                  !AppSettingsController.instance.followOnlyLive.value,
                );
              },
            ),
            AppStyle.vGap16,
            _buildToggleButton(
              label: FollowUserService.instance.searchKeyword.value.isEmpty
                  ? "清除搜索：当前无关键字"
                  : "清除搜索：${FollowUserService.instance.searchKeyword.value}",
              onTap: FollowUserService.instance.clearSearchKeyword,
            ),
            AppStyle.vGap32,
            Text(
              "进入关注页时刷新",
              style: AppStyle.titleStyleWhite.copyWith(fontSize: 26.w),
            ),
            AppStyle.vGap16,
            Text(
              "这是进页刷新，不是定时刷新。开启后，每次进入关注页会先显示本地列表，再异步刷新一次关注状态；关注过多时可能触发抖音限制。",
              style: AppStyle.subTextStyleWhite,
            ),
            AppStyle.vGap16,
            _buildToggleButton(
              label: AppSettingsController.instance.followRefreshOnEnter.value
                  ? "进入关注页时刷新：开"
                  : "进入关注页时刷新：关",
              onTap: () async {
                final current =
                    AppSettingsController.instance.followRefreshOnEnter.value;
                if (!current) {
                  final confirmed = await Utils.showAlertDialog(
                    "这是进页刷新，不是十分钟定时刷新。开启后，每次进入关注页都会先显示本地列表，再异步刷新一次关注状态；关注过多时可能触发抖音限制。",
                    title: "风险提示",
                    confirm: "继续开启",
                  );
                  if (!confirmed) {
                    return;
                  }
                }
                FollowUserService.instance.setRefreshOnEnter(!current);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleButton(String value, String label) {
    final selected =
        AppSettingsController.instance.followDisplayStyle.value == value;
    return HighlightButton(
      focusNode: AppFocusNode(),
      text: label,
      selected: selected,
      onTap: () {
        FollowUserService.instance.setDisplayStyle(value);
      },
    );
  }

  Widget _buildToggleButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return HighlightButton(
      focusNode: AppFocusNode(),
      text: label,
      onTap: onTap,
    );
  }

  Widget _buildFloatingPaginationBar() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: AppStyle.radius16,
          border: Border.all(color: Colors.white24),
        ),
        child: Obx(
          () => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.chevron_left,
                text: "上一页",
                onTap: FollowUserService.instance.currentDisplayPage.value > 1
                    ? FollowUserService.instance.goToPreviousPage
                    : null,
              ),
              AppStyle.hGap16,
              Text(
                "${FollowUserService.instance.currentDisplayPage.value}/${FollowUserService.instance.totalDisplayPages.value}",
                style: AppStyle.textStyleWhite.copyWith(fontSize: 28.w),
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.chevron_right,
                text: "下一页",
                onTap: FollowUserService.instance.currentDisplayPage.value <
                        FollowUserService.instance.totalDisplayPages.value
                    ? FollowUserService.instance.goToNextPage
                    : null,
              ),
              AppStyle.hGap16,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.refresh,
                text: "刷新当前页",
                onTap: FollowUserService.instance.refreshCurrentPageStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshProgress() {
    final progress = FollowUserService.instance.refreshProgress.value;
    if (!progress.active) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: 12.w, left: 48.w, right: 48.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.w),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(progress.automatic ? 120 : 160),
          borderRadius: AppStyle.radius16,
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.stage,
                    style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                  ),
                ),
                Text(
                  "${progress.resolvedCount}/${progress.total}",
                  style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                ),
              ],
            ),
            if (progress.detail.isNotEmpty) ...[
              AppStyle.vGap8,
              Text(
                progress.detail,
                style: AppStyle.textStyleWhite.copyWith(fontSize: 20.w),
              ),
            ],
            AppStyle.vGap12,
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.total > 0 ? progress.percent : null,
                minHeight: 8.w,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.lightGreenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvFollowLayoutSpec {
  final AnchorCardDisplayStyle displayStyle;
  final int crossAxisCount;
  final double mainAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const _TvFollowLayoutSpec({
    required this.displayStyle,
    required this.crossAxisCount,
    required this.mainAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
  });
}
