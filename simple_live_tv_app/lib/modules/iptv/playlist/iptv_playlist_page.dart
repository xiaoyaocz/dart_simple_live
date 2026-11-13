import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/iptv_playlist.dart';
import 'package:simple_live_tv_app/modules/iptv/playlist/iptv_playlist_controller.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';

class IptvPlaylistPage extends GetView<IptvPlaylistController> {
  const IptvPlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStyle.vGap32,
          Row(
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
              Text(
                "直播源管理",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          AppStyle.vGap32,
          Expanded(
            child: Obx(
              () => controller.playlists.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: AppStyle.edgeInsetsH48,
                      itemCount: controller.playlists.length,
                      itemBuilder: (_, index) =>
                          _buildItemRow(controller.playlists[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.live_tv_outlined, size: 80.w, color: Colors.white54),
          AppStyle.vGap24,
          Text("直播源已被删除，重置应用后可恢复",
              style: AppStyle.textStyleWhite),
        ],
      ),
    );
  }

  Widget _buildItemRow(IptvPlaylist item) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: AppFocusNode(),
              leading: const Icon(Icons.cloud_outlined),
              title: item.name,
              subtitle: "自动更新 · 更新于 ${Utils.parseTime(item.updateTime)}",
              onTap: () => Get.toNamed(
                RoutePath.kIptvChannels,
                arguments: item,
              ),
            ),
          ),
          AppStyle.hGap12,
          Obx(
            () => controller.refreshingIds.contains(item.id)
                ? SizedBox(
                    width: 140.w,
                    height: 64.w,
                    child: Center(
                      child: SizedBox(
                        width: 36.w,
                        height: 36.w,
                        child: const CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  )
                : HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.refresh,
                    text: "刷新",
                    onTap: () => controller.refreshPlaylist(item),
                  ),
          ),
          AppStyle.hGap12,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.delete_outline,
            text: "删除",
            onTap: () => controller.delete(item),
          ),
        ],
      ),
    );
  }
}
