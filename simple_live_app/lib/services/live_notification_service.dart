import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/models/db/follow_user.dart';

class LiveNotificationService {
  LiveNotificationService._();

  static const MethodChannel _channel =
      MethodChannel("simple_live/live_notifications");

  static Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        return true;
      }
      return (await Permission.notification.request()).isGranted;
    } catch (e) {
      Log.d("请求通知权限失败: $e");
      return false;
    }
  }

  static Future<void> showLiveStart(FollowUser item) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    final granted = await requestPermissionIfNeeded();
    if (!granted) {
      return;
    }
    try {
      await _channel.invokeMethod<void>("showLiveStart", {
        "notificationId": item.id.hashCode & 0x7fffffff,
        "title": "${item.userName} 开播了",
        "body": "点击回到 Simple Live 查看直播",
        "roomId": item.roomId,
        "siteId": item.siteId,
      });
    } catch (e) {
      Log.d("发送开播提醒失败: $e");
    }
  }
}
