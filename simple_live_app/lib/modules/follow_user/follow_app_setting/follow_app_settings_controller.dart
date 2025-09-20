import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart' hide Condition;
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/duration2strUtils.dart';
import 'package:simple_live_app/app/utils/dynamic_filter.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';

class FollowAppSettingsController extends BaseController {
  final appC = Get.find<AppSettingsController>();

  // 用户自定义标签
  RxList<FollowUserTag> userTagList = <FollowUserTag>[].obs;

  // 用户自定义条件
  Rx<int> takeLast = 15.obs;
  Rx<int> minutes= 30.obs;

  @override
  void onInit() {
    updateTagList();
    super.onInit();
  }

  // 标签管理
  void updateTagList() {
    userTagList.assignAll(FollowService.instance.followTagList);
  }

  Future removeTag(FollowUserTag tag) async {
    await FollowService.instance.removeFollowUserTag(tag);
    updateTagList();
    Log.i('删除tag${tag.tag}');
  }

  void addTag(String tag) async {
    await FollowService.instance.addFollowUserTag(tag);
    updateTagList();
  }

  Future<void> updateTag(FollowUserTag followUserTag) async {
    await FollowService.instance.updateFollowUserTag(followUserTag);
  }

  void updateTagName(FollowUserTag followUserTag, String newTagName) {
    // 未操作
    if (followUserTag.tag == newTagName) {
      return;
    }
    // 避免重名
    if (userTagList.any((item) => item.tag == newTagName)) {
      SmartDialog.showToast("标签名重复，修改失败");
      return;
    }
    FollowService.instance.updateTagName(followUserTag, newTagName);
    SmartDialog.showToast("标签名修改成功");
    updateTagList();
  }

  void updateTagOrder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1; // 处理索引调整
    final item = userTagList.removeAt(oldIndex);
    userTagList.insert(newIndex, item);
    FollowService.instance.updateFollowTagOrder(userTagList);
  }

  // 标签管理弹窗
  void showTagsManager() {
    Utils.showBottomSheet(
      title: '标签管理',
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppStyle.divider,
            ListTile(
              title: const Text("添加标签"),
              leading: const Icon(Icons.add),
              onTap: () {
                editTagDialog("添加标签");
              },
            ),
            AppStyle.divider,
            // 列表内容
            Expanded(
              child: Obx(
                () => ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: userTagList.length,
                  itemBuilder: (context, index) {
                    // 偏移
                    FollowUserTag item = userTagList[index];
                    return ListTile(
                      key: ValueKey(item.id),
                      title: GestureDetector(
                        child: Text(item.tag),
                        onLongPress: () {
                          {
                            editTagDialog("修改标签", followUserTag: item);
                          }
                        },
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          removeTag(item);
                        },
                      ),
                      trailing: ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    updateTagOrder(oldIndex, newIndex);
                  },
                ),
              ),
            ),
          ]),
    );
  }

  void editTagDialog(String title, {FollowUserTag? followUserTag}) {
    final TextEditingController tagEditController =
        TextEditingController(text: followUserTag?.tag);
    bool upMode = title == "添加标签" ? true : false;
    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(Get.context!).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
              TextField(
                controller: tagEditController,
                minLines: 1,
                maxLines: 1,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: AppStyle.edgeInsetsA12,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey.withValues(
                        alpha: .2,
                      ),
                    ),
                  ),
                ),
                onSubmitted: (tag) {
                  upMode
                      ? addTag(tagEditController.text)
                      : updateTagName(followUserTag!, tagEditController.text);
                  Get.back();
                },
              ),
              Container(
                margin: AppStyle.edgeInsetsB4,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: const Text('否'),
                    ),
                    TextButton(
                      onPressed: () {
                        upMode
                            ? addTag(tagEditController.text)
                            : updateTagName(
                                followUserTag!,
                                tagEditController.text,
                              );
                        Get.back();
                      },
                      child: const Text('是'),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 关注清理功能
  Future<void> cleanFollow(List<FollowUser> cleanPool) async {
    if (cleanPool.isEmpty) {
      SmartDialog.showToast("没有需要清理的用户");
      return;
    }
    SmartDialog.showLoading(msg: "清理中");
    for (var follow in cleanPool) {
      // 取消关注同时删除标签内的 userId
      if (follow.tag != "全部") {
        var tag = userTagList.firstWhere((tag) => tag.tag == follow.tag);
        tag.userId.remove(follow.id);
        await updateTag(tag);
      }
      await FollowService.instance.removeFollowUser(follow.id);
    }
    SmartDialog.dismiss();
    EventBus.instance.emit(Constant.kUpdateFollow,0);
    SmartDialog.showToast("清理完成");
  }

  List<FollowUser> buildAutoCleanPool() {
    var followList = FollowService.instance.followList;
    var histories = DBService.instance.getHistories();
    if (histories.isEmpty || followList.isEmpty) return [];
    // 筛选出历史记录里已关注的
    final followedIds =
        followList.map((follow) => follow.id).toSet(); // set性能略优
    final followedHistories =
        histories.where((history) => followedIds.contains(history.id)).toList();
    if (followedHistories.isEmpty) return [];

    List<Condition> conditions = [
      // Condition('siteId', FilterOperator.equals, Constant.kBiliBili),
      Condition(
        'watchDuration',
        FilterOperator.lessThan,
        Duration(minutes: minutes.value),
        comparableValueProvider: (watchDuration) {
          if (watchDuration is String) {
            return watchDuration.toDuration();
          }
          return null;
        },
      ),
    ];
    // 根据动态条件筛选出需要清理的 关注id
    final df = dynamicFilter(followedHistories, conditions, takeLast: takeLast.value);
    final uidsToClean = df.map((history) => history.id).toSet();

    final autoCleanPool =
        followList.where((follow) => uidsToClean.contains(follow.id)).toList();
    return autoCleanPool;
  }
}
