import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/url_parse.dart';
import 'package:simple_live_app/models/db/follow_user.dart' show FollowUser;
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class FollowInfoController extends BasePageController<FollowUser> {
  final Rxn<FollowUser> followUser = Rxn<FollowUser>();

  // 下拉可选标签：只包含“全部”+用户自定义标签
  final RxList<FollowUserTag> tagOptions = <FollowUserTag>[].obs;
  final Rx<FollowUserTag?> selectedTag = Rx<FollowUserTag?>(null);

  // 平台迁移预留：列出除当前平台外的其余平台
  final RxList<Site> migrationSites = <Site>[].obs;

  // 平台迁移：输入链接
  final TextEditingController migrationUrlController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // 读取传入的 FollowUser
    final args = Get.arguments;
    if (args is FollowUser) {
      followUser.value = args;
    } else if (args is Map && args['follow'] is FollowUser) {
      followUser.value = args['follow'] as FollowUser;
    }

    _initTagOptions();
    _initMigrationSites();
  }

  void _initTagOptions() {
    final List<FollowUserTag> options =
        FollowService.instance.getTagOptionsWithAll();
    tagOptions.assignAll(options);

    // 设置选中项
    final current = followUser.value;
    if (current != null) {
      FollowUserTag? matched;
      for (final e in options) {
        if (e.tag == current.tag) {
          matched = e;
          break;
        }
      }
      selectedTag.value = matched ?? options.first;
    }
  }

  void _initMigrationSites() {
    final current = followUser.value;
    if (current == null) {
      migrationSites.clear();
      return;
    }
    final List<Site> all = Sites.supportSites;
    migrationSites.assignAll(
      all.where((s) => s.id != current.siteId).toList(),
    );
  }

  void changeTag(FollowUserTag newTag) {
    final current = followUser.value;
    if (current == null) return;
    FollowService.instance.setItemTag(current, newTag);
    selectedTag.value = newTag;
    followUser.refresh();
  }

  Future<void> pasteFromClipboard() async {
    final content = await Utils.getClipboard();
    if (content != null) {
      migrationUrlController.text = content;
    }
  }

  Future<void> parseAndMigrate() async {
    final url = migrationUrlController.text.trim();
    if (url.isEmpty) {
      SmartDialog.showToast('链接不能为空');
      return;
    }
    final result = await UrlParse.instance.parse(url);
    if (result.isEmpty || result.first == '') {
      SmartDialog.showToast('无法解析此链接');
      return;
    }
    final String newRoomId = result.first as String;
    final Site newSite = result[1] as Site;

    final current = followUser.value;
    if (current == null) return;

    // 防呆
    bool contain = DBService.instance.getFollowExist("${newSite.id}_$newRoomId");
    if (contain == true) {
      SmartDialog.showToast('目标主播已关注，无需迁移');
      return;
    }

    final confirmed = await Get.dialog<bool>(AlertDialog(
      title: const Text('确认迁移'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '从：${Sites.allSites[current.siteId]?.name}  房间号：${current.roomId}'),
          const SizedBox(height: 8),
          Text('到：${newSite.name}  房间号：$newRoomId'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('确定'),
        ),
      ],
    ));

    if (confirmed != true) return;

    await _migrateTo(newSite, newRoomId);
    SmartDialog.showToast('迁移成功');
  }

  @override
  Future<void> refreshData() async{
    pageLoadding.value = true;
    var site = Sites.allSites[followUser.value?.siteId]!;
    await _migrateTo(site, followUser.value!.roomId);
    pageLoadding.value = false;
    SmartDialog.showToast('已刷新用户信息');
  }

  Future<void> _migrateTo(Site targetSite, String targetRoomId) async {
    final current = followUser.value;
    if (current == null) return;
    // 获取目标直播间详细信息 用于更新主播名和头像
    LiveRoomDetail detail = await targetSite.liveSite.getRoomDetail(roomId: targetRoomId);
    // 复制并更新关键信息
    final FollowUser newFollow = FollowUser(
      id: '${targetSite.id}_$targetRoomId',
      roomId: targetRoomId,
      siteId: targetSite.id,
      userName: detail.userName,
      face: detail.userAvatar,
      addTime: current.addTime,
      watchDuration: current.watchDuration,
      tag: current.tag,
    );

    // 更新标签归属
    if (current.tag != '全部') {
      FollowUserTag? tagObj;
      for (final t in FollowService.instance.followTagList) {
        if (t.tag == current.tag) {
          tagObj = t;
          break;
        }
      }
      if (tagObj != null) {
        // 自刷新和迁移逻辑一致：删旧增新
        tagObj.userId.remove(current.id);
        tagObj.userId.add( newFollow.id);
        FollowService.instance.updateFollowUserTag(tagObj);
      }
    }

    // 替换关注
    DBService.instance.deleteFollow(current.id);
    FollowService.instance.addFollow(newFollow);

    // 刷新本地数据并更新UI
    await FollowService.instance.loadData(updateStatus: false);
    followUser.value = newFollow;
    _initMigrationSites();
  }
}
