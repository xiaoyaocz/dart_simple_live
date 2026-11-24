import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_tv_app/models/db/iptv_tag.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/app_text_field.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class IptvChannelsPage extends GetView<IptvChannelsController> {
  const IptvChannelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStyle.vGap32,
          _buildHeader(),
          AppStyle.vGap16,
          // 头部区域：底部分隔线，滚动内容不会从选择条缝隙里透出来
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => controller.searchVisible.value
                    ? _buildSearchBar()
                    : const SizedBox.shrink()),
                AppStyle.vGap16,
                Obx(() {
                  if (controller.showFavorites.value) {
                    return _buildFavoriteTagBar();
                  }
                  return _buildViewToggle();
                }),
                AppStyle.vGap16,
                Obx(() => controller.showFavorites.value || controller.browseBySource.value
                    ? const SizedBox.shrink()
                    : _buildGroupSelector()),
                Obx(() => controller.showFavorites.value
                    ? const SizedBox.shrink()
                    : (controller.browseBySource.value
                        ? _buildSourceSelector()
                        : const SizedBox.shrink())),
                Obx(() => controller.refreshing.value
                    ? _buildRefreshProgress()
                    : const SizedBox.shrink()),
                AppStyle.vGap16,
              ],
            ),
          ),
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
        Text("IPTV直播", style: AppStyle.titleStyleWhite.copyWith(fontSize: 36.w, fontWeight: FontWeight.bold)),
        const Spacer(),
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: controller.searchVisible.value ? Icons.search_off : Icons.search,
          text: "搜索",
          onTap: controller.toggleSearch,
        ),
        AppStyle.hGap16,
        _buildRefreshButton(),
        AppStyle.hGap16,
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.star_border,
          text: "我的收藏",
          onTap: controller.toggleFavoritesMode,
        ),
        AppStyle.hGap48,
      ],
    );
  }

  /// 搜索框：本地匹配频道名或来源名
  Widget _buildSearchBar() {
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: controller.searchController,
              hintText: "搜索频道名或来源名",
              onSubmitted: controller.setKeyword,
            ),
          ),
          AppStyle.hGap16,
          HighlightButton(
            focusNode: AppFocusNode(),
            text: "清空",
            onTap: () {
              controller.searchController.clear();
              controller.setKeyword("");
            },
          ),
        ],
      ),
    );
  }

  /// 刷新按钮：始终可点；当日已刷新过时点击会弹确认，建议制而非强制拦截
  Widget _buildRefreshButton() {
    return Obx(() {
      final label = IptvService.instance.lastRefreshLabel;
      return HighlightButton(
        focusNode: AppFocusNode(),
        iconData: Icons.refresh,
        text: label.isEmpty ? "刷新所有源" : "已更新 $label",
        onTap: controller.onRefresh,
      );
    });
  }

  /// 刷新进度：列表保留，细进度条 + 每源状态行
  Widget _buildRefreshProgress() {
    final service = IptvService.instance;
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => LinearProgressIndicator(
                value: service.totalSourceCount.value == 0
                    ? null
                    : service.currentSourceIndex.value / service.totalSourceCount.value,
                minHeight: 4.w,
              )),
          AppStyle.vGap8,
          Obx(() => Text(
                service.loadingMessage.value,
                style: AppStyle.textStyleWhite.copyWith(fontSize: 20.w, color: Colors.white54),
              )),
        ],
      ),
    );
  }

  /// 浏览维度切换：按分组 / 按来源
  Widget _buildViewToggle() {
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: Row(
        children: [
          Obx(() => HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.category_outlined,
                text: "按分组",
                selected: !controller.browseBySource.value && !controller.showFavorites.value,
                onTap: () => controller.switchBrowseMode(false),
              )),
          AppStyle.hGap16,
          Obx(() => HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.travel_explore,
                text: "按来源",
                selected: controller.browseBySource.value && !controller.showFavorites.value,
                onTap: () => controller.switchBrowseMode(true),
              )),
        ],
      ),
    );
  }

  /// 横向可滚动选择条（分组/来源共用样式），选中项自动居中；TV-Windows 支持滚轮横滚
  Widget _buildSelectorBar({
    required ScrollController scrollController,
    required Map<String, GlobalKey> itemKeys,
    required List<String> items,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    return Listener(
      onPointerSignal: (event) => _scrollHorizontally(scrollController, event),
      child: SizedBox(
        height: 64.w,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: AppStyle.edgeInsetsH48,
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => AppStyle.hGap16,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final value = isAll ? "" : items[i - 1];
            final name = isAll ? "全部" : value;
            final key = itemKeys.putIfAbsent(name, () => GlobalKey());
            final selected = current == value;
            return HighlightButton(
              key: key,
              focusNode: AppFocusNode(),
              text: name,
              selected: selected,
              onTap: () => onSelect(value),
            );
          },
        ),
      ),
    );
  }

  /// 鼠标滚轮转横向滚动
  void _scrollHorizontally(ScrollController scrollController, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) return;
    final target = (scrollController.offset + event.scrollDelta.dy)
        .clamp(0.0, position.maxScrollExtent);
    scrollController.jumpTo(target);
  }

  Widget _buildGroupSelector() {
    return Obx(() => _buildSelectorBar(
          scrollController: controller.groupScrollController,
          itemKeys: controller.groupItemKeys,
          items: controller.groups,
          current: controller.currentGroup.value,
          onSelect: controller.selectGroup,
        ));
  }

  Widget _buildSourceSelector() {
    return Obx(() => _buildSelectorBar(
          scrollController: controller.sourceScrollController,
          itemKeys: controller.sourceItemKeys,
          items: controller.sources,
          current: controller.currentSource.value,
          onSelect: controller.selectSource,
        ));
  }

  /// 收藏模式顶栏：退出按钮 + 标签筛选条 + 标签管理入口
  Widget _buildFavoriteTagBar() {
    return Obx(() {
      final tagItems = <Widget>[
        _buildTagChip(IptvChannelsController.allTagId, "全部"),
        _buildTagChip(IptvChannelsController.ungroupedTagId, "未分组"),
        ...controller.tags.map((t) => _buildTagChip(t.id, t.tag)),
      ];
      return Row(
        children: [
          AppStyle.hGap48,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.close,
            text: "退出收藏",
            onTap: controller.toggleFavoritesMode,
          ),
          AppStyle.hGap16,
          Expanded(
            child: Listener(
              onPointerSignal: (event) =>
                  _scrollHorizontally(controller.favoriteTagScrollController, event),
              child: SizedBox(
                height: 64.w,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: AppStyle.edgeInsetsH48,
                  itemCount: tagItems.length,
                  separatorBuilder: (_, __) => AppStyle.hGap16,
                  itemBuilder: (_, i) => tagItems[i],
                ),
              ),
            ),
          ),
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.style,
            text: "标签管理",
            onTap: _showTagManager,
          ),
          AppStyle.hGap48,
        ],
      );
    });
  }

  Widget _buildTagChip(String tagId, String name) {
    final selected = controller.selectedTagId.value == tagId;
    return HighlightButton(
      focusNode: AppFocusNode(),
      text: name,
      selected: selected,
      onTap: () => controller.selectTag(tagId),
    );
  }

  /// 标签管理：新增、重命名、删除（对齐关注页的独立管理入口）
  Future<void> _showTagManager() async {
    await Utils.showSystemRightDialog(
      width: 700.w,
      child: Padding(
        padding: AppStyle.edgeInsetsA32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "标签管理",
              style: AppStyle.titleStyleWhite.copyWith(fontSize: 32.w, fontWeight: FontWeight.bold),
            ),
            AppStyle.vGap24,
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: controller.tagNewController,
                    hintText: "新标签名称",
                  ),
                ),
                AppStyle.hGap16,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.add_circle_outline,
                  text: "添加",
                  onTap: () async {
                    final name = controller.tagNewController.text.trim();
                    if (name.isEmpty) return;
                    await IptvService.instance.createTag(name);
                    controller.tagNewController.clear();
                    controller.refreshTags();
                  },
                ),
              ],
            ),
            AppStyle.vGap24,
            Flexible(
              child: Obx(() => ListView(
                    shrinkWrap: true,
                    children: controller.tags
                        .map((t) => Padding(
                              padding: EdgeInsets.only(bottom: 12.w),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${t.tag}（包含${t.favoriteIds.length}个收藏）",
                                      style: AppStyle.textStyleWhite.copyWith(fontSize: 26.w),
                                    ),
                                  ),
                                  HighlightButton(
                                    focusNode: AppFocusNode(),
                                    iconData: Icons.edit_outlined,
                                    text: "重命名",
                                    onTap: () => _renameTag(t),
                                  ),
                                  AppStyle.hGap12,
                                  HighlightButton(
                                    focusNode: AppFocusNode(),
                                    iconData: Icons.delete_outline,
                                    text: "删除",
                                    onTap: () async {
                                      await IptvService.instance.deleteTag(t);
                                      if (controller.selectedTagId.value == t.id) {
                                        controller.selectTag(IptvChannelsController.allTagId);
                                      }
                                      controller.refreshTags();
                                    },
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  /// 重命名标签
  Future<void> _renameTag(IptvTag tag) async {
    final name = await Utils.showEditTextDialog(
      tag.tag,
      title: "重命名标签",
      validate: (text) => text.trim().isNotEmpty,
    );
    if (name != null && name.trim().isNotEmpty) {
      await IptvService.instance.renameTag(tag, name.trim());
      controller.refreshTags();
    }
  }

  Widget _buildBody() {
    if (controller.pageLoadding.value) {
      final service = IptvService.instance;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 50.w, height: 50.w, child: CircularProgressIndicator(strokeWidth: 3.w)),
            AppStyle.vGap32,
            Text(service.loadingMessage.value, style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w)),
            AppStyle.vGap16,
            SizedBox(
              width: 400.w,
              child: LinearProgressIndicator(
                value: service.totalSourceCount.value == 0
                    ? null : service.currentSourceIndex.value / service.totalSourceCount.value,
                minHeight: 8.w,
              ),
            ),
          ],
        ),
      );
    }
    if (controller.channels.isEmpty) {
      return Center(
        child: Text(
          controller.showFavorites.value ? "暂无收藏频道" : "暂无频道",
          style: AppStyle.textStyleWhite,
        ),
      );
    }
    return ListView.builder(
      padding: AppStyle.edgeInsetsH48,
      itemCount: controller.channels.length,
      itemBuilder: (_, index) => controller.showFavorites.value
          ? _buildFavoriteRow(controller.channels[index], index)
          : _buildChannelRow(controller.channels[index], index),
    );
  }

  /// 频道行：标题行 + 各源探活胶囊（同源多线路带序号）
  Widget _buildChannelRow(AggregatedChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: HighlightListTile(
                  focusNode: AppFocusNode(),
                  leading: NetImage(channel.logo, width: 48.w, height: 48.w, borderRadius: 8),
                  title: channel.name,
                  subtitle: _channelSummary(channel),
                  onTap: () => controller.openPlayer(channel, index),
                ),
              ),
              AppStyle.hGap12,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: fav ? Icons.star : Icons.star_border,
                text: fav ? "已收藏" : "收藏",
                onTap: () => controller.toggleFavorite(channel),
              ),
            ],
          ),
          AppStyle.vGap8,
          Padding(
            padding: EdgeInsets.only(left: 24.w),
            // 渲染时按最新探活实时排序线路：绿前黄中红后
            child: Obx(() {
              final sortedLines = channel.lines.toList()
                ..sort((a, b) =>
                    controller.lineRank(a.url).compareTo(controller.lineRank(b.url)));
              return Wrap(
                spacing: 12.w,
                runSpacing: 8.w,
                children: sortedLines
                    .map((line) => _buildLineChip(line, _chipLabel(sortedLines, line)))
                    .toList(),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 同源多条容灾线路时给胶囊附加序号；序号按当前显示顺序分配
  String _chipLabel(List<IptvLine> lines, IptvLine line) {
    final counts = <String, int>{};
    for (final l in lines) {
      counts[l.sourceName] = (counts[l.sourceName] ?? 0) + 1;
    }
    if ((counts[line.sourceName] ?? 0) <= 1) return line.sourceName;
    var n = 0;
    for (final l in lines) {
      if (l.sourceName != line.sourceName) continue;
      n++;
      if (identical(l, line)) break;
    }
    return "${line.sourceName} ·$n";
  }

  /// 收藏行：来源信息 + 打标签 + 取消收藏
  Widget _buildFavoriteRow(AggregatedChannel channel, int index) {
    IptvFavorite? favItem;
    for (final e in controller.favorites) {
      if (channel.lines.any((l) => l.url == e.url)) {
        favItem = e;
        break;
      }
    }
    if (favItem == null) return const SizedBox.shrink();
    final item = favItem;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: AppFocusNode(),
              leading: NetImage(channel.logo, width: 48.w, height: 48.w, borderRadius: 8),
              title: channel.name,
              subtitle: "${channel.group} · 来源：${channel.sourceNames.join("、")}",
              onTap: () => controller.openPlayer(channel, index),
            ),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.style,
            text: "标签",
            onTap: () => _showAssignTagsDialog(item),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.star,
            text: "取消收藏",
            onTap: () => controller.toggleFavorite(channel),
          ),
        ],
      ),
    );
  }

  /// 收藏打标对话框：勾选标签归属
  Future<void> _showAssignTagsDialog(IptvFavorite favItem) async {
    final service = IptvService.instance;
    await Utils.showSystemRightDialog(
      width: 700.w,
      child: Obx(() {
        final tags = controller.tags;
        return Padding(
          padding: AppStyle.edgeInsetsA32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "「${favItem.name}」的标签",
                style: AppStyle.titleStyleWhite.copyWith(fontSize: 32.w, fontWeight: FontWeight.bold),
              ),
              AppStyle.vGap24,
              if (tags.isEmpty)
                Text("还没有标签，先到「标签管理」里新建", style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w)),
              ...tags.map((t) => Padding(
                    padding: EdgeInsets.only(bottom: 12.w),
                    child: HighlightButton(
                      focusNode: AppFocusNode(),
                      iconData: t.favoriteIds.contains(favItem.id)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      text: t.tag,
                      selected: t.favoriteIds.contains(favItem.id),
                      onTap: () async {
                        await service.toggleFavoriteInTag(favItem.id, t);
                        controller.refreshTags();
                      },
                    ),
                  )),
            ],
          ),
        );
      }),
    );
  }

  /// 频道摘要：分组、线路数，探测后附可用线路数
  String _channelSummary(AggregatedChannel channel) {
    final summary = "${channel.group} · 共${channel.lines.length}条线路";
    final okCount = channel.lines
        .where((l) => (controller.lineStatus[l.url] ?? 0) == 1 || (controller.lineStatus[l.url] ?? 0) == 2)
        .length;
    final probedAny = channel.lines.any((l) {
      final s = controller.lineStatus[l.url] ?? 0;
      return s >= 1 && s <= 3;
    });
    return probedAny ? "$summary · 可用$okCount条" : summary;
  }

  /// 线路探活胶囊：状态色淡底 + 圆点 + 源名称，检测中显示微型进度
  Widget _buildLineChip(IptvLine line, String label) {
    final status = controller.lineStatus[line.url] ?? 0;
    final (dotColor, textColor) = switch (status) {
      1 => (Colors.green, Colors.greenAccent),
      2 => (Colors.amber, Colors.amberAccent),
      3 => (Colors.red, Colors.redAccent),
      _ => (Colors.grey, Colors.white38),
    };
    return Tooltip(
      message: line.url,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.w),
        decoration: BoxDecoration(
          color: dotColor.withAlpha(status == 0 ? 20 : 32),
          borderRadius: BorderRadius.circular(24.w),
          border: Border.all(color: dotColor.withAlpha(status == 0 ? 60 : 110)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 0)
              SizedBox(
                width: 12.w,
                height: 12.w,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: dotColor),
              )
            else
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            AppStyle.hGap8,
            Text(label, style: TextStyle(fontSize: 20.w, color: textColor)),
          ],
        ),
      ),
    );
  }
}
