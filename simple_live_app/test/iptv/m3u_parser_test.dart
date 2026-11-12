import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/iptv/parser/m3u_parser.dart';

void main() {
  test('解析完整属性的频道', () {
    const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="c1" tvg-name="别名" tvg-logo="http://logo/c1.png" group-title="新闻",新闻频道
http://stream/c1.m3u8
''';
    final result = M3uParser.parse(content);
    expect(result.channels, hasLength(1));
    final channel = result.channels.first;
    expect(channel.id, "c1");
    expect(channel.name, "新闻频道");
    expect(channel.logo, "http://logo/c1.png");
    expect(channel.group, "新闻");
    expect(channel.url, "http://stream/c1.m3u8");
  });

  test('提取头部 url-tvg，支持多个', () {
    const content = '''
#EXTM3U url-tvg="http://epg/a.xml" x-tvg-url="http://epg/ignore.xml"
#EXTINF:-1,频道
http://stream/a.m3u8
''';
    final result = M3uParser.parse(content);
    expect(result.epgUrls, ["http://epg/a.xml"]);
  });

  test('缺失分组与 tvg-id 时兜底', () {
    const content = '''
#EXTM3U
#EXTINF:-1,裸频道
http://stream/b.m3u8
''';
    final channel = M3uParser.parse(content).channels.first;
    expect(channel.group, M3uParser.defaultGroup);
    expect(channel.id, "http://stream/b.m3u8");
  });

  test('无 EXTINF 的裸地址与空行、注释被正确处理', () {
    const content = '''
#EXTM3U

# 某注释
http://stream/c.m3u8
''';
    final result = M3uParser.parse(content);
    expect(result.channels, hasLength(1));
    expect(result.channels.first.name, "http://stream/c.m3u8");
  });

  test('支持 EXTGRP 分组', () {
    const content = '''
#EXTM3U
#EXTGRP:体育
#EXTINF:-1,体育台
http://stream/d.m3u8
''';
    expect(M3uParser.parse(content).channels.first.group, "体育");
  });

  test('相对地址按 baseUrl 补全', () {
    const content = '''
#EXTM3U
#EXTINF:-1 tvg-logo="logo.png",本地频道
channels/live.m3u8
''';
    final channel = M3uParser
        .parse(content, baseUrl: "https://host/sub/index.m3u")
        .channels
        .first;
    expect(channel.url, "https://host/sub/channels/live.m3u8");
    expect(channel.logo, "https://host/sub/logo.png");
  });
}
