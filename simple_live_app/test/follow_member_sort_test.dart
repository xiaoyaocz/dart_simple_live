import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';

void main() {
  test('分类内部按设置平台与热度排序，缺失和同热度保持原顺序', () {
    final controller = FollowUserController();
    FollowUser user(String id, String site) => FollowUser(id: id, roomId: id,
        siteId: site, userName: id, face: '', addTime: DateTime(2026));
    final missing = user('无热度一', 'huya');
    final low = user('低', 'huya')..heat = 10;
    final high = user('高', 'huya')..heat = 100;
    final equal = user('同热度', 'huya')..heat = 100;
    final missing2 = user('无热度二', 'huya');
    final douyin = user('抖音', 'douyin')..heat = 1;
    final source = [missing, low, high, douyin, equal, missing2];
    expect(controller.sortCategoryMembers(source, ['douyin', 'huya']),
        [douyin, high, equal, low, missing, missing2]);
    expect(source, [missing, low, high, douyin, equal, missing2]);
    low.heat = 200;
    expect(controller.sortCategoryMembers(source, ['huya', 'douyin']),
        [low, high, equal, missing, missing2, douyin]);
    final other = user('其他平台', 'other')..heat = 1000;
    expect(controller.sortCategoryMembers([high, other, low], []),
        [low, high, other]);
    controller.onClose();
  });
}
