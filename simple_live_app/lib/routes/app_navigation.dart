import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  /// 跳转至分类详情
  static void toCategoryDetail(
      {required Site site, required LiveSubCategory category}) {
    Get.toNamed(RoutePath.kCategoryDetail, arguments: [site, category]);
  }

  /// 跳转至直播间
  static void toLiveRoomDetail({required Site site, required String roomId}) {
    Get.toNamed(RoutePath.kLiveRoomDetail, arguments: site, parameters: {
      "roomId": roomId,
    });
  }
}
