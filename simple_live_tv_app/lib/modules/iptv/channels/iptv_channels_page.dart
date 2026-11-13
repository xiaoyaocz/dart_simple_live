import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/models/db/iptv_favorite.dart';
import 'package:simple_live_tv_app/modules/iptv/channels/iptv_channels_controller.dart';
import 'package:simple_live_tv_app/modules/iptv/parser/iptv_channel.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
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
          Obx(() => controller.searching.value
              ? _buildSearchBar()
              : const SizedBox.shrink()),
          // 订阅源与分组选择仅在非收藏模式显示
          Obx(() => controller.showFavorites.value
              ? const SizedBox.shrink()
              : _buildSelectors()),
          AppStyle.vGap16,
          Expanded(child: Obx(() => _buildBody())),
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
        Text(
          "IPTV",
          style: AppStyle.titleStyleWhite
              .copyWith(fontSize: 36.w, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.search,
          text: "搜索",
          onTap: controller.toggleSearch,
        ),
        AppStyle.hGap16,
        Obx(
          () => HighlightButton(
            focusNode: AppFocusNode(),
            iconData: controller.showFavorites.value
                ? Icons.star
                : Icons.star_border,
            text: "我的收藏",
            onTap: controller.toggleFavoritesMode,
          ),
        ),
        AppStyle.hGap16,
        HighlightButton(
          focusNode: AppFocusNode(),
          iconData: Icons.playlist_add,
          text: "订阅源管理",
          onTap: controller.goManage,
        ),
        AppStyle.hGap48,
      ],
    );
  }

  Widget _buildSearchBar() {
    final textController = TextEditingController(text: controller.keyword.value);
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: SizedBox(
        width: 640.w,
        child: AppTextField(
          controller: textController,
          autofocus: true,
          hintText: "搜索频道名称",
          onSubmitted: controller.setKeyword,
        ),
      ),
    );
  }

  Widget _buildSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHorizontalList(
          itemCount: controller.playlists.length,
          itemBuilder: (_, i) {
            final item = controller.playlists[i];
            return HighlightButton(
              focusNode: AppFocusNode(),
              text: item.name,
              selected: controller.currentPlaylist.value?.id == item.id,
              onTap: () => controller.selectPlaylist(item),
            );
          },
        ),
        AppStyle.vGap12,
        _buildHorizontalList(
          itemCount: controller.groups.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return HighlightButton(
                focusNode: AppFocusNode(),
                text: "全部",
                selected: controller.currentGroup.value.isEmpty,
                onTap: () => controller.selectGroup(""),
              );
            }
            final group = controller.groups[i - 1];
            return HighlightButton(
              focusNode: AppFocusNode(),
              text: group,
              selected: controller.currentGroup.value == group,
              onTap: () => controller.selectGroup(group),
            );
          },
        ),
      ],
    );
  }

  /// 横向可滚动的焦点按钮条
  Widget _buildHorizontalList({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return SizedBox(
      height: 64.w,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppStyle.edgeInsetsH48,
        itemCount: itemCount,
        separatorBuilder: (_, __) => AppStyle.hGap16,
        itemBuilder: itemBuilder,
      ),
    );
  }

  Widget _buildBody() {
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
                SizedBox(
                  width: 50.w,
                  height: 50.w,
                  child: CircularProgressIndicator(strokeWidth: 3.w),
                ),
                AppStyle.vGap32,
                SizedBox(
                  width: 400.w,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8.w,
                  ),
                ),
                AppStyle.vGap16,
                Text(
                  service.loadingMessage.value,
                  style: AppStyle.textStyleWhite.copyWith(fontSize: 24.w),
                ),
              ],
            );
          }),
        ),
      );
    }
    if (controller.showFavorites.value) {
      return _buildFavorites();
    }
    if (controller.playlists.isEmpty) {
      return _buildEmpty();
    }
    if (controller.pageError.value) {
      return _buildError();
    }
    if (controller.channels.isEmpty) {
      return Center(
        child: Text("没有匹配的频道", style: AppStyle.textStyleWhite),
      );
    }
    return ListView.builder(
      padding: AppStyle.edgeInsetsH48,
      itemCount: controller.channels.length,
      itemBuilder: (_, index) =>
          _buildChannelRow(controller.channels[index], index),
    );
  }

  Widget _buildChannelRow(IptvChannel channel, int index) {
    final fav = controller.isFavoriteChannel(channel);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        children: [
          Expanded(
            child: HighlightListTile(
              focusNode: AppFocusNode(),
              leading: NetImage(channel.logo,
                  width: 48.w, height: 48.w, borderRadius: 8),
              title: channel.name,
              subtitle: channel.group,
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

  Widget _buildFavorites() {
    if (controller.favorites.isEmpty) {
      return Center(
        child: Text("还没有收藏频道", style: AppStyle.textStyleWhite),
      );
    }
    return ListView.builder(
      padding: AppStyle.edgeInsetsH48,
      itemCount: controller.favorites.length,
      itemBuilder: (_, index) =>
          _buildFavoriteRow(controller.favorites[index], index),
    );
  }

  Widget _buildFavoriteRow(IptvFavorite item, int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: HighlightListTile(
        focusNode: AppFocusNode(),
        leading: NetImage(item.logo, width: 48.w, height: 48.w, borderRadius: 8),
        title: item.name,
        subtitle: item.group,
        onTap: () => controller.openFavoritePlayer(item, index),
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
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.add,
            text: "添加订阅源",
            onTap: controller.goManage,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(controller.errorMsg.value, style: AppStyle.textStyleWhite),
          AppStyle.vGap24,
          HighlightButton(
            focusNode: AppFocusNode(),
            iconData: Icons.refresh,
            text: "重试",
            onTap: () {
              final playlist = controller.currentPlaylist.value;
              if (playlist != null) controller.selectPlaylist(playlist);
            },
          ),
        ],
      ),
    );
  }
}
