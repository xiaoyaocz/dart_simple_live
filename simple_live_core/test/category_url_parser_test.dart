import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('DouyinSite.normalizeCategoryId', () {
    test('keeps valid id,type format', () {
      expect(DouyinSite.normalizeCategoryId('1010016,1'), '1010016,1');
      expect(DouyinSite.normalizeCategoryId(' 103 , 4 '), '103,4');
    });

    test('converts type_id path tokens to id,type', () {
      expect(DouyinSite.normalizeCategoryId('1_1010016'), '1010016,1');
      expect(
        DouyinSite.normalizeCategoryId('4_103_1_2_1_1010016'),
        '1010016,1',
      );
      expect(DouyinSite.normalizeCategoryId('4_103'), '103,4');
    });

    test('defaults bare numeric id to sub-partition type 1', () {
      expect(DouyinSite.normalizeCategoryId('1010016'), '1010016,1');
      expect(DouyinSite.normalizeCategoryId('   '), '');
    });
  });

  group('CategoryUrlParser', () {
    test('parses douyin categorynew and category URLs', () {
      final deep = CategoryUrlParser.parse(
        'https://live.douyin.com/categorynew/4_103_1_2_1_1010016',
      );
      expect(deep, isNotNull);
      expect(deep!.siteId, LiveUrlParser.siteDouyin);
      expect(deep.categoryId, '1010016,1');
      expect(deep.parentId, '103,4');
      expect(deep.hasCategoryId, isTrue);

      final direct = CategoryUrlParser.parse(
        'live.douyin.com/category/1_1010016',
      );
      expect(direct, isNotNull);
      expect(direct!.categoryId, '1010016,1');
    });

    test('parses bilibili area-tags URL', () {
      final parsed = CategoryUrlParser.parse(
        'https://live.bilibili.com/p/eden/area-tags?parentAreaId=2&areaId=235',
      );
      expect(parsed, isNotNull);
      expect(parsed!.siteId, LiveUrlParser.siteBilibili);
      expect(parsed.categoryId, '235');
      expect(parsed.parentId, '2');
    });

    test('parses huya numeric and slug category URLs', () {
      final numeric = CategoryUrlParser.parse('https://www.huya.com/g/4079');
      expect(numeric, isNotNull);
      expect(numeric!.siteId, LiveUrlParser.siteHuya);
      expect(numeric.categoryId, '4079');
      expect(numeric.needsHtmlFetch, isFalse);

      final slug = CategoryUrlParser.parse('https://www.huya.com/g/lol');
      expect(slug, isNotNull);
      expect(slug!.siteId, LiveUrlParser.siteHuya);
      expect(slug.categoryId, isEmpty);
      expect(slug.needsHtmlFetch, isTrue);
    });

    test('returns guidance hint for douyu slug URL', () {
      final parsed = CategoryUrlParser.parse('https://www.douyu.com/g_LOL');
      expect(parsed, isNotNull);
      expect(parsed!.siteId, LiveUrlParser.siteDouyu);
      expect(parsed.hasCategoryId, isFalse);
      expect(parsed.hintMessage, isNotNull);
    });

    test('extracts douyin game_tag and huya GID from HTML snippets', () {
      const douyinHtml =
          r'{"roomsData":{"data":[{"room":{"game_tag":"永劫无间"}}]}}';
      expect(
        CategoryUrlParser.extractDouyinCategoryTitleFromHtml(douyinHtml),
        '永劫无间',
      );

      const douyinTitleHtml =
          '<html><head><title>无畏契约直播_抖音直播</title></head></html>';
      expect(
        CategoryUrlParser.extractDouyinCategoryTitleFromHtml(douyinTitleHtml),
        '无畏契约',
      );
      expect(
        CategoryUrlParser.extractDouyinCategoryTitleFromHtml(
          '<title>抖音直播</title>',
        ),
        isNull,
      );

      const huyaHtml = '''
        <title>英雄联盟直播_英雄联盟无限火力_虎牙直播</title>
        <script>var GID = '1';</script>
      ''';
      final huya = CategoryUrlParser.extractHuyaCategoryFromHtml(huyaHtml);
      expect(huya, isNotNull);
      expect(huya!.id, '1');
      expect(huya.name, '英雄联盟');
    });
  });
}
