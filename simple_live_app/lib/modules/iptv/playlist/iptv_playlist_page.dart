import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/iptv_playlist.dart';
import 'package:simple_live_app/modules/iptv/playlist/iptv_playlist_controller.dart';

class IptvPlaylistPage extends GetView<IptvPlaylistController> {
  const IptvPlaylistPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("直播源管理")),
      body: Obx(
        () => controller.playlists.isEmpty
            ? _buildEmpty(context)
            : ListView.separated(
                padding: AppStyle.edgeInsetsV8,
                itemCount: controller.playlists.length,
                separatorBuilder: (_, __) => AppStyle.divider,
                itemBuilder: (_, index) =>
                    _buildItem(controller.playlists[index]),
              ),
      ),
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
          Text(
            "直播源已被删除，重置应用后可恢复",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(IptvPlaylist item) {
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "自动更新 · 更新于 ${Utils.parseTime(item.updateTime)}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Obx(
              () => controller.refreshingIds.contains(item.id)
                  ? const Padding(
                      padding: AppStyle.edgeInsetsA12,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: "刷新",
                      onPressed: () => controller.refreshPlaylist(item),
                      icon: const Icon(Icons.refresh),
                    ),
            ),
            IconButton(
              tooltip: "删除",
              onPressed: () => controller.delete(item),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
