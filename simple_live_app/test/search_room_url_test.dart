import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/search/search_room_url.dart';

void main() {
  test('B站官方桌面房间 blanc 路由可识别并保留房间防串检查', () {
    expect(SearchRoomUrl.roomIdFor('bilibili',
        Uri.parse('https://live.bilibili.com/blanc/7734200')), '7734200');
    expect(SearchRoomUrl.roomIdFor('bilibili',
        Uri.parse('https://live.bilibili.com/blanc/search')), isNull);
  });
  test('抖音关注页内直播房间地址可识别，不把关注列表当作房间', () {
    expect(
        SearchRoomUrl.roomIdFor(
            'douyin',
            Uri.parse(
                'https://www.douyin.com/follow/live/46912316249?anchor_id=1')),
        '46912316249');
    expect(
        SearchRoomUrl.roomIdFor('douyin',
            Uri.parse('https://www.douyin.com/follow/live/67839072609')),
        '67839072609');
    expect(
        SearchRoomUrl.roomIdFor(
            'douyin', Uri.parse('https://www.douyin.com/follow')),
        isNull);
  });
  test('手机网页重定向后的房间地址仍可识别', () {
    const cases = [
      (
        Constant.kBiliBili,
        'https://live.bilibili.com/h5/12345?broadcast_type=0',
        '12345'
      ),
      (Constant.kBiliBili, 'https://m.bilibili.com/live/12345', '12345'),
      (Constant.kHuya, 'https://m.huya.com/my_room-1?from=search', 'my_room-1'),
      (Constant.kDouyu, 'https://m.douyu.com/98765?from=search', '98765'),
      (
        Constant.kDouyin,
        'https://www.douyin.com/root/live/921169302662',
        '921169302662'
      ),
    ];
    for (final (site, url, id) in cases) {
      expect(SearchRoomUrl.roomIdFor(site, Uri.parse(url)), id, reason: url);
    }
  });

  test('移动搜索、分类、用户页和伪装域名不识别为房间', () {
    const cases = [
      (Constant.kBiliBili, 'https://m.bilibili.com/video/123'),
      (Constant.kBiliBili, 'https://live.bilibili.com/h5/'),
      (Constant.kHuya, 'https://m.huya.com/search'),
      (Constant.kHuya, 'https://m.huya.com/g/1'),
      (Constant.kDouyu, 'https://m.douyu.com/search'),
      (Constant.kDouyu, 'https://m.douyu.com/directory'),
      (Constant.kDouyin, 'https://www.douyin.com/user/123'),
      (Constant.kHuya, 'https://m.huya.com.evil.test/123'),
      (Constant.kDouyu, 'https://evil.test/123?url=https://m.douyu.com/123'),
    ];
    for (final (site, url) in cases) {
      expect(SearchRoomUrl.roomIdFor(site, Uri.parse(url)), isNull,
          reason: url);
    }
  });

  test('每个平台打开对应的直播网站首页', () {
    expect(
        SearchRoomUrl.homeUriFor(Constant.kBiliBili).host, 'live.bilibili.com');
    expect(SearchRoomUrl.homeUriFor(Constant.kHuya).host, 'www.huya.com');
    expect(SearchRoomUrl.homeUriFor(Constant.kDouyu).host, 'www.douyu.com');
    expect(SearchRoomUrl.homeUriFor(Constant.kDouyin).host, 'live.douyin.com');
  });

  test('识别四个平台的直播间地址', () {
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kBiliBili,
        Uri.parse('https://live.bilibili.com/12345?spm=1'),
      ),
      '12345',
    );
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kHuya,
        Uri.parse('https://www.huya.com/my_room-1'),
      ),
      'my_room-1',
    );
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kDouyu,
        Uri.parse('https://www.douyu.com/98765'),
      ),
      '98765',
    );
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kDouyu,
        Uri.parse('https://www.douyu.com/topic/event?rid=5678'),
      ),
      '5678',
    );
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kDouyin,
        Uri.parse('https://live.douyin.com/1234567890'),
      ),
      '1234567890',
    );
    expect(
      SearchRoomUrl.roomIdFor(
        Constant.kDouyin,
        Uri.parse(
            'https://www.douyin.com/root/live/921169302662?room_id=7689851218365139754'),
      ),
      '921169302662',
    );
  });

  test('首页、搜索页及其他域名不显示跳转按钮', () {
    const cases = [
      (Constant.kBiliBili, 'https://live.bilibili.com/'),
      (Constant.kBiliBili, 'https://www.bilibili.com/video/12345'),
      (Constant.kHuya, 'https://www.huya.com/g/1'),
      (Constant.kHuya, 'https://www.huya.com/search'),
      (Constant.kHuya, 'https://www.huya.com/index'),
      (Constant.kHuya, 'https://www.huya.com/live'),
      (Constant.kHuya, 'https://www.huya.com/l/'),
      (Constant.kDouyu, 'https://www.douyu.com/search/abc'),
      (Constant.kDouyu, 'https://www.douyu.com/g_lol'),
      (Constant.kDouyin, 'https://www.douyin.com/search/abc?type=live'),
      (Constant.kDouyin, 'https://live.douyin.com/category'),
      (Constant.kBiliBili, 'https://live.bilibili.com.evil.test/12345'),
    ];
    for (final (site, url) in cases) {
      expect(SearchRoomUrl.roomIdFor(site, Uri.parse(url)), isNull);
    }
  });
}
