import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/utils.dart';

void main() {
  group('parseVersion', () {
    test('parses plain x.y.z versions', () {
      expect(Utils.parseVersion("1.13.2"), 11302);
      expect(Utils.parseVersion("1.9.0"), 10900);
    });

    test('tolerates build suffixes instead of throwing', () {
      // 回归：SlotSun 曾因 "-local.1" 后缀导致 int.parse 崩溃
      expect(Utils.parseVersion("1.13.2+11302"), 11302);
      expect(Utils.parseVersion("1.13.2-local.1"), 11302);
      expect(Utils.parseVersion("1.13.2-local"), 11302);
    });

    test('tolerates whitespace and junk segments', () {
      expect(Utils.parseVersion(" 1.13.2 "), 11302);
      expect(Utils.parseVersion("1.13.beta"), 11300);
    });

    test('returns 0 for empty or malformed input', () {
      expect(Utils.parseVersion(""), 0);
      expect(Utils.parseVersion("abc"), 0);
    });
  });
}
