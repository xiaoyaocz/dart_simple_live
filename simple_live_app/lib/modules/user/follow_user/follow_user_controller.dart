import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';

class FollowUserController extends BasePageController<FollowUser> {
  StreamSubscription<dynamic>? subscription;
  StreamSubscription<dynamic>? subscriptionIndexedUpdate;
  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      refreshData();
    });
    subscriptionIndexedUpdate = EventBus.instance.listen(
      EventBus.kBottomNavigationBarClicked,
      (index) {
        if (index == 1) {
          scrollToTopOrRefresh();
        }
      },
    );
    super.onInit();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) {
    if (page > 1) {
      return Future.value([]);
    }
    var list = DBService.instance.getFollowList();
    for (var item in list) {
      updateLiveStatus(item);
    }
    return Future.value(list);
  }

  void updateLiveStatus(FollowUser item) async {
    try {
      var site = Sites.supportSites.firstWhere((x) => x.id == item.siteId);
      item.liveStatus.value =
          (await site.liveSite.getLiveStatus(roomId: item.roomId)) ? 2 : 1;
      list.sort((a, b) => b.liveStatus.value.compareTo(a.liveStatus.value));
    } catch (e) {
      Log.logPrint(e);
    }
  }

  void removeItem(FollowUser item) async {
    var result =
        await Utils.showAlertDialog("确定要取消关注${item.userName}吗?", title: "取消关注");
    if (!result) {
      return;
    }
    await DBService.instance.followBox.delete(item.id);
    refreshData();
  }

  @override
  void onClose() {
    subscription?.cancel();
    subscriptionIndexedUpdate?.cancel();
    super.onClose();
  }

  void exportList() async {
    if (list.isEmpty) {
      SmartDialog.showToast("列表为空");
      return;
    }
    var dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) {
      return;
    }
    try {
      var jsonFile = File(
          '$dir/SimpleLive_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json');
      var data = list
          .map(
            (item) => {
              "siteId": item.siteId,
              "id": item.id,
              "roomId": item.roomId,
              "userName": item.userName,
              "face": item.face,
              "addTime": item.addTime.toString(),
            },
          )
          .toList();

      await jsonFile.writeAsString(jsonEncode(data));
      SmartDialog.showToast("已导出关注列表");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导出失败：$e");
    }
  }

  void inputList() async {
    var file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) {
      return;
    }
    try {
      var jsonFile = File(file.files.single.path!);
      var data = jsonDecode(await jsonFile.readAsString());

      for (var item in data) {
        var user = FollowUser.fromJson(item);
        DBService.instance.followBox.put(user.id, user);
      }
      SmartDialog.showToast("导入成功");
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("导入失败:$e");
    } finally {
      refreshData();
    }
  }
}
