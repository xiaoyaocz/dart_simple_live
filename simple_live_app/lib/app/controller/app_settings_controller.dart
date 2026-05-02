import 'dart:convert';
import 'dart:io';

import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/danmu_shield_preset.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSettingsController extends GetxController {
  static AppSettingsController get instance =>
      Get.find<AppSettingsController>();

  static const String _keywordShieldPrefix = "keyword:";
  static const String _userShieldPrefix = "user:";

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
        .getValue(LocalStorageService.kDanmuEnable, true);
    danmuShieldEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuShieldEnable, true);
    danmuKeywordShieldEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuKeywordShieldEnable, true);
    danmuUserShieldEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuUserShieldEnable, true);
    danmuStrokeWidth.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuStrokeWidth, 2.0);
    danmuTopMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuTopMargin, 0.0);
    danmuBottomMargin.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuBottomMargin, 0.0);
    danmuFontWeight.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuFontWeight, 4);

    hardwareDecode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kHardwareDecode, true);
    chatTextSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextSize, 14.0);

    chatTextGap.value = LocalStorageService.instance
        .getValue(LocalStorageService.kChatTextGap, 4.0);

    chatBubbleStyle.value = LocalStorageService.instance.getValue(
      LocalStorageService.kChatBubbleStyle,
      false,
    );

    qualityLevel.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevel, 1);
    qualityLevelCellular.value = LocalStorageService.instance
        .getValue(LocalStorageService.kQualityLevelCellular, 1);

    autoExitEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitEnable, false);

    autoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoExitDuration, 60);

    roomAutoExitDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kRoomAutoExitDuration, 60);

    playerCompatMode.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerCompatMode, false);

    playerAutoPause.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerAutoPause, false);

    playerForceHttps.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerForceHttps, false);

    autoFullScreen.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoFullScreen, false);
    playershowSuperChat.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerShowSuperChat, true);

    _loadShieldList();
    _loadShieldPresetList();

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

    playerBufferSize.value = LocalStorageService.instance
        .getValue(LocalStorageService.kPlayerBufferSize, 32);

    logEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kLogEnable, false);
    if (logEnable.value) {
      Log.initWriter();
    }

    customPlayerOutput.value = LocalStorageService.instance
        .getValue(LocalStorageService.kCustomPlayerOutput, false);

    videoOutputDriver.value = LocalStorageService.instance.getValue(
      LocalStorageService.kVideoOutputDriver,
      Platform.isAndroid ? "gpu" : "libmpv",
    );

    audioOutputDriver.value = LocalStorageService.instance.getValue(
      LocalStorageService.kAudioOutputDriver,
      Platform.isAndroid
          ? "audiotrack"
          : Platform.isLinux
              ? "pulse"
              : Platform.isWindows
                  ? "wasapi"
                  : Platform.isIOS
                      ? "audiounit"
                      : Platform.isMacOS
                          ? "coreaudio"
                          : "sdl",
    );

    videoHardwareDecoder.value = LocalStorageService.instance.getValue(
      LocalStorageService.kVideoHardwareDecoder,
      Platform.isAndroid ? "auto-safe" : "auto",
    );

    autoUpdateFollowEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kAutoUpdateFollowEnable, true);

    autoUpdateFollowDuration.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowDuration, 10);

    updateFollowThreadCount.value = LocalStorageService.instance
        .getValue(LocalStorageService.kUpdateFollowThreadCount, 0); // 默认 0 = 自动

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
  }

  var hardwareDecode = true.obs;
  void setHardwareDecode(bool e) {
    hardwareDecode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kHardwareDecode, e);
  }

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

  var danmuEnable = true.obs;
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

  var qualityLevel = 1.obs;
  void setQualityLevel(int level) {
    qualityLevel.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevel, level);
  }

  var qualityLevelCellular = 1.obs;
  void setQualityLevelCellular(int level) {
    qualityLevelCellular.value = level;
    LocalStorageService.instance
        .setValue(LocalStorageService.kQualityLevelCellular, level);
  }

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

  var playerCompatMode = false.obs;
  void setPlayerCompatMode(bool e) {
    playerCompatMode.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerCompatMode, e);
  }

  var playerBufferSize = 32.obs;
  void setPlayerBufferSize(int e) {
    playerBufferSize.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerBufferSize, e);
  }

  var playerAutoPause = false.obs;
  void setPlayerAutoPause(bool e) {
    playerAutoPause.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerAutoPause, e);
  }

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

  var danmuShieldEnable = true.obs;
  void setDanmuShieldEnable(bool e) {
    danmuShieldEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuShieldEnable, e);
  }

  var danmuKeywordShieldEnable = true.obs;
  void setDanmuKeywordShieldEnable(bool e) {
    danmuKeywordShieldEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuKeywordShieldEnable, e);
  }

  var danmuUserShieldEnable = true.obs;
  void setDanmuUserShieldEnable(bool e) {
    danmuUserShieldEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuUserShieldEnable, e);
  }

  RxSet<String> shieldList = <String>{}.obs;
  RxSet<String> userShieldList = <String>{}.obs;
  RxList<DanmuShieldPreset> shieldPresetList = <DanmuShieldPreset>[].obs;

  Iterable<String> get allShieldValues =>
      LocalStorageService.instance.shieldBox.values.cast<String>();

  void _loadShieldList() {
    final keywords = <String>{};
    final users = <String>{};
    for (final rawValue in allShieldValues) {
      final value = rawValue.trim();
      if (value.isEmpty) {
        continue;
      }
      if (value.startsWith(_userShieldPrefix)) {
        users.add(value.substring(_userShieldPrefix.length));
        continue;
      }
      if (value.startsWith(_keywordShieldPrefix)) {
        keywords.add(value.substring(_keywordShieldPrefix.length));
        continue;
      }
      keywords.add(value);
    }
    shieldList
      ..clear()
      ..addAll(keywords);
    userShieldList
      ..clear()
      ..addAll(users);
  }

  void _loadShieldPresetList() {
    final presets = <DanmuShieldPreset>[];
    for (final entry
        in LocalStorageService.instance.shieldPresetBox.toMap().entries) {
      final name = entry.key.toString().trim();
      final rawValue = entry.value.toString().trim();
      if (name.isEmpty || rawValue.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is! Map) {
          continue;
        }
        final keywordValues = (decoded['keywords'] as List? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        final userValues = (decoded['users'] as List? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        presets.add(
          DanmuShieldPreset(
            name: name,
            keywords: keywordValues,
            users: userValues,
          ),
        );
      } catch (e) {
        Log.d("加载历史屏蔽预设失败: $e");
      }
    }
    presets.sort((a, b) => a.name.compareTo(b.name));
    shieldPresetList.assignAll(presets);
  }

  String _buildShieldStorageValue(
    String value, {
    required bool isUser,
  }) {
    return "${isUser ? _userShieldPrefix : _keywordShieldPrefix}$value";
  }

  void importShieldValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return;
    }
    if (value.startsWith(_userShieldPrefix)) {
      addUserShieldList(value.substring(_userShieldPrefix.length));
      return;
    }
    if (value.startsWith(_keywordShieldPrefix)) {
      addShieldList(value.substring(_keywordShieldPrefix.length));
      return;
    }
    addShieldList(value);
  }

  void addShieldList(String e) {
    final value = e.trim();
    if (value.isEmpty) {
      return;
    }
    final storageValue = _buildShieldStorageValue(value, isUser: false);
    shieldList.add(value);
    LocalStorageService.instance.shieldBox.delete(value);
    LocalStorageService.instance.shieldBox.put(storageValue, storageValue);
  }

  void removeShieldList(String e) {
    final value = e.trim();
    final storageValue = _buildShieldStorageValue(value, isUser: false);
    shieldList.remove(value);
    LocalStorageService.instance.shieldBox.delete(value);
    LocalStorageService.instance.shieldBox.delete(storageValue);
  }

  void addUserShieldList(String e) {
    final value = e.trim();
    if (value.isEmpty) {
      return;
    }
    final storageValue = _buildShieldStorageValue(value, isUser: true);
    userShieldList.add(value);
    LocalStorageService.instance.shieldBox.put(storageValue, storageValue);
  }

  void removeUserShieldList(String e) {
    final value = e.trim();
    final storageValue = _buildShieldStorageValue(value, isUser: true);
    userShieldList.remove(value);
    LocalStorageService.instance.shieldBox.delete(storageValue);
  }

  bool isUserShielded(String userName) {
    final value = userName.trim();
    if (value.isEmpty) {
      return false;
    }
    return userShieldList.contains(value);
  }

  bool shouldShieldUser(String userName) {
    if (!danmuShieldEnable.value || !danmuUserShieldEnable.value) {
      return false;
    }
    return isUserShielded(userName);
  }

  DanmuShieldPreset? _findShieldPreset(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return null;
    }
    for (final preset in shieldPresetList) {
      if (preset.name == value) {
        return preset;
      }
    }
    return null;
  }

  Future<bool> saveShieldPreset(String name) async {
    final value = name.trim();
    if (value.isEmpty) {
      return false;
    }
    final preset = DanmuShieldPreset(
      name: value,
      keywords: shieldList.toList(),
      users: userShieldList.toList(),
    );
    await LocalStorageService.instance.shieldPresetBox.put(
      value,
      jsonEncode(preset.toJson()),
    );
    _loadShieldPresetList();
    return true;
  }

  Future<bool> applyShieldPreset(String name) async {
    final preset = _findShieldPreset(name);
    if (preset == null) {
      return false;
    }
    await clearShieldList();
    for (final keyword in preset.keywords) {
      addShieldList(keyword);
    }
    for (final user in preset.users) {
      addUserShieldList(user);
    }
    setDanmuShieldEnable(true);
    setDanmuKeywordShieldEnable(true);
    setDanmuUserShieldEnable(true);
    return true;
  }

  Future<bool> deleteShieldPreset(String name) async {
    final value = name.trim();
    if (value.isEmpty) {
      return false;
    }
    await LocalStorageService.instance.shieldPresetBox.delete(value);
    _loadShieldPresetList();
    return true;
  }

  Future clearShieldList() async {
    shieldList.clear();
    userShieldList.clear();
    await LocalStorageService.instance.shieldBox.clear();
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

  var customPlayerOutput = false.obs;
  void setCustomPlayerOutput(bool e) {
    customPlayerOutput.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kCustomPlayerOutput, e);
  }

  var videoOutputDriver = "".obs;
  void setVideoOutputDriver(String e) {
    videoOutputDriver.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kVideoOutputDriver, e);
  }

  var audioOutputDriver = "".obs;
  void setAudioOutputDriver(String e) {
    audioOutputDriver.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kAudioOutputDriver, e);
  }

  var videoHardwareDecoder = "".obs;
  void setVideoHardwareDecoder(String e) {
    videoHardwareDecoder.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kVideoHardwareDecoder, e);
  }

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

  var playerForceHttps = false.obs;
  void setPlayerForceHttps(bool e) {
    playerForceHttps.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kPlayerForceHttps, e);
  }
}
