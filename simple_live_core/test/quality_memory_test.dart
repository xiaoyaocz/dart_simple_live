import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

LivePlayQuality q(String name) => LivePlayQuality(quality: name, data: null);

void main() {
  group('QualityMemory', () {
    test('按名称精确匹配', () {
      final qualities = [q("蓝光8M"), q("蓝光4M"), q("高清"), q("流畅")];
      expect(
        QualityMemory.resolveIndex(
          qualities: qualities,
          savedName: "高清",
          savedOffset: 2,
        ),
        2,
      );
    });

    test('名称不存在时按距最高档偏移兜底', () {
      final qualities = [q("原画"), q("高清"), q("流畅")];
      // 上次在另一房间选的 "蓝光8M"（当时是第 1 档），本房间没有该名称。
      expect(
        QualityMemory.resolveIndex(
          qualities: qualities,
          savedName: "蓝光8M",
          savedOffset: 0,
        ),
        0,
      );
    });

    test('偏移越界时返回 -1', () {
      final qualities = [q("原画"), q("流畅")];
      expect(
        QualityMemory.resolveIndex(
          qualities: qualities,
          savedName: "蓝光8M",
          savedOffset: 3,
        ),
        -1,
      );
    });

    test('名称与偏移都缺失时返回 -1', () {
      final qualities = [q("原画")];
      expect(
        QualityMemory.resolveIndex(qualities: qualities),
        -1,
      );
    });

    test('条目编解码', () {
      final encoded = QualityMemory.encodeEntry(
        qualityName: "蓝光8M",
        offsetFromTop: 0,
      );
      final decoded = QualityMemory.decodeEntry(encoded)!;
      expect(decoded.name, "蓝光8M");
      expect(decoded.offset, 0);

      expect(QualityMemory.decodeEntry(null), isNull);
      expect(QualityMemory.decodeEntry("x"), isNull);
      expect(QualityMemory.decodeEntry({"name": "", "offset": 0}), isNull);
      expect(QualityMemory.decodeEntry({"name": "原画", "offset": -1}), isNull);
      expect(QualityMemory.decodeEntry({"name": "原画", "offset": "0"}), isNull);
    });
  });
}
