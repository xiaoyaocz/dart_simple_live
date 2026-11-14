import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('LiveUrlParser', () {
    LiveParsedUrl? parse(String url) => LiveUrlParser.parse(url);

    test('live.douyin.com 数字房间号', () {
      final result = parse("https://live.douyin.com/123456789");
      expect(result, isNotNull);
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "123456789");
      expect(result.isShortLink, isFalse);
    });

    test('房间号含点号不被截断', () {
      final result = parse("https://live.douyin.com/123.456");
      expect(result!.roomId, "123.456");

      final huya = parse("https://www.huya.com/abc.def");
      expect(huya!.siteId, LiveUrlParser.siteHuya);
      expect(huya.roomId, "abc.def");
    });

    test('www.douyin.com/live/数字', () {
      final result = parse("https://www.douyin.com/live/884412345678");
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "884412345678");
    });

    test('www.douyin.com/follow/live/数字', () {
      final result =
          parse("https://www.douyin.com/follow/live/884412345678?from=tab");
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "884412345678");
    });

    test('www.douyin.com 非直播路径不解析', () {
      expect(parse("https://www.douyin.com/video/7123456789012"), isNull);
      expect(parse("https://www.douyin.com/user/MS4wLjABAAAA"), isNull);
      expect(parse("https://www.douyin.com/live"), isNull);
      expect(parse("https://www.douyin.com/follow/live"), isNull);
    });

    test('host 大小写不敏感', () {
      final result = parse("HTTPS://LIVE.DOUYIN.COM/123456");
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "123456");
    });

    test('不带协议头的链接', () {
      final result = parse("live.douyin.com/123456");
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "123456");
    });

    test('v.douyin.com 短链', () {
      final result = parse("https://v.douyin.com/iAbC12d3/");
      expect(result!.isShortLink, isTrue);
      expect(result.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, isEmpty);
    });

    test('webcast.amemv.com reflow 链接', () {
      final result =
          parse("https://webcast.amemv.com/douyin/webcast/reflow/7012345678");
      expect(result!.siteId, LiveUrlParser.siteDouyin);
      expect(result.roomId, "7012345678");
    });

    test('bilibili 直播间', () {
      final result = parse("https://live.bilibili.com/2225346?spm_id_from=x");
      expect(result!.siteId, LiveUrlParser.siteBilibili);
      expect(result.roomId, "2225346");
    });

    test('b23.tv 短链', () {
      final result = parse("https://b23.tv/Ab12Cd3");
      expect(result!.isShortLink, isTrue);
      expect(result.siteId, LiveUrlParser.siteBilibili);
    });

    test('斗鱼房间与 topic rid', () {
      final room = parse("https://www.douyu.com/4492468");
      expect(room!.siteId, LiveUrlParser.siteDouyu);
      expect(room.roomId, "4492468");

      final topic = parse("https://www.douyu.com/topic/xyz?rid=5087042");
      expect(topic!.siteId, LiveUrlParser.siteDouyu);
      expect(topic.roomId, "5087042");
    });

    test('虎牙房间号', () {
      final result = parse("https://www.huya.com/660148");
      expect(result!.siteId, LiveUrlParser.siteHuya);
      expect(result.roomId, "660148");
    });

    test('快手房间与短链', () {
      final room = parse("https://live.kuaishou.com/u/vvvy");
      expect(room!.siteId, LiveUrlParser.siteKuaishou);
      expect(room.roomId, "vvvy");

      final short = parse("https://v.kuaishou.com/nQxz1");
      expect(short!.isShortLink, isTrue);
      expect(short.siteId, LiveUrlParser.siteKuaishou);
    });

    test('无法识别的链接返回 null', () {
      expect(parse("https://example.com/123"), isNull);
      expect(parse("https://live.bilibili.com/"), isNull);
      expect(parse(""), isNull);
      expect(parse("随便一段话"), isNull);
    });
  });
}
