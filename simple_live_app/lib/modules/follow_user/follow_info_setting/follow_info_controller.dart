import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart' show FollowUser;
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/app/utils.dart';

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
    final result = await _parse(url);
    if (result.isEmpty || result.first == '') {
      SmartDialog.showToast('无法解析此链接');
      return;
    }
    final String newRoomId = result.first as String;
    final Site newSite = result[1] as Site;

    final current = followUser.value;
    if (current == null) return;

    if (current.siteId == newSite.id && current.roomId == newRoomId) {
      SmartDialog.showToast('与当前信息相同，无需迁移');
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

  Future<void> _migrateTo(Site targetSite, String targetRoomId) async {
    final current = followUser.value;
    if (current == null) return;

    // 复制并更新关键信息
    final FollowUser newFollow = FollowUser(
      id: '${targetSite.id}_$targetRoomId',
      roomId: targetRoomId,
      siteId: targetSite.id,
      userName: current.userName,
      face: current.face,
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
        tagObj.userId.remove(current.id);
        tagObj.userId
            .addIf(!tagObj.userId.contains(newFollow.id), newFollow.id);
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

  // 解析逻辑：与工具页保持一致
  Future<List> _parse(String url) async {
    var id = '';
    if (url.contains('bilibili.com')) {
      var regExp = RegExp(r'bilibili\.com/([\d|\w]+)');
      id = regExp.firstMatch(url)?.group(1) ?? '';
      return [id, Sites.allSites[Constant.kBiliBili]!];
    }

    if (url.contains('b23.tv')) {
      var btvReg = RegExp(r'https?:\/\/b23.tv\/[0-9a-z-A-Z]+');
      var u = btvReg.firstMatch(url)?.group(0) ?? '';
      var location = await _getLocation(u);
      return await _parse(location);
    }

    if (url.contains('douyu.com')) {
      var regExp = RegExp(r'douyu\.com/([\d|\w]+)');
      if (url.contains('topic')) {
        regExp = RegExp(r'[?&]rid=([\d]+)');
      }
      id = regExp.firstMatch(url)?.group(1) ?? '';
      return [id, Sites.allSites[Constant.kDouyu]!];
    }
    if (url.contains('huya.com')) {
      var regExp = RegExp(r'huya\.com/([\d|\w]+)');
      id = regExp.firstMatch(url)?.group(1) ?? '';
      return [id, Sites.allSites[Constant.kHuya]!];
    }
    if (url.contains('live.douyin.com')) {
      var regExp = RegExp(r'live\.douyin\.com/([\d|\w]+)');
      id = regExp.firstMatch(url)?.group(1) ?? '';
      return [id, Sites.allSites[Constant.kDouyin]!];
    }
    if (url.contains('webcast.amemv.com')) {
      var regExp = RegExp(r'reflow/(\d+)');
      id = regExp.firstMatch(url)?.group(1) ?? '';
      return [id, Sites.allSites[Constant.kDouyin]!];
    }
    if (url.contains('v.douyin.com')) {
      var regExp = RegExp(r'http.?://v.douyin.com/[\d\w]+/');
      var u = regExp.firstMatch(url)?.group(0) ?? '';
      var location = await _getLocation(u);
      return await _parse(location);
    }

    return [];
  }

  Future<String> _getLocation(String url) async {
    try {
      if (url.isEmpty) return '';
      await Dio().get(url, options: Options(followRedirects: false));
    } on DioException catch (e) {
      if (e.response?.statusCode == 302) {
        var redirectUrl = e.response?.headers.value('Location');
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return '';
  }
}
