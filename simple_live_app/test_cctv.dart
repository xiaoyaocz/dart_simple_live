import "package:simple_live_app/requests/http_client.dart";
import "package:simple_live_app/modules/iptv/parser/m3u_parser.dart";

void main() async {
  const url = "https://peterhchina.github.io/iptv/IPTV-V4.m3u";
  final content = await HttpClient.instance.getText(url);
  final result = M3uParser.parse(content, baseUrl: url);
  final cctv = result.channels.where((e) => e.group.contains("央视")).toList();
  print("央视频道总数：${cctv.length}");
  for (final ch in cctv) {
    print("${ch.name} | group: ${ch.group}");
  }
}
