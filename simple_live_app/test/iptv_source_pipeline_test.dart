import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/iptv/parser/aggregated_channel.dart';
import 'package:simple_live_app/modules/iptv/parser/m3u_parser.dart';
import 'package:simple_live_app/services/iptv_service.dart';

void main() {
  group("M3U解析", () {
    test("标准M3U：tvg属性、group-title与英文频道名（autom3u示例）", () {
      const content = '''
#EXTM3U x-tvg-url="https://epg.pw/xmltv/epg_CN.xml.gz"
#EXTINF:-1 tvg-id="dce63b7f" tvg-name="Hebei TV" group-title="General" tvg-country="CN" tvg-language="zh",Hebei TV
https://event.pull.hebtv.com/live/live101.m3u8
#EXTINF:-1 tvg-id="ce881d0f" tvg-name="Guangxi TV" group-title="General;Travel",Guangxi Variety & Travel Channel
http://111.59.24.227:8181/tsfile/live/1001_1.m3u8?key=txi
''';
      final result = M3uParser.parse(content, baseUrl: "https://a.autom3u.com/playlist/country/cn.m3u");
      expect(result.channels.length, 2);
      expect(result.channels[0].name, "Hebei TV");
      expect(result.channels[0].group, "General");
      expect(result.channels[0].id, "dce63b7f");
      expect(result.channels[0].url, "https://event.pull.hebtv.com/live/live101.m3u8");
    });

    test("属性值内的逗号不影响频道名分隔", () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-name="CCTV5" group-title="Sports, Live",CCTV5 体育频道
http://example.com/cctv5p.m3u8
''';
      final result = M3uParser.parse(content);
      expect(result.channels.first.name, "CCTV5 体育频道");
      expect(result.channels.first.group, "Sports, Live");
    });

    test("TXT #genre# 格式：xisohi全量源样式", () {
      const content = '''
央视,#genre#
CCTV1,http://[2409:8087:8:21::18]:6610/otttv.bj.chinamobile.com/PLTV/88888888/224/3221226895/1.m3u8?
CCTV5,http://112.46.85.60:8009/hls/503/index.m3u8
卫视,#genre#
东方卫视,https://example.com/dongfang.m3u8
''';
      final result = M3uParser.parse(content);
      expect(result.channels.length, 3);
      expect(result.channels[0].group, "央视");
      expect(result.channels[0].name, "CCTV1");
      expect(result.channels[2].group, "卫视");
    });

    test("相对地址按订阅源URL补全", () {
      const content = '''
#EXTM3U
#EXTINF:-1,测试
/live/stream.m3u8
''';
      final result = M3uParser.parse(content, baseUrl: "https://example.com/iptv/list.m3u");
      expect(result.channels.first.url, "https://example.com/live/stream.m3u8");
    });
  });

  group("聚合缓存持久化", () {
    test("decodeAggregatedCache 往返还原频道与线路", () {
      final channels = [
        const AggregatedChannel(
          name: "CCTV-5体育",
          group: "央视频道",
          logo: "https://logo.example.com/cctv5.png",
          lines: [
            IptvLine(sourceName: "zhi35聚合源", url: "http://a.example.com/1.m3u8", logo: "", channelId: "cctv5"),
            IptvLine(sourceName: "suxuang全量源", url: "http://b.example.com/2.m3u8", logo: "http://l/2.png", channelId: "cctv5b"),
          ],
        ),
      ];
      final raw = IptvService.encodeAggregatedChannels(channels);
      final decoded = IptvService.decodeAggregatedCache(raw);
      expect(decoded, isNotNull);
      expect(decoded!.result.channels.length, 1);
      expect(decoded.result.channels.first.name, "CCTV-5体育");
      expect(decoded.result.channels.first.lines.length, 2);
      expect(decoded.result.channels.first.lines[0].sourceName, "zhi35聚合源");
      expect(decoded.time, isNotNull);
    });

    test("损坏或空缓存返回null", () {
      expect(IptvService.decodeAggregatedCache(""), isNull);
      expect(IptvService.decodeAggregatedCache("not-json"), isNull);
      expect(IptvService.decodeAggregatedCache('{"channels": []}'), isNull);
    });
  });
}
