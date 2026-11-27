import 'dart:io';
import 'package:simple_live_app/services/window_appearance_controller.dart';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/player_output_policy.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSettingsController extends GetxController {
  AppSettingsController({PlayerOutputPolicy? outputPolicy})
      : outputPolicy = outputPolicy ?? PlayerOutputPolicy(Platform.operatingSystem);
  final PlayerOutputPolicy outputPolicy;
  static AppSettingsController get instance =>
      Get.find<AppSettingsController>();

  /// 缩放模式
  var scaleMode = 0.obs;

  var themeMode = 0.obs;

  var firstRun = false;

  @override
  void onInit() {
    themeMode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kThemeMode, 0);
    firstRun = LocalStorageService.instance
        .getValue(LocalStorageService.kFirstRun, true);
    danmuSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSize, 16.0);
    danmuOpacity.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuOpacity, 1.0);
    danmuArea.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuArea, 0.8);
    danmuSpeed.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuSpeed, 10.0);
    danmuEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuEnable, false);
    danmuStrokeWidth.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuStrokeWidth, 2.0);
    danmuTopMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuTopMargin, 0.0);
    danmuBottomMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuBottomMargin, 0.0);
    danmuFontWeight.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuFontWeight, 4);

    chatTextSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextSize, 14.0);

    chatTextGap.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextGap, 4.0);

    chatBubbleStyle.value = LocalStorageService.instance.getValue(
      LocalStorageService.kChatBubbleStyle,
      false,
    );

    autoExitEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitEnable, false);

    autoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitDuration, 60);

    roomAutoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kRoomAutoExitDuration, 60);

    playerAutoPause.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerAutoPause, false);

    autoFullScreen.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoFullScreen, false);

    // ignore: invalid_use_of_protected_member
    shieldList.value = LocalStorageService.instance.shieldBox.values.toSet();
    final rawShieldUsers = LocalStorageService.instance
        .getValue<dynamic>(LocalStorageService.kDanmuShieldUsers, const <String>[]);
    if (rawShieldUsers is List) {
      shieldUserList.assignAll(
        rawShieldUsers
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    danmuMergeDuplicate.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuMergeDuplicate, true);
    danmuMergeWindowSeconds.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuMergeWindowSeconds, 5)
        .clamp(2, 15);

    scaleMode.value = LocalStorageService.instance.getValue(
      LocalStorageService.kPlayerScaleMode,
      0,
    );

    playerVolume.value = LocalStorageService.instance.getValue(
      LocalStorageService.kPlayerVolume,
      100.0,
    );
    pipHideDanmu.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPIPHideDanmu, true);

    styleColor.value = LocalStorageService.instance
        .getValue(LocalStorageService.kStyleColor, 0xff3498db);

    isDynamic.value = LocalStorageService.instance
        .getValue(LocalStorageService.kIsDynamic, false);

    bilibiliLoginTip.value = LocalStorageService.instance
        .getValue(LocalStorageService.kBilibiliLoginTip, true);

    logEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kLogEnable, false);
    if (logEnable.value) {
      Log.initWriter();
    }

    autoUpdateFollowEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoUpdateFollowEnable, true);

    autoUpdateFollowDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowDuration, 10);

    updateFollowThreadCount.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowThreadCount, 0);  // 默认 0 = 自动

    liveNotificationEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kLiveNotificationEnable, false);

    webDavAutoSync.value = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVAutoSync, false);

    windowsSuperResolution.value = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowsSuperResolution, true);
    windowsInterpolation.value = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowsInterpolation, false);
    windowsAudioExclusive.value = LocalStorageService.instance
        .getValue(LocalStorageService.kWindowsAudioExclusive, false);

    initSiteSort();
    initHomeSort();

    super.onInit();
  }

  void initSiteSort() {
    var sort = LocalStorageService.instance
        .getValue(
          LocalStorageService.kSiteSort,
          Sites.allSites.keys.join(","),
        )
        .split(",");
    //如果数量与allSites的数量不一致，将缺失的添加上
    if (sort.length != Sites.allSites.length) {
      var keys = Sites.allSites.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        if (!sort.contains(keys[i])) {
          sort.add(keys[i]);
        }
      }
    }

    siteSort.value = sort;
  }

  void initHomeSort() {
    var sort = LocalStorageService.instance
        .getValue(
          LocalStorageService.kHomeSort,
          Constant.allHomePages.keys.join(","),
        )
        .split(",");
    //如果数量与allSites的数量不一致，将缺失的添加上
    if (sort.length != Constant.allHomePages.length) {
      var keys = Constant.allHomePages.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        if (!sort.contains(keys[i])) {
          sort.add(keys[i]);
        }
      }
    }

    homeSort.value = sort;
  }

  void setNoFirstRun() {
    LocalStorageService.instance.setValue(LocalStorageService.kFirstRun, false);
  }

  void changeTheme() {
    Get.dialog(
      RadioGroup(
        groupValue: themeMode.value,
        onChanged: (e) {
          Get.back();
          setTheme(e ?? 0);
        },
        child: const SimpleDialog(
          title: Text("设置主题"),
          children: [
            RadioListTile<int>(
              title: Text("跟随系统"),
              value: 0,
            ),
            RadioListTile<int>(
              title: Text("浅色模式"),
              value: 1,
            ),
            RadioListTile<int>(
              title: Text("深色模式"),
              value: 2,
            ),
          ],
        ),
      ),
    );
  }

  void setTheme(int i) {
    themeMode.value = i;
    var mode = ThemeMode.values[i];

    LocalStorageService.instance.setValue(LocalStorageService.kThemeMode, i);
    Get.changeThemeMode(mode);
    if (Get.isRegistered<WindowAppearanceController>()) {
      Get.find<WindowAppearanceController>().apply();
    }
  }

  // 最高画质优先，源码可启用跨画质档位的原生帧率优先策略。
  final preferNativeFrameRate = false.obs;

  final hardwareDecode = true.obs;

  var chatTextSize = 14.0.obs;
  void setChatTextSize(double e) {
    chatTextSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextSize, e);
  }

  var chatTextGap = 4.0.obs;
  void setChatTextGap(double e) {
    chatTextGap.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kChatTextGap, e);
  }

  var chatBubbleStyle = false.obs;
  void setChatBubbleStyle(bool e) {
    chatBubbleStyle.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kChatBubbleStyle, e);
  }

  var danmuSize = 16.0.obs;
  void setDanmuSize(double e) {
    danmuSize.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSize, e);
  }

  var danmuSpeed = 10.0.obs;
  void setDanmuSpeed(double e) {
    danmuSpeed.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuSpeed, e);
  }

  var danmuArea = 0.8.obs;
  void setDanmuArea(double e) {
    danmuArea.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuArea, e);
  }

  var danmuOpacity = 1.0.obs;
  void setDanmuOpacity(double e) {
    danmuOpacity.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuOpacity, e);
  }

  var danmuEnable = false.obs;
  void setDanmuEnable(bool e) {
    danmuEnable.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kDanmuEnable, e);
  }

  var danmuStrokeWidth = 2.0.obs;
  void setDanmuStrokeWidth(double e) {
    danmuStrokeWidth.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuStrokeWidth, e);
  }

  var danmuFontWeight = 4.obs;
  void setDanmuFontWeight(int e) {
    danmuFontWeight.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuFontWeight, e);
  }

  final qualityLevel = 2.obs;

  final qualityLevelCellular = 2.obs;

  var autoExitEnable = false.obs;
  void setAutoExitEnable(bool e) {
    autoExitEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitEnable, e);
  }

  var autoExitDuration = 60.obs;
  void setAutoExitDuration(int e) {
    autoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoExitDuration, e);
  }

  var roomAutoExitDuration = 60.obs;
  void setRoomAutoExitDuration(int e) {
    roomAutoExitDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kRoomAutoExitDuration, e);
  }

  final playerCompatMode = false.obs;

  final playerBufferSize = (Platform.isWindows ? 256 : 64).obs;

  /// Windows AI 超分着色器开关（FSRCNNX）
  var windowsSuperResolution = true.obs;
  void setWindowsSuperResolution(bool e) {
    windowsSuperResolution.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowsSuperResolution, e);
  }

  /// Windows 动态画面平滑（补帧）开关
  var windowsInterpolation = false.obs;
  void setWindowsInterpolation(bool e) {
    windowsInterpolation.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowsInterpolation, e);
  }

  /// Windows WASAPI 音频独占开关
  var windowsAudioExclusive = false.obs;
  void setWindowsAudioExclusive(bool e) {
    windowsAudioExclusive.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWindowsAudioExclusive, e);
  }

  /// 缓冲策略：0=均衡（默认），1=抗抖稳流，2=低延迟
  final playerBufferMode = 0.obs;

  /// 直播累积延迟自动微倍速追帧
  final liveCatchupEnable = true.obs;

  /// 开播/切清晰度前 CDN 线路测速优选
  final streamRouteProbeEnable = true.obs;

  var playerAutoPause = false.obs;
  void setPlayerAutoPause(bool e) {
    playerAutoPause.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerAutoPause, e);
  }

  final backgroundAudioOnly = true.obs;

  var autoFullScreen = false.obs;
  void setAutoFullScreen(bool e) {
    autoFullScreen.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoFullScreen, e);
  }

  var playershowSuperChat = true.obs;
  void setPlayerShowSuperChat(bool e) {
    playershowSuperChat.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerShowSuperChat, e);
  }

  RxSet<String> shieldList = <String>{}.obs;
  void addShieldList(String e) {
    final trimmed = e.trim();
    if (trimmed.isEmpty) return;
    if (!shieldList.add(trimmed)) return;
    LocalStorageService.instance.shieldBox.put(trimmed, trimmed);
    WebDavAutoSyncService.notifyLocalMutation();
  }

  void removeShieldList(String e) {
    if (!shieldList.remove(e)) return;
    LocalStorageService.instance.shieldBox.delete(e);
    WebDavAutoSyncService.notifyLocalMutation();
  }

  Future clearShieldList() async {
    shieldList.clear();
    await LocalStorageService.instance.shieldBox.clear();
    WebDavAutoSyncService.notifyLocalMutation();
  }

  RxSet<String> shieldUserList = <String>{}.obs;
  void addShieldUser(String userName) {
    final trimmed = userName.trim();
    if (trimmed.isEmpty) return;
    if (!shieldUserList.add(trimmed)) return;
    LocalStorageService.instance.setValue(
      LocalStorageService.kDanmuShieldUsers,
      shieldUserList.toList(),
    );
    WebDavAutoSyncService.notifyLocalMutation();
  }

  void removeShieldUser(String userName) {
    if (!shieldUserList.remove(userName)) return;
    LocalStorageService.instance.setValue(
      LocalStorageService.kDanmuShieldUsers,
      shieldUserList.toList(),
    );
    WebDavAutoSyncService.notifyLocalMutation();
  }

  var danmuMergeDuplicate = true.obs;
  void setDanmuMergeDuplicate(bool e) {
    danmuMergeDuplicate.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuMergeDuplicate, e);
  }

  var danmuMergeWindowSeconds = 5.obs;
  void setDanmuMergeWindowSeconds(int e) {
    final clamped = e.clamp(2, 15);
    danmuMergeWindowSeconds.value = clamped;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuMergeWindowSeconds, clamped);
  }

  var liveNotificationEnable = false.obs;
  void setLiveNotificationEnable(bool e) {
    liveNotificationEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kLiveNotificationEnable, e);
  }

  var webDavAutoSync = false.obs;
  void setWebDavAutoSync(bool e) {
    webDavAutoSync.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebDAVAutoSync, e);
  }

  void setScaleMode(int value) {
    scaleMode.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kPlayerScaleMode,
      value,
    );
  }

  RxList<String> siteSort = RxList<String>();
  void setSiteSort(List<String> e) {
    siteSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kSiteSort,
      siteSort.join(","),
    );
  }

  RxList<String> homeSort = RxList<String>();
  void setHomeSort(List<String> e) {
    homeSort.value = e;
    LocalStorageService.instance.setValue(
      LocalStorageService.kHomeSort,
      homeSort.join(","),
    );
  }

  Rx<double> playerVolume = 100.0.obs;
  void setPlayerVolume(double value) {
    playerVolume.value = value;
    LocalStorageService.instance.setValue(
      LocalStorageService.kPlayerVolume,
      value,
    );
  }

  var pipHideDanmu = true.obs;
  void setPIPHideDanmu(bool e) {
    pipHideDanmu.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kPIPHideDanmu, e);
  }

  var styleColor = 0xff3498db.obs;
  void setStyleColor(int e) {
    styleColor.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kStyleColor, e);
  }

  var isDynamic = false.obs;
  void setIsDynamic(bool e) {
    isDynamic.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kIsDynamic, e);
  }

  var danmuTopMargin = 0.0.obs;
  void setDanmuTopMargin(double e) {
    danmuTopMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuTopMargin, e);
  }

  var danmuBottomMargin = 0.0.obs;
  void setDanmuBottomMargin(double e) {
    danmuBottomMargin.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuBottomMargin, e);
  }

  var bilibiliLoginTip = true.obs;
  void setBiliBiliLoginTip(bool e) {
    bilibiliLoginTip.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliLoginTip, e);
  }

  var logEnable = false.obs;
  void setLogEnable(bool e) {
    logEnable.value = e;
    LocalStorageService.instance.setValue(LocalStorageService.kLogEnable, e);
  }

  final customPlayerOutput = false.obs;

  final videoOutputDriver = 'auto'.obs;

  final audioOutputDriver = 'auto'.obs;

  final videoHardwareDecoder = 'auto'.obs;

  var autoUpdateFollowEnable = false.obs;
  void setAutoUpdateFollowEnable(bool e) {
    autoUpdateFollowEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAutoUpdateFollowEnable, e);
  }

  var autoUpdateFollowDuration = 10.obs;
  void setAutoUpdateFollowDuration(int e) {
    autoUpdateFollowDuration.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowDuration, e);
  }

  var updateFollowThreadCount = 4.obs;
  void setUpdateFollowThreadCount(int e) {
    updateFollowThreadCount.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kUpdateFollowThreadCount, e);
  }

  final playerForceHttps = false.obs;
}
