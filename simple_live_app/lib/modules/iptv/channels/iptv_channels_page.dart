import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/services/iptv_service.dart';
import 'package:simple_live_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class IptvChannelsPage extends GetView<IptvChannelsController> {
  const IptvChannelsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 搜索态直接替换标题为输入框，不再占据头部一整行灰底
        title: Obx(() => controller.searchVisible.value
            ? TextField(
                controller: controller.searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: "搜索频道名或来源名",
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                onChanged: controller.setKeyword,
              )
            : const Text("IPTV直播")),
        actions: [
          _buildSearchToggle(),
          _buildRefreshButton(),
          IconButton(
            tooltip: "我的收藏",
            icon: const Icon(Icons.star_border),
            onPressed: controller.toggleFavoritesMode,
          ),
        ],
      ),
      body: Column(
        children: [
          // 头部区域：加底色与分隔线，滚动内容不会从选择条缝隙里透出来
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Column(
              children: [
                Obx(() {
                  if (controller.showFavorites.value) {
                    return _buildFavoriteTagBar();
                  }
                  if (controller.browseBySource.value) {
                    return _buildSourceSelector();
                  }
                  return _buildGroupSelector();
                }),
                Obx(() => controller.refreshing.value
                    ? _buildRefreshProgress()
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 搜索开关
  Widget _buildSearchToggle() {
    return Obx(() => IconButton(
          tooltip: "搜索频道或来源",
          icon: Icon(controller.searchVisible.value ? Icons.search_off : Icons.search),
          onPressed: controller.toggleSearch,
        ));
  }

  /// 刷新进度：列表保留，顶部细进度条 + 每源状态行
  Widget _buildRefreshProgress() {
    final service = IptvService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Obx(() => LinearProgressIndicator(
                  value: service.totalSourceCount.value == 0
                      ? null
                      : service.currentSourceIndex.value / service.totalSourceCount.value,
                  minHeight: 3,
                )),
          ),
          const SizedBox(height: 4),
          Obx(() => Text(
                service.loadingMessage.value,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              )),
        ],
      ),
    );
  }

  /// 刷新按钮：始终可点；当日已刷新过时点击会弹确认，建议制而非强制拦截
  Widget _buildRefreshButton() {
    return Obx(() {
      final label = IptvService.instance.lastRefreshLabel;
      return IconButton(
        tooltip: label.isEmpty
            ? "刷新所有源（公开源为日更，建议勿频繁刷新）"
            : "今日已更新（$label）；再次刷新会弹确认，避免给源站添堵",
        icon: const Icon(Icons.refresh),
        onPressed: controller.onRefresh,
      );
    });
  }

  /// 横向可滚动选择条（分组/来源/收藏标签共用样式），选中项自动居中；
  /// 桌面端无触摸，鼠标滚轮直接横向滚动
  Widget _buildSelectorBar({
    required ScrollController scrollController,
    required Map<String, GlobalKey> itemKeys,
    required List<Widget> items,
  }) {
    return Listener(
      onPointerSignal: (event) => _scrollHorizontally(scrollController, event),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: AppStyle.edgeInsetsH12,
          itemCount: items.length,
          separatorBuilder: (_, __) => AppStyle.hGap8,
          itemBuilder: (_, i) => items[i],
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
          items: [
            _buildGroupChip("", "全部"),
            ...controller.groups.map((g) => _buildGroupChip(g, g)),
          ],
        ));
  }

  Widget _buildGroupChip(String group, String name) {
    final key = controller.groupItemKeys.putIfAbsent(name, () => GlobalKey());
    final selected = controller.currentGroup.value == group;
    return OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(Get.context!).colorScheme.primary : null,
        foregroundColor: selected ? Colors.white : null,
      ),
      onPressed: () => controller.selectGroup(group),
      child: Text(name),
    );
  }

  Widget _buildSourceSelector() {
    return Obx(() => _buildSelectorBar(
          scrollController: controller.sourceScrollController,
          itemKeys: controller.sourceItemKeys,
          items: [
            _buildSourceChip("", "全部"),
            ...controller.sources.map((s) => _buildSourceChip(s, s)),
          ],
        ));
  }

  Widget _buildSourceChip(String source, String name) {
    final key = controller.sourceItemKeys.putIfAbsent(name, () => GlobalKey());
    final selected = controller.currentSource.value == source;
    return OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(Get.context!).colorScheme.primary : null,
        foregroundColor: selected ? Colors.white : null,
      ),
      onPressed: () => controller.selectSource(source),
      child: Text(name),
    );
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
          IconButton(
            tooltip: "退出收藏",
            icon: const Icon(Icons.close),
            onPressed: controller.toggleFavoritesMode,
          ),
          Expanded(
            child: Listener(
              onPointerSignal: (event) =>
                  _scrollHorizontally(controller.favoriteTagScrollController, event),
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  controller: controller.favoriteTagScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: AppStyle.edgeInsetsH12,
                  itemCount: tagItems.length,
                  separatorBuilder: (_, __) => AppStyle.hGap8,
                  itemBuilder: (_, i) => tagItems[i],
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _showTagManager,
            icon: const Icon(Icons.style, size: 18),
            label: const Text("标签管理"),
          ),
          AppStyle.hGap8,
        ],
      );
    });
  }

  Widget _buildTagChip(String tagId, String name) {
    final selected = controller.selectedTagId.value == tagId;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(Get.context!).colorScheme.primary : null,
        foregroundColor: selected ? Colors.white : null,
      ),
      onPressed: () => controller.selectTag(tagId),
      child: Text(name),
    );
  }

  /// 标签管理：新增、重命名、删除（对齐关注页的独立管理入口）
  Future<void> _showTagManager() async {
    await showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text("标签管理"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.tagNewController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: "新标签名称",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: "添加标签",
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final name = controller.tagNewController.text.trim();
                          if (name.isEmpty) return;
                          await IptvService.instance.createTag(name);
                          controller.tagNewController.clear();
                          controller.refreshTags();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: controller.tags
                          .map((t) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.style, size: 18),
                                title: Text(t.tag),
                                subtitle: Text("包含${t.favoriteIds.length}个收藏",
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "重命名",
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () async {
                                        final controller_ = TextEditingController(text: t.tag);
                                        final name = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("重命名标签"),
                                            content: TextField(controller: controller_),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Get.back(),
                                                child: const Text("取消"),
                                              ),
                                              FilledButton(
                                                onPressed: () => Get.back(result: controller_.text.trim()),
                                                child: const Text("保存"),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (name != null && name.isNotEmpty) {
                                          await IptvService.instance.renameTag(t, name);
                                          controller.refreshTags();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: "删除标签",
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () async {
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
                    ),
                  ),
                ],
              )),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("完成")),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.pageLoadding.value) {
        final service = IptvService.instance;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(service.loadingMessage.value),
              const SizedBox(height: 8),
              SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: service.totalSourceCount.value == 0
                      ? null
                      : service.currentSourceIndex.value / service.totalSourceCount.value,
                ),
              ),
            ],
          ),
        );
      }
      if (controller.showFavorites.value && controller.channels.isEmpty) {
        return const Center(child: Text("暂无收藏频道"));
      }
      if (!controller.showFavorites.value && controller.channels.isEmpty) {
        return const Center(child: Text("暂无频道"));
      }
      return ListView.builder(
        padding: AppStyle.edgeInsetsA12,
        itemCount: controller.channels.length,
        itemBuilder: (_, index) => controller.showFavorites.value
            ? _buildFavoriteItem(controller.channels[index], index)
            : _buildChannelItem(controller.channels[index], index),
      );
    });
  }

  /// 频道项：副标题展示分组、线路数、可用数与各源探活胶囊
  Widget _buildChannelItem(AggregatedChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    return Card(
      child: ListTile(
        leading: NetImage(channel.logo, width: 60, height: 60, borderRadius: 8, fit: BoxFit.contain),
        title: Text(channel.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final okCount = channel.lines
                  .where((l) => (controller.lineStatus[l.url] ?? 0) == 1 || (controller.lineStatus[l.url] ?? 0) == 2)
                  .length;
              final probedAny = channel.lines.any((l) {
                final s = controller.lineStatus[l.url] ?? 0;
                return s >= 1 && s <= 3;
              });
              final summary = probedAny
                  ? "${channel.group} · 共${channel.lines.length}条线路 · 可用$okCount条"
                  : "${channel.group} · 共${channel.lines.length}条线路";
              return Text(summary, style: const TextStyle(fontSize: 12));
            }),
            AppStyle.vGap4,
            // 渲染时按最新探活实时排序线路：绿前黄中红后，不依赖列表重建链路
            Obx(() {
              final sortedLines = channel.lines.toList()
                ..sort((a, b) =>
                    controller.lineRank(a.url).compareTo(controller.lineRank(b.url)));
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: sortedLines
                    .map((line) => _buildLineChip(line, _chipLabel(sortedLines, line)))
                    .toList(),
              );
            }),
          ],
        ),
        trailing: IconButton(
          icon: Icon(fav ? Icons.star : Icons.star_border),
          onPressed: () => controller.toggleFavorite(channel),
        ),
        onTap: () => controller.openPlayer(channel, index),
      ),
    );
  }

  /// 同源多条容灾线路时给胶囊附加序号，避免看起来重复；序号按当前显示顺序分配
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

  /// 收藏项：展示命中线路与来源，支持播放、打标签、取消收藏
  Widget _buildFavoriteItem(AggregatedChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    IptvFavorite? favItem;
    for (final e in controller.favorites) {
      if (channel.lines.any((l) => l.url == e.url)) {
        favItem = e;
        break;
      }
    }
    if (favItem == null) return const SizedBox.shrink();
    final item = favItem;
    return Card(
      child: ListTile(
        leading: NetImage(channel.logo, width: 60, height: 60, borderRadius: 8, fit: BoxFit.contain),
        title: Text(channel.name),
        subtitle: Text(
          "${channel.group} · 来源：${channel.sourceNames.join("、")}",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "设置标签",
              icon: const Icon(Icons.style, size: 20),
              onPressed: () => _showAssignTagsDialog(item),
            ),
            IconButton(
              tooltip: fav ? "取消收藏" : "收藏",
              icon: Icon(fav ? Icons.star : Icons.star_border),
              onPressed: () => controller.toggleFavorite(channel),
            ),
          ],
        ),
        onTap: () => controller.openPlayer(channel, index),
      ),
    );
  }

  /// 收藏打标对话框：勾选标签归属
  Future<void> _showAssignTagsDialog(IptvFavorite favItem) async {
    final service = IptvService.instance;
    await showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text("「${favItem.name}」的标签"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Obx(() {
            final tags = controller.tags;
            if (tags.isEmpty) return const Text("还没有标签，先到「标签管理」里新建");
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: tags
                  .map((t) => CheckboxListTile(
                        dense: true,
                        title: Text(t.tag),
                        value: t.favoriteIds.contains(favItem.id),
                        onChanged: (_) async {
                          await service.toggleFavoriteInTag(favItem.id, t);
                          controller.refreshTags();
                        },
                      ))
                  .toList(),
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("完成")),
        ],
      ),
    );
  }

  /// 线路探活胶囊：状态色淡底 + 圆点 + 源名称（同源多线路带序号），检测中显示微型进度
  Widget _buildLineChip(IptvLine line, String label) {
    final status = controller.lineStatus[line.url] ?? 0;
    final (dotColor, textColor) = switch (status) {
      1 => (Colors.green, Colors.green.shade800),
      2 => (Colors.amber, Colors.amber.shade900),
      3 => (Colors.red, Colors.red.shade700),
      _ => (Colors.grey, Colors.grey.shade700),
    };
    return Tooltip(
      message: line.url,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: dotColor.withAlpha(status == 0 ? 20 : 32),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dotColor.withAlpha(status == 0 ? 60 : 110)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 0)
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(strokeWidth: 1.4, color: dotColor),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            AppStyle.hGap4,
            Text(label, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
    );
  }
}
