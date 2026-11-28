import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/live_notification_service.dart';

FollowUser _user(
  String id, {
  required int status,
  String siteId = 'bilibili',
  String roomId = '100',
  String userName = '主播A',
  String? categoryName,
}) {
  final user = FollowUser(
    id: id,
    roomId: roomId,
    siteId: siteId,
    userName: userName,
    face: '',
    addTime: DateTime(2026, 1, 1),
    categoryName: categoryName,
  );
  user.liveStatus.value = status;
  return user;
}

void main() {
  group('LiveOnlineTransitionTracker', () {
    test('skips initial baseline and only notifies on offline -> live transition',
        () {
      var now = DateTime(2026, 1, 1, 20, 0, 0);
      final tracker = LiveOnlineTransitionTracker(
        now: () => now,
        cooldown: const Duration(minutes: 10),
      );

      // Initial startup snapshot: already live user must NOT trigger alert
      final initial = tracker.recordSnapshot([
        _user('bilibili_1', status: 2, roomId: '1', userName: '已开播'),
        _user('bilibili_2', status: 1, roomId: '2', userName: '未开播'),
      ]);
      expect(initial, isEmpty);

      // Second refresh: bilibili_2 goes 1 -> 2
      now = now.add(const Duration(minutes: 1));
      final second = tracker.recordSnapshot([
        _user('bilibili_1', status: 2, roomId: '1', userName: '已开播'),
        _user(
          'bilibili_2',
          status: 2,
          roomId: '2',
          userName: '未开播',
          categoryName: '英雄联盟',
        ),
      ]);
      expect(second, hasLength(1));
      expect(second.first.followId, 'bilibili_2');
      expect(second.first.categoryName, '英雄联盟');

      // Third refresh: stays live (2 -> 2) should NOT notify again
      now = now.add(const Duration(minutes: 1));
      final third = tracker.recordSnapshot([
        _user('bilibili_1', status: 2, roomId: '1', userName: '已开播'),
        _user('bilibili_2', status: 2, roomId: '2', userName: '未开播'),
      ]);
      expect(third, isEmpty);
    });

    test('enforces cooldown for flapping streams and prunes unfollowed users',
        () {
      var now = DateTime(2026, 1, 1, 20, 0, 0);
      final tracker = LiveOnlineTransitionTracker(
        now: () => now,
        cooldown: const Duration(minutes: 10),
      );

      tracker.recordSnapshot([_user('douyu_9', status: 1, roomId: '9')]);

      // Goes live at t+1m -> fires
      now = now.add(const Duration(minutes: 1));
      expect(
        tracker.recordSnapshot([_user('douyu_9', status: 2, roomId: '9')]),
        hasLength(1),
      );

      // Drops offline then comes back at t+4m (within 10m cooldown) -> suppressed
      now = now.add(const Duration(minutes: 1));
      tracker.recordSnapshot([_user('douyu_9', status: 1, roomId: '9')]);
      now = now.add(const Duration(minutes: 2));
      expect(
        tracker.recordSnapshot([_user('douyu_9', status: 2, roomId: '9')]),
        isEmpty,
      );

      // Drops offline and returns after cooldown expires -> fires again
      now = now.add(const Duration(minutes: 1));
      tracker.recordSnapshot([_user('douyu_9', status: 1, roomId: '9')]);
      now = now.add(const Duration(minutes: 10));
      expect(
        tracker.recordSnapshot([_user('douyu_9', status: 2, roomId: '9')]),
        hasLength(1),
      );

      // Unfollowed user is pruned from tracked map
      tracker.recordSnapshot([]);
      expect(
        tracker.recordSnapshot([_user('douyu_9', status: 2, roomId: '9')]),
        isEmpty,
      );
    });

    test('LiveNotificationService batches >3 simultaneous live events',
        () async {
      final delivered = <(String, String, String, String)>[];
      final tracker = LiveOnlineTransitionTracker();
      final service = LiveNotificationService(
        tracker: tracker,
        showOverride: (title, body, siteId, roomId) async {
          delivered.add((title, body, siteId, roomId));
        },
      );

      final initialUsers = List.generate(
        4,
        (i) => _user(
          'bilibili_$i',
          status: 1,
          roomId: '$i',
          userName: '主播$i',
        ),
      );
      await service.handleFollowRefreshCompleted(initialUsers);
      expect(delivered, isEmpty);

      for (final u in initialUsers) {
        u.liveStatus.value = 2;
      }
      await service.handleFollowRefreshCompleted(initialUsers);
      expect(delivered, hasLength(1));
      expect(delivered.first.$1, contains('4 位'));
      expect(delivered.first.$3, 'bilibili');
      expect(delivered.first.$4, '0');
    });
  });
}
