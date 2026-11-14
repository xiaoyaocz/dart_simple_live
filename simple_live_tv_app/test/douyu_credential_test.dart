import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/utils.dart';

void main() {
  group('parseVersion', () {
    test('parses plain x.y.z versions', () {
      expect(Utils.parseVersion("1.8.2"), 10802);
      expect(Utils.parseVersion("1.9.10"), 10910);
    });

    test('tolerates build suffixes instead of throwing', () {
      // 回归：SlotSun 曾因 "-local.1" 后缀导致 int.parse 崩溃
      expect(Utils.parseVersion("1.8.2+10802"), 10802);
      expect(Utils.parseVersion("1.8.2-local.1"), 10802);
    });

    test('returns 0 for empty or malformed input', () {
      expect(Utils.parseVersion(""), 0);
      expect(Utils.parseVersion("abc"), 0);
    });
  });

  group('douyu credential extraction (sync compatibility)', () {
    test('extracts ltp0 and dy_did from synced cookie', () {
      // 同步链路只传 cookie 字符串，接收端应能从中提取续期凭据
      const cookie = 'dy_did=1234567890abcdef1234567890abcdef; '
          'acf_did=1234567890abcdef1234567890abcdef; LTP0=renewal-token';
      expect(
        DouyuPassport.cookieValue(cookie, 'LTP0'),
        'renewal-token',
      );
      expect(
        DouyuPassport.cookieValue(cookie, 'dy_did'),
        '1234567890abcdef1234567890abcdef',
      );
    });

    test('missing credentials extract to empty string', () {
      expect(DouyuPassport.cookieValue('acf_uid=42', 'LTP0'), '');
      expect(DouyuPassport.cookieValue('', 'dy_did'), '');
    });
  });
}
