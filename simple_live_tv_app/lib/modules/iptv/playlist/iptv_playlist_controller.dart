import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/iptv_playlist.dart';
import 'package:simple_live_tv_app/services/iptv_service.dart';
import 'package:simple_live_tv_app/widgets/app_text_field.dart';

class IptvPlaylistController extends BaseController {
  final playlists = <IptvPlaylist>[].obs;

  /// 正在刷新的订阅源 id
  final refreshingIds = <String>{}.obs;

  @override
  void onInit() {
    loadPlaylists();
    super.onInit();
  }

  void loadPlaylists() {
    playlists.value = IptvService.instance.getPlaylists();
  }

  /// 添加网络订阅源（TV 端不支持本地文件选择）
  Future<void> addRemote() async {
    final input = await showAddDialog();
    if (input == null) return;
    final playlist = await IptvService.instance.addPlaylist(
      name: input.name,
      url: input.url,
      type: IptvPlaylist.typeRemote,
    );
    loadPlaylists();
    await refreshPlaylist(playlist);
  }

  /// 拉取并解析订阅源
  Future<void> refreshPlaylist(IptvPlaylist playlist) async {
    if (refreshingIds.contains(playlist.id)) return;
    refreshingIds.add(playlist.id);
    try {
      final result = await IptvService.instance.refresh(playlist);
      SmartDialog.showToast("「${playlist.name}」已更新，共 ${result.channels.length} 个频道");
    } catch (e) {
      handleError(e);
    } finally {
      refreshingIds.remove(playlist.id);
      loadPlaylists();
    }
  }

  Future<void> delete(IptvPlaylist playlist) async {
    final confirmed = await Utils.showAlertDialog(
      "确定删除订阅源「${playlist.name}」？该源下的收藏频道不会被删除。",
      title: "删除订阅源",
      confirm: "删除",
    );
    if (!confirmed) return;
    await IptvService.instance.deletePlaylist(playlist.id);
    loadPlaylists();
  }

  /// 名称与地址录入弹窗，名称留空时用地址兜底
  Future<({String name, String url})?> showAddDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppStyle.radius16),
        titlePadding: AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        contentPadding:
            AppStyle.edgeInsetsA24.copyWith(left: 48.w, right: 48.w),
        insetPadding: AppStyle.edgeInsetsA16,
        actionsPadding: AppStyle.edgeInsetsA16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Get.theme.cardColor,
        title: Text("添加网络订阅源", style: AppStyle.titleStyleWhite),
        content: SizedBox(
          width: 640.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                autofocus: true,
                hintText: "名称（可留空）",
              ),
              AppStyle.vGap24,
              AppTextField(
                controller: urlController,
                hintText: "M3U 地址，如 https://example.com/live.m3u",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text("取消", style: AppStyle.textStyleWhite),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                SmartDialog.showToast("请填写订阅地址");
                return;
              }
              final name = nameController.text.trim().isNotEmpty
                  ? nameController.text.trim()
                  : url.split("/").last;
              Get.back(result: (name: name, url: url));
            },
            child: Text("添加", style: AppStyle.textStyleWhite),
          ),
        ],
      ),
    );
  }
}
