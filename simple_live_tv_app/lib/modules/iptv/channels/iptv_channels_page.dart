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
          _buildGroupSelector(),
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
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.refresh,
          text: "刷新所有源",
          onTap: controller.onRefresh,
        ),
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

  Widget _buildGroupSelector() {
    return SizedBox(
      height: 64.w,
      child: Obx(
        () => ListView.separated(
          controller: controller.groupScrollController,
          scrollDirection: Axis.horizontal,
          padding: AppStyle.edgeInsetsH48,
          itemCount: controller.groups.length + 1,
          separatorBuilder: (_, __) => AppStyle.hGap16,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final group = isAll ? "" : controller.groups[i - 1];
            final name = isAll ? "全部" : group;
            final key = controller.groupItemKeys.putIfAbsent(name, () => GlobalKey());
            final selected = controller.currentGroup.value == group;
            return HighlightButton(
              key: key,
              focusNode: AppFocusNode(),
              text: name,
              selected: selected,
              onTap: () => controller.selectGroup(group),
            );
          },
        ),
      ),
    );
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

  Widget _buildChannelRow(AggregatedChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: AppFocusNode(),
              leading: NetImage(channel.logo, width: 48.w, height: 48.w, borderRadius: 8),
              title: channel.name,
              subtitle: "${channel.group} · 共${channel.lines.length}条线路 · 来源：${channel.sourceNames.join("、")}",
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
    );
  }
}
