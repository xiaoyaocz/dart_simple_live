import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/danmaku_filter.dart';

void main() {
  group('DanmakuFilter', () {
    test('validates plain keywords and regex syntax', () {
      expect(DanmakuFilter.validateRule(''), isNotNull);
      expect(DanmakuFilter.validateRule('   '), isNotNull);
      expect(DanmakuFilter.validateRule('广告'), isNull);
      expect(DanmakuFilter.validateRule(r'/\d+/'), isNull);
      expect(DanmakuFilter.validateRule('/abc/i'), isNull);
      expect(DanmakuFilter.validateRule('/[unclosed/'), isNotNull);
      expect(DanmakuFilter.validateRule('//'), isNotNull);
    });

    test('matches case-sensitive and case-insensitive regexes with cache', () {
      final filter = DanmakuFilter();
      final rules = ['/VIP/', '/spam/i', '代练'];

      expect(
        filter
            .evaluate(
              message: '买VIP进群',
              userName: 'u1',
              keywordRules: rules,
              blockedUsers: const [],
              mergeDuplicate: false,
            )
            .action,
        DanmakuFilterAction.blockKeyword,
      );

      expect(
        filter
            .evaluate(
              message: 'vip lowercase',
              userName: 'u1',
              keywordRules: rules,
              blockedUsers: const [],
              mergeDuplicate: false,
            )
            .action,
        DanmakuFilterAction.allow,
      );

      expect(
        filter
            .evaluate(
              message: 'SpAm message',
              userName: 'u1',
              keywordRules: rules,
              blockedUsers: const [],
              mergeDuplicate: false,
            )
            .action,
        DanmakuFilterAction.blockKeyword,
      );

      expect(
        filter
            .evaluate(
              message: '便宜代练',
              userName: 'u1',
              keywordRules: rules,
              blockedUsers: const [],
              mergeDuplicate: false,
            )
            .action,
        DanmakuFilterAction.blockKeyword,
      );
    });

    test('blocks users case-insensitively while allowing self messages', () {
      final filter = DanmakuFilter();
      final blocked = filter.evaluate(
        message: 'normal chat',
        userName: 'TrollUser',
        keywordRules: const [],
        blockedUsers: const ['trolluser'],
        mergeDuplicate: false,
      );
      expect(blocked.action, DanmakuFilterAction.blockUser);
      expect(blocked.shouldDisplay, isFalse);

      final selfMsg = filter.evaluate(
        message: 'normal chat',
        userName: 'TrollUser',
        keywordRules: const ['normal'],
        blockedUsers: const ['trolluser'],
        isSelf: true,
        mergeDuplicate: true,
      );
      expect(selfMsg.action, DanmakuFilterAction.allow);
      expect(selfMsg.shouldDisplay, isTrue);
    });

    test('suppresses duplicates in window and emits folded milestones', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final filter = DanmakuFilter(now: () => now);

      DanmakuFilterDecision eval(String text) => filter.evaluate(
            message: text,
            userName: 'viewer',
            keywordRules: const [],
            blockedUsers: const [],
            mergeDuplicate: true,
            mergeWindowSeconds: 5,
          );

      // 1st message passes
      expect(eval('666').action, DanmakuFilterAction.allow);
      // 2nd, 3rd, 4th suppressed
      expect(eval('666').action, DanmakuFilterAction.suppressDuplicate);
      expect(eval(' 666 ').action, DanmakuFilterAction.suppressDuplicate);
      expect(eval('666').action, DanmakuFilterAction.suppressDuplicate);
      // 5th emits folded milestone
      final fifth = eval('666');
      expect(fifth.action, DanmakuFilterAction.foldDuplicate);
      expect(fifth.duplicateCount, 5);
      expect(fifth.displayMessage, '666 (×5)');

      // After window expires, resets cleanly
      now = now.add(const Duration(seconds: 6));
      final afterWindow = eval('666');
      expect(afterWindow.action, DanmakuFilterAction.allow);
      expect(afterWindow.displayMessage, '666');
    });
  });
}
