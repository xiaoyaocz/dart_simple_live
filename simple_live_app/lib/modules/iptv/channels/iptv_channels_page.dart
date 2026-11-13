import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/models/db/iptv_favorite.dart';
import 'package:simple_live_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_app/services/iptv_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class IptvChannelsPage extends GetView<IptvChannelsController> {
  const IptvChannelsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => controller.searching.value
              ? TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "搜索频道名称",
                  ),
                  onChanged: controller.setKeyword,
                )
              : const Text("IPTV"),
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip: "搜索",
              onPressed: () {
                controller.searching.value = !controller.searching.value;
                if (!controller.searching.value) controller.setKeyword("");
              },
              icon: Icon(
                controller.searching.value ? Icons.close : Icons.search,
              ),
            ),
          ),
          Obx(
            () => IconButton(
              tooltip: "我的收藏",
              onPressed: controller.toggleFavoritesMode,
              icon: Icon(
                controller.showFavorites.value
                    ? Icons.star
                    : Icons.star_border,
              ),
            ),
          ),
          IconButton(
            tooltip: "订阅源管理",
            onPressed: controller.goManage,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: Obx(() => _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.pageLoadding.value) {
      return Center(
        child: Padding(
          padding: AppStyle.edgeInsetsA24,
          child: Obx(() {
            final service = IptvService.instance;
            final progress = (service.currentSourceIndex.value + 1) /
                service.totalSourceCount.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                AppStyle.vGap24,
                SizedBox(
                  width: 280,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                  ),
                ),
                AppStyle.vGap12,
                Text(
                  service.loadingMessage.value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }),
        ),
      );
    }
    if (controller.showFavorites.value) {
      return _buildFavorites(context);
    }
    if (controller.playlists.isEmpty) {
      return _buildEmpty(context);
    }
    if (controller.pageError.value) {
      return _buildError(context);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPlaylistSelector(context),
        _buildGroupSelector(context),
        Expanded(child: _buildChannelList(context)),
      ],
    );
  }

  // 订阅源横向选择
  Widget _buildPlaylistSelector(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: true,
          physics: const BouncingScrollPhysics(),
        ),
        child: ListView.separated(
          controller: controller.playlistScrollController,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppStyle.edgeInsetsH12,
          itemCount: controller.playlists.length,
          separatorBuilder: (_, __) => AppStyle.hGap8,
          itemBuilder: (_, index) {
            final item = controller.playlists[index];
            final key = controller.playlistItemKeys.putIfAbsent(item.id, () => GlobalKey());
            return Center(
              key: key,
              child: FilterButton(
                text: item.name,
                selected: controller.currentPlaylist.value?.id == item.id,
                onTap: () => controller.selectPlaylist(item),
              ),
            );
          },
        ),
      ),
    );
  }

  // 分组横向选择
  Widget _buildGroupSelector(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: true,
          physics: const BouncingScrollPhysics(),
        ),
        child: ListView.separated(
          controller: controller.groupScrollController,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppStyle.edgeInsetsH12,
          itemCount: controller.groups.length + 1,
          separatorBuilder: (_, __) => AppStyle.hGap8,
          itemBuilder: (_, index) {
            if (index == 0) {
              final key = controller.groupItemKeys.putIfAbsent("全部", () => GlobalKey());
              return Center(
                key: key,
                child: FilterButton(
                  text: "全部",
                  selected: controller.currentGroup.value.isEmpty,
                  onTap: () => controller.selectGroup(""),
                ),
              );
            }
            final group = controller.groups[index - 1];
            final key = controller.groupItemKeys.putIfAbsent(group, () => GlobalKey());
            return Center(
              key: key,
              child: FilterButton(
                text: group,
                selected: controller.currentGroup.value == group,
                onTap: () => controller.selectGroup(group),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChannelList(BuildContext context) {
    if (controller.channels.isEmpty) {
      return Center(
        child: Text(
          "没有匹配的频道",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      itemCount: controller.channels.length,
      separatorBuilder: (_, __) => AppStyle.divider,
      itemBuilder: (_, index) {
        final channel = controller.channels[index];
        return ListTile(
          onTap: () => controller.openPlayer(channel, index),
          leading: NetImage(channel.logo, width: 40, height: 40, borderRadius: 8),
          title: Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "${channel.group} · 来源：${controller.currentPlaylist.value?.name ?? ""}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            onPressed: () => controller.toggleFavorite(channel),
            icon: Icon(
              controller.isFavoriteChannel(channel)
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavorites(BuildContext context) {
    if (controller.favorites.isEmpty) {
      return Center(
        child: Text(
          "还没有收藏频道",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      itemCount: controller.favorites.length,
      separatorBuilder: (_, __) => AppStyle.divider,
      itemBuilder: (_, index) {
        final IptvFavorite item = controller.favorites[index];
        return ListTile(
          onTap: () => controller.openFavoritePlayer(item, index),
          leading: NetImage(item.logo, width: 40, height: 40, borderRadius: 8),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            item.group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          AppStyle.vGap12,
          FilledButton.icon(
            onPressed: controller.goManage,
            icon: const Icon(Icons.add),
            label: const Text("添加订阅源"),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(controller.errorMsg.value),
          AppStyle.vGap12,
          OutlinedButton(
            onPressed: () {
              final playlist = controller.currentPlaylist.value;
              if (playlist != null) controller.selectPlaylist(playlist);
            },
            child: const Text("重试"),
          ),
        ],
      ),
    );
  }
}
