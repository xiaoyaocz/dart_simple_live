import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/sync/local_sync/scan_qr/sync_scan_qr_controller.dart';

void main() {
  test('识别旧版和带局域网地址的房间二维码', () {
    expect(parseSyncQrCode(' E3GUCD '), 'E3GUCD');
    expect(parseSyncQrCode('E3GUCD|192.168.3.139'), 'E3GUCD|192.168.3.139');
  });

  test('识别局域网同步地址并忽略无关二维码', () {
    expect(parseSyncQrCode('192.168.3.139;192.168.3.140'),
        '192.168.3.139;192.168.3.140');
    expect(parseSyncQrCode('https://example.com'), isNull);
    expect(parseSyncQrCode(''), isNull);
  });
}
