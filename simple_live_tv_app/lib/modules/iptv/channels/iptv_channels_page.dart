import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
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
          _buildViewToggle(),
          AppStyle.vGap16,
          Obx(() => controller.browseBySource.value
              ? _buildSourceSelector()
              : _buildGroupSelector()),
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
        Text("IPTV直播", style: AppStyle.titleStyleWhite.copyWith(fontSize: 36.w, fontWeight: FontWeight.bold)),
        const Spacer(),
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

  /// 刷新按钮：源为日更，当日成功刷新后置灰为不可聚焦的提示块，次日自动恢复
  Widget _buildRefreshButton() {
    return Obx(() {
      final can = controller.canRefreshToday.value;
      if (can) {
        return HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.refresh,
          text: "刷新所有源",
          onTap: controller.onRefresh,
        );
      }
      final label = IptvService.instance.lastRefreshLabel;
      return Container(
        height: 64.w,
        padding: AppStyle.edgeInsetsH24,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: AppStyle.radius32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 40.w, color: Colors.white38),
            AppStyle.hGap12,
            Text(
              label.isEmpty ? "今日已更新" : "今日已更新 $label",
              style: TextStyle(fontSize: 28.w, color: Colors.white38),
            ),
          ],
        ),
      );
    });
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
                selected: !controller.browseBySource.value,
                onTap: () => controller.switchBrowseMode(false),
              )),
          AppStyle.hGap16,
          Obx(() => HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.travel_explore,
                text: "按来源",
                selected: controller.browseBySource.value,
                onTap: () => controller.switchBrowseMode(true),
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
    if (controller.channels.isEmpty) return Center(child: Text("暂无频道", style: AppStyle.textStyleWhite));
    return ListView.builder(
      padding: AppStyle.edgeInsetsH48,
      itemCount: controller.channels.length,
      itemBuilder: (_, index) => _buildChannelRow(controller.channels[index], index),
    );
  }

  /// 频道行：标题行 + 各源探活胶囊
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
            child: Obx(() => Wrap(
                  spacing: 12.w,
                  runSpacing: 8.w,
                  children: channel.lines.map((line) => _buildLineChip(line)).toList(),
                )),
          ),
        ],
      ),
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
  Widget _buildLineChip(IptvLine line) {
    final status = controller.lineStatus[line.url] ?? 0;
    final (dotColor, textColor) = switch (status) {
      1 => (Colors.green, Colors.greenAccent),
      2 => (Colors.amber, Colors.amberAccent),
      3 => (Colors.red, Colors.redAccent),
      _ => (Colors.grey, Colors.white38),
    };
    return Container(
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
          Text(line.sourceName, style: TextStyle(fontSize: 20.w, color: textColor)),
        ],
      ),
    );
  }
}
