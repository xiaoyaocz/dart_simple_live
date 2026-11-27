import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';

void main() {
  group('WebDavAutoSyncService', () {
    test('coalesces rapid local mutations into a single debounced upload',
        () async {
      var uploadCount = 0;
      final uploadDone = Completer<void>();

      final service = WebDavAutoSyncService(
        debounceDuration: const Duration(milliseconds: 40),
        hasCredentialsOverride: () => true,
        autoSyncEnabledOverride: () => true,
        buildBackupBytesOverride: () async => [1, 2, 3],
        uploadOverride: (_) async {
          uploadCount++;
          if (!uploadDone.isCompleted) uploadDone.complete();
        },
      );

      service.scheduleUpload();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.scheduleUpload();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.scheduleUpload();

      await uploadDone.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(uploadCount, 1);
      service.onClose();
    });

    test('skips upload and startup pull when auto-sync is disabled', () async {
      var uploadCount = 0;
      var downloadCount = 0;

      final service = WebDavAutoSyncService(
        debounceDuration: const Duration(milliseconds: 20),
        startupDelay: const Duration(milliseconds: 20),
        hasCredentialsOverride: () => true,
        autoSyncEnabledOverride: () => false,
        buildBackupBytesOverride: () async => [1, 2, 3],
        uploadOverride: (_) async => uploadCount++,
        downloadOverride: () async {
          downloadCount++;
          return [];
        },
      );

      service.scheduleStartupSync();
      service.scheduleUpload();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(uploadCount, 0);
      expect(downloadCount, 0);
      service.onClose();
    });

    test('suppresses scheduleUpload during cloud recovery to avoid sync loop',
        () async {
      var uploadCount = 0;
      late final WebDavAutoSyncService service;
      service = WebDavAutoSyncService(
        debounceDuration: const Duration(milliseconds: 20),
        hasCredentialsOverride: () => true,
        autoSyncEnabledOverride: () => true,
        buildBackupBytesOverride: () async => [1, 2, 3],
        uploadOverride: (_) async => uploadCount++,
        downloadOverride: () async {
          // Simulate local DB mutations triggered while applying cloud backup
          service.scheduleUpload();
          throw StateError('abort after simulating in-recovery mutation');
        },
      );

      final ok = await service.recoverSilent();
      expect(ok, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(uploadCount, 0);
      service.onClose();
    });

    test('triggers startup pull when enabled and credentials exist', () async {
      final downloaded = Completer<void>();
      final service = WebDavAutoSyncService(
        startupDelay: const Duration(milliseconds: 20),
        hasCredentialsOverride: () => true,
        autoSyncEnabledOverride: () => true,
        downloadOverride: () async {
          if (!downloaded.isCompleted) downloaded.complete();
          throw StateError('stop after verifying startup trigger');
        },
      );

      service.scheduleStartupSync();
      await downloaded.future.timeout(const Duration(seconds: 2));
      service.onClose();
    });
  });
}
