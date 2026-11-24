import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('DouyuSite.resolveCategoryInfo', () {
    test('reads snake_case betard fields and h5room fallback metadata', () {
      final betardRoom = {
        'room_id': 5140547,
        'cate1_id': 9,
        'cate2_id': 3785,
        'cate_id': 3785,
        'second_lvl_name': '王者万象棋',
      };
      final h5Data = {
        'cate_id': 3785,
        'game_name': '王者万象棋',
        'game_icon_url':
            'https://sta-op.douyucdn.cn/dycatr/fe501a69fae67a069f84ab431f683425.png',
      };

      final info = DouyuSite.resolveCategoryInfo(betardRoom, h5Data);
      expect(info['categoryId'], '3785');
      expect(info['categoryName'], '王者万象棋');
      expect(info['categoryParentId'], '9');
      expect(info['categoryParentName'], isNull);
      expect(
        info['categoryPic'],
        'https://sta-op.douyucdn.cn/dycatr/fe501a69fae67a069f84ab431f683425.png',
      );
    });

    test(
      'falls back to h5room game_name when betard lacks second_lvl_name',
      () {
        final betardRoom = {'room_id': 3014399, 'cate1_id': 9, 'cate_id': 181};
        final h5Data = {
          'game_name': '王者荣耀',
          'game_icon_url': 'https://example.com/wzry.png',
        };

        final info = DouyuSite.resolveCategoryInfo(betardRoom, h5Data);
        expect(info['categoryId'], '181');
        expect(info['categoryName'], '王者荣耀');
        expect(info['categoryParentId'], '9');
        expect(info['categoryPic'], 'https://example.com/wzry.png');
      },
    );

    test(
      'keeps backward compatibility with camelCase fields and ignores zero IDs',
      () {
        final betardRoom = {
          'cate1Id': 0,
          'cate2Id': 123,
          'cate2Name': '测试分类',
          'game_icon': 'https://example.com/icon.png',
        };

        final info = DouyuSite.resolveCategoryInfo(betardRoom);
        expect(info['categoryId'], '123');
        expect(info['categoryName'], '测试分类');
        expect(info['categoryParentId'], isNull);
        expect(info['categoryPic'], 'https://example.com/icon.png');
      },
    );
  });
}
