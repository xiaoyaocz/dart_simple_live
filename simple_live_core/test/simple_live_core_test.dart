import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  CoreLog.requestLogType = RequestLogType.short;

  // 测试哔哩哔哩
  group('bilibili tests', () {
    final BiliBiliSite site = BiliBiliSite();
    var rooms = <LiveRoomItem>[];
    test('getRecommendRooms', () async {
      final result = await site.getRecommendRooms();
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
      rooms = result.items;
    });
    var categores = <LiveCategory>[];
    test('getCategores', () async {
      categores = await site.getCategores();
      expect(categores, isNotEmpty);
      expect(categores.first.children, isNotEmpty);
    });

    test('getCategoryRooms', () async {
      var result = await site.getCategoryRooms(categores.first.children.first);
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchRooms', () async {
      var result = await site.searchRooms('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchAnchors', () async {
      var result = await site.searchAnchors('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    LiveRoomDetail? roomDetail;
    test('getRoomDetail', () async {
      roomDetail = await site.getRoomDetail(roomId: rooms.first.roomId);
      expect(roomDetail, isNotNull);
      expect(roomDetail?.roomId, isNotEmpty);
      expect(roomDetail?.danmakuData, isNotNull);
    });
    List<LivePlayQuality> playQualities = [];
    test('getPlayQuality', () async {
      playQualities = await site.getPlayQualites(detail: roomDetail!);
      expect(playQualities, isNotEmpty);
      expect(playQualities.first.quality, isNotEmpty);
    });
    test('getPlayUrls', () async {
      var urls = await site.getPlayUrls(
          detail: roomDetail!, quality: playQualities.first);
      expect(urls, isNotNull);
      expect(urls, isNotEmpty);
    });
    test('getDanmaku', () async {
      var danmaku = site.getDanmaku();
      expect(danmaku, isNotNull);
      expect(danmaku, isA<BiliBiliDanmaku>());
      var closed = false;
      var ready = false;
      danmaku.onReady = () {
        print('ready');
        ready = true;
      };
      danmaku.onClose = (msg) {
        print('onClose $msg');
        closed = true;
      };
      var msgCount = 0;
      danmaku.onMessage = (LiveMessage msg) {
        print('onMessage ${msg.type} ${msg.message}');
        msgCount++;
      };
      await danmaku.start(roomDetail!.danmakuData);
      // 接收30秒的弹幕
      await Future.delayed(const Duration(seconds: 30));
      expect(ready, isTrue);
      expect(closed, isFalse);
      expect(msgCount, greaterThan(0));
      await danmaku.stop();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });

  // 测试斗鱼
  group('douyu tests', () {
    final DouyuSite site = DouyuSite();
    var rooms = <LiveRoomItem>[];
    test('getRecommendRooms', () async {
      final result = await site.getRecommendRooms();
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
      rooms = result.items;
    });
    var categores = <LiveCategory>[];
    test('getCategores', () async {
      categores = await site.getCategores();
      expect(categores, isNotEmpty);
      expect(categores.first.children, isNotEmpty);
    });

    test('getCategoryRooms', () async {
      var result = await site.getCategoryRooms(categores.first.children.first);
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchRooms', () async {
      var result = await site.searchRooms('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchAnchors', () async {
      var result = await site.searchAnchors('联盟');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    LiveRoomDetail? roomDetail;
    test('getRoomDetail', () async {
      roomDetail = await site.getRoomDetail(roomId: rooms.first.roomId);
      expect(roomDetail, isNotNull);
      expect(roomDetail?.roomId, isNotEmpty);
      expect(roomDetail?.danmakuData, isNotNull);
    });
    List<LivePlayQuality> playQualities = [];
    test('getPlayQuality', () async {
      playQualities = await site.getPlayQualites(detail: roomDetail!);
      expect(playQualities, isNotEmpty);
      expect(playQualities.first.quality, isNotEmpty);
    });
    test('getPlayUrls', () async {
      var urls = await site.getPlayUrls(
          detail: roomDetail!, quality: playQualities.first);
      expect(urls, isNotNull);
      expect(urls, isNotEmpty);
    });
    test('getDanmaku', () async {
      var danmaku = site.getDanmaku();
      expect(danmaku, isNotNull);
      expect(danmaku, isA<DouyuDanmaku>());
      var closed = false;
      var ready = false;
      danmaku.onReady = () {
        print('ready');
        ready = true;
      };
      danmaku.onClose = (msg) {
        print('onClose $msg');
        closed = true;
      };
      var msgCount = 0;
      danmaku.onMessage = (LiveMessage msg) {
        print('onMessage ${msg.type} ${msg.message}');
        msgCount++;
      };
      await danmaku.start(roomDetail!.danmakuData);
      // 接收30秒的弹幕
      await Future.delayed(const Duration(seconds: 30));
      expect(ready, isTrue);
      expect(closed, isFalse);
      expect(msgCount, greaterThan(0));
      await danmaku.stop();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });

  // 测试虎牙
  group('huya tests', () {
    final HuyaSite site = HuyaSite();
    var rooms = <LiveRoomItem>[];
    test('getRecommendRooms', () async {
      final result = await site.getRecommendRooms();
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
      rooms = result.items;
    });
    var categores = <LiveCategory>[];
    test('getCategores', () async {
      categores = await site.getCategores();
      expect(categores, isNotEmpty);
      expect(categores.first.children, isNotEmpty);
    });

    test('getCategoryRooms', () async {
      var result = await site.getCategoryRooms(categores.first.children.first);
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchRooms', () async {
      var result = await site.searchRooms('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchAnchors', () async {
      var result = await site.searchAnchors('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    LiveRoomDetail? roomDetail;
    test('getRoomDetail', () async {
      roomDetail = await site.getRoomDetail(roomId: rooms.first.roomId);
      expect(roomDetail, isNotNull);
      expect(roomDetail?.roomId, isNotEmpty);
      expect(roomDetail?.danmakuData, isNotNull);
    });
    List<LivePlayQuality> playQualities = [];
    test('getPlayQuality', () async {
      playQualities = await site.getPlayQualites(detail: roomDetail!);
      expect(playQualities, isNotEmpty);
      expect(playQualities.first.quality, isNotEmpty);
    });
    test('getPlayUrls', () async {
      var urls = await site.getPlayUrls(
          detail: roomDetail!, quality: playQualities.first);
      expect(urls, isNotNull);
      expect(urls, isNotEmpty);
    });
    test('getDanmaku', () async {
      var danmaku = site.getDanmaku();
      expect(danmaku, isNotNull);
      expect(danmaku, isA<HuyaDanmaku>());
      var closed = false;
      var ready = false;
      danmaku.onReady = () {
        print('ready');
        ready = true;
      };
      danmaku.onClose = (msg) {
        print('onClose $msg');
        closed = true;
      };
      var msgCount = 0;
      danmaku.onMessage = (LiveMessage msg) {
        print('onMessage ${msg.type} ${msg.message}');
        msgCount++;
      };
      await danmaku.start(roomDetail!.danmakuData);
      // 接收30秒的弹幕
      await Future.delayed(const Duration(seconds: 30));
      expect(ready, isTrue);
      expect(closed, isFalse);
      expect(msgCount, greaterThan(0));
      await danmaku.stop();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });

  // 测试抖音
  group('douyin tests', () {
    final DouyinSite site = DouyinSite();
    var rooms = <LiveRoomItem>[];
    test('getRecommendRooms', () async {
      final result = await site.getRecommendRooms();
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
      rooms = result.items;
    });
    var categores = <LiveCategory>[];
    test('getCategores', () async {
      categores = await site.getCategores();
      expect(categores, isNotEmpty);
      expect(categores.first.children, isNotEmpty);
    });

    test('getCategoryRooms', () async {
      var result = await site.getCategoryRooms(categores.first.children.first);
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });
    test('searchRooms', () async {
      var result = await site.searchRooms('LOL');
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
    });

    LiveRoomDetail? roomDetail;
    test('getRoomDetail', () async {
      roomDetail = await site.getRoomDetail(roomId: rooms.first.roomId);
      expect(roomDetail, isNotNull);
      expect(roomDetail?.roomId, isNotEmpty);
      expect(roomDetail?.danmakuData, isNotNull);
    });
    List<LivePlayQuality> playQualities = [];
    test('getPlayQuality', () async {
      playQualities = await site.getPlayQualites(detail: roomDetail!);
      expect(playQualities, isNotEmpty);
      expect(playQualities.first.quality, isNotEmpty);
      print(playQualities.map((play) => play.quality).join('\r\n'));
    });
    test('getPlayUrls', () async {
      var urls = await site.getPlayUrls(
          detail: roomDetail!, quality: playQualities.first);
      expect(urls, isNotNull);
      expect(urls, isNotEmpty);
      print(urls);
    });
    test('getDanmaku', () async {
      var danmaku = site.getDanmaku();
      expect(danmaku, isNotNull);
      expect(danmaku, isA<DouyinDanmaku>());
      var closed = false;
      var ready = false;
      danmaku.onReady = () {
        print('ready');
        ready = true;
      };
      danmaku.onClose = (msg) {
        print('onClose $msg');
        closed = true;
      };
      var msgCount = 0;
      danmaku.onMessage = (LiveMessage msg) {
        print('onMessage ${msg.type} ${msg.message}');
        msgCount++;
      };
      await danmaku.start(roomDetail!.danmakuData);
      // 接收30秒的弹幕
      await Future.delayed(const Duration(seconds: 30));
      expect(ready, isTrue);
      expect(closed, isFalse);
      expect(msgCount, greaterThan(0));
      await danmaku.stop();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}
