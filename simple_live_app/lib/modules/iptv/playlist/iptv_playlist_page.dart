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
      appBar: AppBar(
        title: const Text("订阅源管理"),
        actions: [
          IconButton(
            tooltip: "添加本地文件",
            onPressed: controller.addLocal,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: "添加网络源",
            onPressed: controller.addRemote,
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: Obx(
        () => controller.playlists.isEmpty
            ? _buildEmpty(context)
            : ListView.separated(
                padding: AppStyle.edgeInsetsV8,
                itemCount: controller.playlists.length,
                separatorBuilder: (_, __) => AppStyle.divider,
                itemBuilder: (_, index) => _buildItem(
                  context,
                  controller.playlists[index],
                ),
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
            "还没有订阅源，添加一个开始观看",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppStyle.vGap24,
          FilledButton.icon(
            onPressed: controller.addRemote,
            icon: const Icon(Icons.add_link),
            label: const Text("添加网络订阅源"),
          ),
          AppStyle.vGap8,
          OutlinedButton.icon(
            onPressed: controller.addLocal,
            icon: const Icon(Icons.folder_open),
            label: const Text("导入本地 M3U 文件"),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, IptvPlaylist item) {
    return ListTile(
      leading: Icon(item.isLocal ? Icons.folder : Icons.cloud_outlined),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${item.isLocal ? "本地文件" : "网络订阅"} · 更新于 ${Utils.parseTime(item.updateTime)}",
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
