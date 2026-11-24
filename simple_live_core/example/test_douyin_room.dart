import 'package:simple_live_core/simple_live_core.dart';

Future<void> main(List<String> args) async {
  for (final webRid in args) {
    try {
      final detail = await DouyinSite().getRoomDetail(roomId: webRid);
      print("[$webRid] OK status=${detail.status} title=${detail.title} user=${detail.userName}");
    } catch (e) {
      print("[$webRid] FAIL: $e");
    }
  }
}
