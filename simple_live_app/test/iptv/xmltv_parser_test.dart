import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/iptv/parser/iptv_program.dart';
import 'package:simple_live_app/modules/iptv/parser/xmltv_parser.dart';

void main() {
  const xml = '''
<tv>
  <channel id="c1"><display-name>频道一</display-name></channel>
  <programme start="20260101120000 +0800" stop="20260101130000 +0800" channel="c1">
    <title>新闻</title><desc>新闻描述</desc>
  </programme>
  <programme start="20260101130000 +0800" stop="20260101140000 +0800" channel="c1">
    <title>纪录片</title>
  </programme>
</tv>
''';

  test('按频道索引并解析节目字段', () {
    final data = XmltvParser.parse(xml);
    final list = data.programsOf("c1");
    expect(list, hasLength(2));
    expect(list.first.title, "新闻");
    expect(list.first.desc, "新闻描述");
    expect(list.last.title, "纪录片");
    expect(list.last.desc, "");
  });

  test('查询当前与下一档节目', () {
    final data = XmltvParser.parse(xml);
    // 12:30 +0800 = 04:30 UTC，落在第一档
    final at = DateTime.utc(2026, 1, 1, 4, 30);
    expect(data.nowPlaying("c1", at: at)?.title, "新闻");
    expect(data.nextProgram("c1", at: at)?.title, "纪录片");
  });

  test('时间解析按时区转换为 UTC', () {
    expect(
      XmltvParser.parseTime("20260101120000 +0800"),
      DateTime.utc(2026, 1, 1, 4),
    );
    expect(
      XmltvParser.parseTime("20260101120000 +0000"),
      DateTime.utc(2026, 1, 1, 12),
    );
    expect(
      XmltvParser.parseTime("20260101120000 -0500"),
      DateTime.utc(2026, 1, 1, 17),
    );
    // 无时区按 UTC 处理
    expect(XmltvParser.parseTime("20260101120000"), DateTime.utc(2026, 1, 1, 12));
  });

  test('非法时间与缺失字段安全跳过', () {
    const bad = '''
<tv>
  <programme start="bad" stop="20260101130000 +0800" channel="c1"><title>x</title></programme>
</tv>''';
    final EpgData data = XmltvParser.parse(bad);
    expect(data.programsOf("c1"), isEmpty);
  });
}
