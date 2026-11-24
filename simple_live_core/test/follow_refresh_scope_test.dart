import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('tag refresh scope keeps a separate resumable task', () {
    final scope = FollowRefreshScope.tag(tagId: 'morning', tagName: '上午开播');

    expect(scope.scopeKey, 'tag:morning');
    expect(scope.includeAllNormals, isTrue);
    expect(scope.allowBackgroundSpecials, isFalse);
    expect(scope.automatic, isFalse);
    expect(scope.stage, contains('上午开播'));
  });
}
