import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';

void main() {
  test('layout corrections stay on the device across full settings sync', () {
    final settings = <String, dynamic>{
      LocalStorageService.kMobileTopExtraInset: 24,
      LocalStorageService.kMobileBottomExtraInset: 12,
      LocalStorageService.kThemeMode: 2,
      LocalStorageService.kHardwareDecode: false,
    };

    final exported = ProfileBackupService.stripDeviceLocalSettings(settings);

    expect(exported, {
      LocalStorageService.kThemeMode: 2,
      LocalStorageService.kHardwareDecode: false,
    });
    expect(settings[LocalStorageService.kMobileTopExtraInset], 24);
    expect(settings[LocalStorageService.kMobileBottomExtraInset], 12);
  });
}
