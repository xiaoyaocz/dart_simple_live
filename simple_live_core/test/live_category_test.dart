import 'dart:convert';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('LiveCategory nested categories', () {
    test('preserves 游戏 -> 射击游戏 -> 无畏契约 in JSON output', () {
      final category = LiveCategory(
        id: 'games',
        name: '游戏',
        children: [
          LiveSubCategory(
            id: 'shooting',
            name: '射击游戏',
            parentId: 'games',
            children: [
              LiveSubCategory(
                id: 'valorant',
                name: '无畏契约',
                parentId: 'shooting',
              ),
            ],
          ),
        ],
      );

      final encoded = jsonDecode(category.toString()) as Map<String, dynamic>;
      final shooting =
          (encoded['children'] as List).single as Map<String, dynamic>;
      final valorant =
          (shooting['children'] as List).single as Map<String, dynamic>;

      expect(category.children.single.hasChildren, isTrue);
      expect(shooting['name'], '射击游戏');
      expect(valorant['name'], '无畏契约');
      expect(valorant['children'], isEmpty);
    });
  });
}
