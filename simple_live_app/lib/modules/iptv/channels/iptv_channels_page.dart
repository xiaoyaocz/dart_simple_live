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
          IconButton(
            tooltip: "刷新所有源",
            icon: const Icon(Icons.refresh),
            onPressed: controller.onRefresh,
          ),
          IconButton(
            tooltip: "我的收藏",
            icon: const Icon(Icons.star_border),
            onPressed: controller.toggleFavoritesMode,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGroupSelector(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 横向可滚动分组条，选中项自动居中
  Widget _buildGroupSelector() {
    return SizedBox(
      height: 48,
      child: Obx(
        () => ListView.separated(
          controller: controller.groupScrollController,
          scrollDirection: Axis.horizontal,
          padding: AppStyle.edgeInsetsH12,
          itemCount: controller.groups.length + 1,
          separatorBuilder: (_, __) => AppStyle.hGap8,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final group = isAll ? "" : controller.groups[i - 1];
            final name = isAll ? "全部" : group;
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
          },
        ),
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

  /// 频道项：副标题展示分组、线路数、所有源名称
  Widget _buildChannelItem(AggregatedChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    return Card(
      child: ListTile(
        leading: NetImage(channel.logo, width: 44, height: 44, borderRadius: 8),
        title: Text(channel.name),
        subtitle: Text(
          "${channel.group} · 共${channel.lines.length}条线路 · 来源：${channel.sourceNames.join("、")}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(fav ? Icons.star : Icons.star_border),
          onPressed: () => controller.toggleFavorite(channel),
        ),
        onTap: () => controller.openPlayer(channel, index),
      ),
    );
  }
}
