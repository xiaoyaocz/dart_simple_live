import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';

void main() {
  test('follow tag survives JSON round trip', () {
    final user = FollowUser(
      id: 'douyin_1',
      roomId: '1',
      siteId: 'douyin',
      userName: '主播',
      face: '',
      addTime: DateTime.utc(2026, 9, 2),
      tag: '上午开播',
    );

    final restored = FollowUser.fromJson(user.toJson());

    expect(restored.tag, '上午开播');
  });

  test('follow tag defaults to all for older JSON data', () {
    final restored = FollowUser.fromJson({
      'id': 'bilibili_2',
      'roomId': '2',
      'siteId': 'bilibili',
      'userName': '主播',
      'face': '',
      'addTime': '2026-09-02T00:00:00.000Z',
    });

    expect(restored.tag, '全部');
  });
}
