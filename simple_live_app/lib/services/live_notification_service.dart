import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/routes/app_navigation.dart';

class LiveOnlineEvent {
  const LiveOnlineEvent({
    required this.followId,
    required this.siteId,
    required this.roomId,
    required this.userName,
    required this.categoryName,
  });

  final String followId;
  final String siteId;
  final String roomId;
  final String userName;
  final String categoryName;
}

/// Pure transition tracker that detects followed streamers going from offline (1)
/// to live (2) while skipping the initial startup baseline and preventing repeat
/// notifications within [cooldown].
class LiveOnlineTransitionTracker {
  LiveOnlineTransitionTracker({
    DateTime Function()? now,
    this.cooldown = const Duration(minutes: 10),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration cooldown;

  final Map<String, int> _lastKnownStatus = {};
  final Map<String, DateTime> _lastNotifiedAt = {};

  void reset() {
    _lastKnownStatus.clear();
    _lastNotifiedAt.clear();
  }

  /// Processes a completed status snapshot and returns newly-live transitions.
  /// Status values follow [FollowUser.liveStatus]: 0 = unknown, 1 = offline, 2 = live.
  List<LiveOnlineEvent> recordSnapshot(Iterable<FollowUser> users) {
    final now = _now();
    final newlyLive = <LiveOnlineEvent>[];
    final currentIds = <String>{};

    for (final user in users) {
      currentIds.add(user.id);
      final status = user.liveStatus.value;
      if (status != 1 && status != 2) continue;

      final previous = _lastKnownStatus[user.id];
      _lastKnownStatus[user.id] = status;

      if (previous == 1 && status == 2) {
        final lastNotified = _lastNotifiedAt[user.id];
        if (lastNotified == null || now.difference(lastNotified) >= cooldown) {
          _lastNotifiedAt[user.id] = now;
          newlyLive.add(LiveOnlineEvent(
            followId: user.id,
            siteId: user.siteId,
            roomId: user.roomId,
            userName: user.userName,
            categoryName: user.categoryName?.trim() ?? '',
          ));
        }
      }
    }

    _lastKnownStatus.removeWhere((id, _) => !currentIds.contains(id));
    return newlyLive;
  }
}

class LiveNotificationService extends GetxService {
  LiveNotificationService({
    LiveOnlineTransitionTracker? tracker,
    Future<void> Function(String title, String body, String siteId, String roomId)?
        showOverride,
  })  : _tracker = tracker ?? LiveOnlineTransitionTracker(),
        _showOverride = showOverride;

  static LiveNotificationService get instance =>
      Get.find<LiveNotificationService>();

  static const _windowChannel = MethodChannel('simple_live/window');
  static const _androidChannel = MethodChannel('simple_live/notification');

  final LiveOnlineTransitionTracker _tracker;
  final Future<void> Function(
      String title, String body, String siteId, String roomId)? _showOverride;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (Platform.isAndroid) {
      _androidChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationClick') {
          final args = call.arguments;
          if (args is Map) {
            await handleNotificationClick(
              args['siteId']?.toString() ?? '',
              args['roomId']?.toString() ?? '',
            );
          }
        }
      });
      try {
        final initial =
            await _androidChannel.invokeMethod<dynamic>('getInitialNotification');
        if (initial is Map) {
          final siteId = initial['siteId']?.toString() ?? '';
          final roomId = initial['roomId']?.toString() ?? '';
          if (siteId.isNotEmpty && roomId.isNotEmpty) {
            Future<void>.delayed(const Duration(milliseconds: 800), () {
              unawaited(handleNotificationClick(siteId, roomId));
            });
          }
        }
      } catch (e) {
        Log.d('读取初始通知参数失败：$e');
      }
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted =
          await _androidChannel.invokeMethod<bool>('requestPermission');
      return granted ?? true;
    } catch (e) {
      Log.d('请求通知权限失败：$e');
      return false;
    }
  }

  Future<void> handleFollowRefreshCompleted(Iterable<FollowUser> users) async {
    final newlyLive = _tracker.recordSnapshot(users);
    if (newlyLive.isEmpty) return;
    if (Get.isRegistered<AppSettingsController>() &&
        !AppSettingsController.instance.liveNotificationEnable.value) {
      return;
    }

    if (newlyLive.length <= 3) {
      for (final event in newlyLive) {
        final siteName = Sites.allSites[event.siteId]?.name ?? event.siteId;
        final subtitle = event.categoryName.isNotEmpty
            ? '$siteName · ${event.categoryName}'
            : '$siteName · 点击进入直播间';
        await showNotification(
          title: '${event.userName} 开播了',
          body: subtitle,
          siteId: event.siteId,
          roomId: event.roomId,
        );
      }
      return;
    }

    final first = newlyLive.first;
    final names = newlyLive.take(3).map((e) => e.userName).join('、');
    await showNotification(
      title: '${newlyLive.length} 位关注主播开播了',
      body: '$names 等已开播，点击查看',
      siteId: first.siteId,
      roomId: first.roomId,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String siteId,
    required String roomId,
  }) async {
    if (_showOverride != null) {
      await _showOverride!(title, body, siteId, roomId);
      return;
    }
    try {
      if (Platform.isWindows) {
        await _windowChannel.invokeMethod('showNotification', {
          'title': title,
          'body': body,
          'siteId': siteId,
          'roomId': roomId,
        });
      } else if (Platform.isAndroid) {
        await _androidChannel.invokeMethod('showNotification', {
          'title': title,
          'body': body,
          'siteId': siteId,
          'roomId': roomId,
        });
      }
    } catch (e) {
      Log.d('发送开播通知失败：$e');
    }
  }

  Future<void> handleNotificationClick(String siteId, String roomId) async {
    if (siteId.isEmpty || roomId.isEmpty) return;
    final site = Sites.allSites[siteId];
    if (site == null) return;
    await AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
  }

  @override
  void onClose() {
    if (Platform.isAndroid) {
      _androidChannel.setMethodCallHandler(null);
    }
    super.onClose();
  }
}
