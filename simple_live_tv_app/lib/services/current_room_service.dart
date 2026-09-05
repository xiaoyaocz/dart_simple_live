import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class CurrentRoomService extends GetxService {
  static CurrentRoomService get instance => Get.find<CurrentRoomService>();

  final siteId = "".obs;
  final roomId = "".obs;

  String get currentKey => siteId.value.isEmpty || roomId.value.isEmpty
      ? ""
      : "${siteId.value}_${roomId.value}";

  void setRoom(Site site, String roomId) {
    siteId.value = site.id;
    this.roomId.value = roomId;
  }
}
