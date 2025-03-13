import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class MigrationService extends GetxService {
  static MigrationService get instance => Get.find<MigrationService>();

  // 修改webdav同步时间在Hive中的数据格式


  /// 数据迁移根据版本：from 1.7.8
  void migrateDataByVersion() {
    int curAppVer = Utils.parseVersion(Utils.packageInfo.version);
    int curDBVer = LocalStorageService.instance.getValue(LocalStorageService.kHiveDbVer, 10708);
    if (curDBVer <= 10708) {
      LocalStorageService.instance.settingsBox
          .delete(LocalStorageService.kWebDAVLastUploadTime);
      LocalStorageService.instance.settingsBox
          .delete(LocalStorageService.kWebDAVLastRecoverTime);
    }
    // follow_user 添加 tag属性
    // 从followUserTag 读取 标签
    if(curDBVer <= 10709){
      List tagList = DBService.instance.tagBox.values.toList();
      List<FollowUser> followList = DBService.instance.followBox.values.toList();
      for (int i = 0; i < followList.length; i++) {
        for (FollowUserTag tag in tagList) {
          if (tag.userId.contains(followList[i].id)) {
            followList[i].tag = tag.tag;
            DBService.instance.addFollow(followList[i]);
          }
        }
      }
    }
    LocalStorageService.instance.settingsBox
        .put(LocalStorageService.kHiveDbVer, curAppVer);
  }
}
