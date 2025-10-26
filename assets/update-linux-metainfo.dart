import 'dart:convert';
import 'dart:io';

String _xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

void main() {
  final projectRoot = Directory.current.path;
  final jsonPath = '$projectRoot/assets/app_version.json';
  final targetPath =
      '$projectRoot/simple_live_app/assets/io.github.SlotSun.dart_simple_live.metainfo.xml';

  final jsonFile = File(jsonPath);
  if (!jsonFile.existsSync()) {
    stderr.writeln('app_version.json not found: $jsonPath');
    exit(2);
  }

  final targetFile = File(targetPath);
  if (!targetFile.existsSync()) {
    stderr.writeln('target file not found: $targetPath');
    exit(2);
  }

  final map = json.decode(jsonFile.readAsStringSync());
  final version = (map['version'] ?? '').toString();
  final desc = (map['version_desc'] ?? '').toString();

  final date = DateTime.now().toIso8601String().split('T').first;

  final releaseBlock = [
    '    <release version="$version" date="$date">',
    '      <description>',
    for (final line in desc.split('\n'))
      '        <p>${_xmlEscape(line.replaceAll("\r", ""))}</p>',
    '      </description>',
    '    </release>',
  ].join('\n');

  final content = targetFile.readAsStringSync();

  final releasesReg = RegExp(
    r'(<releases\b[^>]*>)([\s\S]*?)(  </releases>)',
    multiLine: true,
    dotAll: true,
  );

  // 直接替换第一个 <releases> 区块（如果不存在则 content 保持不变）
  final newContent = content.replaceFirstMapped(
    releasesReg,
    (m) => '${m.group(1)}\n$releaseBlock\n${m.group(3)}',
  );

  targetFile.writeAsStringSync(newContent);
  stdout.writeln('Update Done: $targetPath');
}
