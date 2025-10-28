import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class MigrationService {
  /// 将Hive数据迁移到Application Support
  static Future migrateData() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    var hiveFileList = [
      "followuser",
      //旧版本写错成hostiry了
      "hostiry",
      "followusertag",
      "localstorage",
      "danmushield",
    ];
    try {
      var newDir = await getApplicationSupportDirectory();
      var hiveFile = File(p.join(newDir.path, "followuser.hive"));
      if (await hiveFile.exists()) {
        return;
      }

      var oldDir = await getApplicationDocumentsDirectory();
      for (var element in hiveFileList) {
        var oldFile = File(p.join(oldDir.path, "$element.hive"));
        if (await oldFile.exists()) {
          var fileName = "$element.hive";
          if (element == "hostiry") {
            fileName = "history.hive";
          }
          await oldFile.copy(p.join(newDir.path, fileName));
          await oldFile.delete();
        }
        var lockFile = File(p.join(oldDir.path, "$element.lock"));
        if (await lockFile.exists()) {
          await lockFile.delete();
        }
      }
    } catch (e) {
      Log.logPrint(e);
    }
  }

  /// 数据迁移根据版本：from 1.7.8
  static void migrateDataByVersion() {
    int curAppVer = Utils.parseVersion(Utils.packageInfo.version);
    int curDBVer = LocalStorageService.instance
        .getValue(LocalStorageService.kHiveDbVer, 10708);
    if (curDBVer <= 10708) {
      LocalStorageService.instance.settingsBox
          .delete(LocalStorageService.kWebDAVLastUploadTime);
      LocalStorageService.instance.settingsBox
          .delete(LocalStorageService.kWebDAVLastRecoverTime);
    }
    // follow_user 添加 tag属性
    // 从followUserTag 读取 标签
    if (curDBVer <= 10709) {
      List tagList = DBService.instance.tagBox.values.toList();
      List<FollowUser> followList =
          DBService.instance.followBox.values.toList();
      for (int i = 0; i < followList.length; i++) {
        for (FollowUserTag tag in tagList) {
          if (tag.userId.contains(followList[i].id)) {
            followList[i].tag = tag.tag;
            DBService.instance.addFollow(followList[i]);
            break;
          }
        }
      }
    }
    LocalStorageService.instance.settingsBox
        .put(LocalStorageService.kHiveDbVer, curAppVer);
  }
}
