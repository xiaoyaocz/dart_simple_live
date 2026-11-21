import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
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
        title: const Text("IPTV直播"),
        actions: [
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
          _buildViewToggle(),
          Obx(() => controller.browseBySource.value
              ? _buildSourceSelector()
              : _buildGroupSelector()),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 刷新按钮：源为日更，当日成功刷新后置灰，次日自动恢复
  Widget _buildRefreshButton() {
    return Obx(() {
      final can = controller.canRefreshToday.value;
      final label = IptvService.instance.lastRefreshLabel;
      return IconButton(
        tooltip: can
            ? "刷新所有源（公开源为日更，今日刷新后按钮置灰）"
            : "今日已更新（$label），明日可再刷新",
        icon: const Icon(Icons.refresh),
        onPressed: can ? controller.onRefresh : null,
      );
    });
  }

  /// 浏览维度切换：按分组 / 按来源
  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Obx(() => SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.category_outlined, size: 18),
                    label: Text("按分组"),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.travel_explore, size: 18),
                    label: Text("按来源"),
                  ),
                ],
                selected: {controller.browseBySource.value},
                onSelectionChanged: (selection) =>
                    controller.switchBrowseMode(selection.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              )),
        ],
      ),
    );
  }

  /// 横向可滚动选择条（分组/来源共用样式），选中项自动居中
  Widget _buildSelectorBar({
    required ScrollController scrollController,
    required Map<String, GlobalKey> itemKeys,
    required List<String> items,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: AppStyle.edgeInsetsH12,
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => AppStyle.hGap8,
        itemBuilder: (_, i) {
          final isAll = i == 0;
          final value = isAll ? "" : items[i - 1];
          final name = isAll ? "全部" : value;
          final key = itemKeys.putIfAbsent(name, () => GlobalKey());
          final selected = current == value;
          return OutlinedButton(
            key: key,
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? Theme.of(Get.context!).colorScheme.primary : null,
              foregroundColor: selected ? Colors.white : null,
            ),
            onPressed: () => onSelect(value),
            child: Text(name),
          );
        },
      ),
    );
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
      if (controller.showFavorites.value) {
        return const Center(child: Text("收藏列表"));
      }
      if (controller.channels.isEmpty) {
        return const Center(child: Text("暂无频道"));
      }
      return ListView.builder(
        padding: AppStyle.edgeInsetsA12,
        itemCount: controller.channels.length,
        itemBuilder: (_, index) => _buildChannelItem(controller.channels[index], index),
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
            Obx(() => Wrap(
              spacing: 8,
              runSpacing: 4,
              children: channel.lines.map((line) => _buildLineChip(line)).toList(),
            )),
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

  /// 线路探活胶囊：状态色淡底 + 圆点 + 源名称，检测中显示微型进度
  Widget _buildLineChip(IptvLine line) {
    final status = controller.lineStatus[line.url] ?? 0;
    final (dotColor, textColor) = switch (status) {
      1 => (Colors.green, Colors.green.shade800),
      2 => (Colors.amber, Colors.amber.shade900),
      3 => (Colors.red, Colors.red.shade700),
      _ => (Colors.grey, Colors.grey.shade700),
    };
    return Container(
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
          Text(line.sourceName, style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }
}
