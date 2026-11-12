import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/iptv_playlist.dart';
import 'package:simple_live_app/services/iptv_service.dart';

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

  /// 添加网络订阅源
  Future<void> addRemote() async {
    final input = await _showAddDialog();
    if (input == null) return;
    final playlist = await IptvService.instance.addPlaylist(
      name: input.name,
      url: input.url,
      type: IptvPlaylist.typeRemote,
    );
    loadPlaylists();
    await refreshPlaylist(playlist);
  }

  /// 添加本地 M3U 文件
  Future<void> addLocal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["m3u", "m3u8"],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final playlist = await IptvService.instance.addPlaylist(
      name: result!.files.single.name,
      url: path,
      type: IptvPlaylist.typeLocal,
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

  /// 名称与地址的录入弹窗，名称留空时用地址兜底
  Future<({String name, String url})?> _showAddDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    return Get.dialog(
      AlertDialog(
        title: const Text("添加网络订阅源"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "名称（可留空）",
              ),
            ),
            AppStyle.vGap12,
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "M3U 地址，如 https://example.com/live.m3u",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("取消")),
          FilledButton(
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
            child: const Text("添加"),
          ),
        ],
      ),
    );
  }
}
