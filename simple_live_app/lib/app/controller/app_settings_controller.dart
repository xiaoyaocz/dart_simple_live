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
  static const String kGlobalUserShieldSiteId = "__all__";

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
    danmuLineCount.value = LocalStorageService.instance
        .getValue(LocalStorageService.kDanmuLineCount, 8);
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
    contributionRankEnable.value = LocalStorageService.instance
        .getValue(LocalStorageService.kContributionRankEnable, true);

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

    _loadDanmuDelaySettings();
    _loadUserRemarks();
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

  var danmuLineCount = 8.obs;
  void setDanmuLineCount(int e) {
    final value = e.clamp(1, 40);
    danmuLineCount.value = value;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDanmuLineCount, value);
  }

  var danmuDelayMs = 0.obs;
  RxMap<String, int> danmuDelayBySite = <String, int>{}.obs;

  void _loadDanmuDelaySettings() {
    final rawValue = LocalStorageService.instance.getValue(
      LocalStorageService.kDanmuDelay,
      "",
    );
    final delayMap = <String, int>{};
    if (rawValue.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString().trim();
            final value = int.tryParse(entry.value.toString()) ?? 0;
            if (key.isEmpty) {
              continue;
            }
            delayMap[key] = value.clamp(0, 5000);
          }
        }
      } catch (e) {
        Log.d("加载弹幕延迟设置失败: $e");
      }
    }
    danmuDelayMs.value = (delayMap.remove("global") ?? 0).clamp(0, 5000);
    danmuDelayBySite.assignAll(delayMap);
  }

  Future<void> _saveDanmuDelaySettings() {
    final payload = <String, int>{"global": danmuDelayMs.value};
    for (final entry in danmuDelayBySite.entries) {
      payload[entry.key] = entry.value.clamp(0, 5000);
    }
    return LocalStorageService.instance.setValue(
      LocalStorageService.kDanmuDelay,
      jsonEncode(payload),
    );
  }

  int getDanmuDelayMs([String? siteId]) {
    final value = siteId == null || siteId.trim().isEmpty
        ? danmuDelayMs.value
        : danmuDelayBySite[siteId.trim()] ?? danmuDelayMs.value;
    return value.clamp(0, 5000);
  }

  Future<void> setDanmuDelayMs(int value, {String? siteId}) async {
    final safeValue = value.clamp(0, 5000);
    if (siteId == null || siteId.trim().isEmpty) {
      danmuDelayMs.value = safeValue;
    } else {
      danmuDelayBySite[siteId.trim()] = safeValue;
      danmuDelayBySite.refresh();
    }
    await _saveDanmuDelaySettings();
  }

  double estimateDanmuTextHeight({
    double? fontSize,
    double? strokeWidth,
    FontWeight? fontWeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: '测试vjgpqa',
        style: TextStyle(
          fontSize: fontSize ?? danmuSize.value,
          fontWeight: fontWeight ?? _danmuFontWeightValue,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth ?? danmuStrokeWidth.value
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    return painter.height;
  }

  int estimateDanmuMaxVisibleLineCount({
    required double viewportHeight,
    double? area,
    double? fontSize,
  }) {
    if (viewportHeight <= 0) {
      return 1;
    }
    final itemHeight = estimateDanmuTextHeight(fontSize: fontSize);
    final safeArea = (area ?? danmuArea.value).clamp(0.1, 1.0);
    final maxRows = ((viewportHeight / itemHeight) * safeArea).floor();
    return maxRows.clamp(1, 40);
  }

  double resolveDanmuEffectiveArea({
    required double viewportHeight,
    double? area,
    double? fontSize,
    int? lineCount,
  }) {
    final safeArea = (area ?? danmuArea.value).clamp(0.1, 1.0);
    if (viewportHeight <= 0) {
      return safeArea;
    }
    final maxLines = estimateDanmuMaxVisibleLineCount(
      viewportHeight: viewportHeight,
      area: safeArea,
      fontSize: fontSize,
    );
    final desiredLines = (lineCount ?? danmuLineCount.value).clamp(1, maxLines);
    final itemHeight = estimateDanmuTextHeight(fontSize: fontSize);
    final targetArea = (desiredLines * itemHeight) / viewportHeight;
    return targetArea.clamp(0.02, safeArea);
  }

  double resolveDanmuLineHeight({
    required double viewportHeight,
    double? area,
    double? fontSize,
    int? lineCount,
  }) {
    if (viewportHeight <= 0) {
      return 1.2;
    }
    final safeArea = (area ?? danmuArea.value).clamp(0.1, 1.0);
    final desiredLines = (lineCount ?? danmuLineCount.value).clamp(1, 40);
    final itemHeight = estimateDanmuTextHeight(fontSize: fontSize);
    final lineHeight =
        ((viewportHeight * safeArea) / itemHeight) / desiredLines;
    return lineHeight.clamp(1.0, 3.0);
  }

  int resolveDanmuActualLineCount({
    required double viewportHeight,
    double? area,
    double? fontSize,
    int? lineCount,
  }) {
    if (viewportHeight <= 0) {
      return 1;
    }
    final itemHeight = estimateDanmuTextHeight(fontSize: fontSize);
    final effectiveArea = resolveDanmuEffectiveArea(
      viewportHeight: viewportHeight,
      area: area,
      fontSize: fontSize,
      lineCount: lineCount,
    );
    final rows = ((viewportHeight / itemHeight) * effectiveArea).floor();
    return rows.clamp(1, 40);
  }

  int estimateDanmuSparseWarningThreshold({
    required double viewportHeight,
    double? area,
    double? fontSize,
  }) {
    final maxLines = estimateDanmuMaxVisibleLineCount(
      viewportHeight: viewportHeight,
      area: area,
      fontSize: fontSize,
    );
    return (maxLines * 0.35).round().clamp(3, 12);
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

  FontWeight get _danmuFontWeightValue =>
      FontWeight.values[danmuFontWeight.value.clamp(1, 9) - 1];

  var contributionRankEnable = true.obs;
  void setContributionRankEnable(bool e) {
    contributionRankEnable.value = e;
    LocalStorageService.instance
        .setValue(LocalStorageService.kContributionRankEnable, e);
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
  RxMap<String, List<String>> userShieldGroups = <String, List<String>>{}.obs;
  RxList<DanmuShieldPreset> shieldPresetList = <DanmuShieldPreset>[].obs;
  RxMap<String, String> userRemarks = <String, String>{}.obs;

  Iterable<String> get allShieldValues =>
      LocalStorageService.instance.shieldBox.values.cast<String>();

  String _normalizeShieldSiteId(String? siteId) {
    final value = siteId?.trim() ?? "";
    if (value.isEmpty) {
      return kGlobalUserShieldSiteId;
    }
    if (value == kGlobalUserShieldSiteId || Sites.allSites.containsKey(value)) {
      return value;
    }
    return kGlobalUserShieldSiteId;
  }

  String resolveShieldSiteLabel(String? siteId) {
    final value = _normalizeShieldSiteId(siteId);
    if (value == kGlobalUserShieldSiteId) {
      return "全平台";
    }
    return Sites.allSites[value]?.name ?? value;
  }

  String _buildShieldStorageValue(
    String value, {
    required bool isUser,
    String? siteId,
  }) {
    if (!isUser) {
      return "$_keywordShieldPrefix$value";
    }
    final siteKey = _normalizeShieldSiteId(siteId);
    if (siteKey == kGlobalUserShieldSiteId) {
      return "$_userShieldPrefix$value";
    }
    return "$_userShieldPrefix$siteKey:$value";
  }

  MapEntry<String, String>? _parseUserShieldStorageValue(String rawValue) {
    final value = rawValue.substring(_userShieldPrefix.length).trim();
    if (value.isEmpty) {
      return null;
    }

    final separatorIndex = value.indexOf(":");
    if (separatorIndex <= 0) {
      return MapEntry(kGlobalUserShieldSiteId, value);
    }

    final siteId = value.substring(0, separatorIndex).trim();
    final userName = value.substring(separatorIndex + 1).trim();
    if (userName.isEmpty) {
      return null;
    }
    if (siteId == kGlobalUserShieldSiteId || Sites.allSites.containsKey(siteId)) {
      return MapEntry(_normalizeShieldSiteId(siteId), userName);
    }
    return MapEntry(kGlobalUserShieldSiteId, value);
  }

  void _setUserShieldGroupValues(String siteId, Iterable<String> values) {
    final safeSiteId = _normalizeShieldSiteId(siteId);
    final normalized = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (normalized.isEmpty) {
      userShieldGroups.remove(safeSiteId);
    } else {
      userShieldGroups[safeSiteId] = normalized;
    }
  }

  void _refreshUserShieldList() {
    final allValues = <String>{};
    for (final values in userShieldGroups.values) {
      allValues.addAll(values);
    }
    final normalized = allValues.toList()..sort();
    userShieldList
      ..clear()
      ..addAll(normalized);
    userShieldGroups.refresh();
  }

  List<String> getUserShieldValues({
    String? siteId,
    bool includeGlobal = false,
  }) {
    final safeSiteId = _normalizeShieldSiteId(siteId);
    final values = <String>{};
    if (safeSiteId == kGlobalUserShieldSiteId) {
      values.addAll(
        userShieldGroups[kGlobalUserShieldSiteId] ?? const <String>[],
      );
    } else {
      values.addAll(userShieldGroups[safeSiteId] ?? const <String>[]);
      if (includeGlobal) {
        values.addAll(
          userShieldGroups[kGlobalUserShieldSiteId] ?? const <String>[],
        );
      }
    }
    final result = values.toList()..sort();
    return result;
  }

  Map<String, List<String>> getUserShieldGroupSnapshot() {
    final snapshot = <String, List<String>>{};
    for (final entry in userShieldGroups.entries) {
      final values = entry.value
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (values.isEmpty) {
        continue;
      }
      snapshot[entry.key] = values;
    }
    return snapshot;
  }

  void _loadShieldList() {
    final keywords = <String>{};
    final userGroupValues = <String, Set<String>>{};
    for (final rawValue in allShieldValues) {
      final value = rawValue.trim();
      if (value.isEmpty) {
        continue;
      }
      if (value.startsWith(_userShieldPrefix)) {
        final parsed = _parseUserShieldStorageValue(value);
        if (parsed != null) {
          userGroupValues
              .putIfAbsent(parsed.key, () => <String>{})
              .add(parsed.value);
        }
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
    userShieldGroups.clear();
    for (final entry in userGroupValues.entries) {
      _setUserShieldGroupValues(entry.key, entry.value);
    }
    _refreshUserShieldList();
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
            .toList()
          ..sort();
        final globalUsers = (decoded['users'] as List? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final userGroups = <String, List<String>>{};
        final rawUserGroups = decoded['userGroups'];
        if (rawUserGroups is Map) {
          for (final rawEntry in rawUserGroups.entries) {
            final siteId = _normalizeShieldSiteId(rawEntry.key.toString());
            final values = (rawEntry.value as List? ?? const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            if (values.isEmpty) {
              continue;
            }
            userGroups[siteId] = values;
          }
        }
        if (globalUsers.isNotEmpty) {
          userGroups[kGlobalUserShieldSiteId] = {
            ...globalUsers,
            ...?userGroups[kGlobalUserShieldSiteId],
          }.toList()
            ..sort();
        }
        presets.add(
          DanmuShieldPreset(
            name: name,
            keywords: keywordValues,
            users: globalUsers,
            userGroups: userGroups,
          ),
        );
      } catch (e) {
        Log.d("加载历史屏蔽预设失败: $e");
      }
    }
    presets.sort((a, b) => a.name.compareTo(b.name));
    shieldPresetList.assignAll(presets);
  }

  void importShieldValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return;
    }
    if (value.startsWith(_userShieldPrefix)) {
      final parsed = _parseUserShieldStorageValue(value);
      if (parsed != null) {
        addUserShieldList(parsed.value, siteId: parsed.key);
      }
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

  void addUserShieldList(String e, {String? siteId}) {
    final value = e.trim();
    if (value.isEmpty) {
      return;
    }
    final safeSiteId = _normalizeShieldSiteId(siteId);
    final storageValue = _buildShieldStorageValue(
      value,
      isUser: true,
      siteId: safeSiteId,
    );
    final current = {...getUserShieldValues(siteId: safeSiteId), value}.toList()
      ..sort();
    _setUserShieldGroupValues(safeSiteId, current);
    _refreshUserShieldList();
    LocalStorageService.instance.shieldBox.put(storageValue, storageValue);
  }

  void removeUserShieldList(String e, {String? siteId}) {
    final value = e.trim();
    final safeSiteId = _normalizeShieldSiteId(siteId);
    final storageValue = _buildShieldStorageValue(
      value,
      isUser: true,
      siteId: safeSiteId,
    );
    final current = {...getUserShieldValues(siteId: safeSiteId)}..remove(value);
    _setUserShieldGroupValues(safeSiteId, current);
    _refreshUserShieldList();
    LocalStorageService.instance.shieldBox.delete(storageValue);
    if (safeSiteId == kGlobalUserShieldSiteId) {
      LocalStorageService.instance.shieldBox
          .delete("$_userShieldPrefix$kGlobalUserShieldSiteId:$value");
    }
  }

  bool isUserShielded(String userName, {String? siteId}) {
    final value = userName.trim();
    if (value.isEmpty) {
      return false;
    }
    final safeSiteId = _normalizeShieldSiteId(siteId);
    if ((userShieldGroups[kGlobalUserShieldSiteId] ?? const <String>[])
        .contains(value)) {
      return true;
    }
    if (safeSiteId == kGlobalUserShieldSiteId) {
      return false;
    }
    return (userShieldGroups[safeSiteId] ?? const <String>[]).contains(value);
  }

  bool shouldShieldUser(String userName, {String? siteId}) {
    if (!danmuShieldEnable.value || !danmuUserShieldEnable.value) {
      return false;
    }
    return isUserShielded(userName, siteId: siteId);
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
      keywords: shieldList.toList()..sort(),
      users: getUserShieldValues(siteId: kGlobalUserShieldSiteId),
      userGroups: getUserShieldGroupSnapshot(),
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
    final userGroups = preset.userGroups.isNotEmpty
        ? preset.userGroups
        : {
            if (preset.users.isNotEmpty) kGlobalUserShieldSiteId: preset.users,
          };
    for (final entry in userGroups.entries) {
      for (final user in entry.value) {
        addUserShieldList(user, siteId: entry.key);
      }
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
    userShieldGroups.clear();
    await LocalStorageService.instance.shieldBox.clear();
  }

  Future<void> clearKeywordShieldList() async {
    final keysToDelete = <dynamic>[];
    for (final entry
        in LocalStorageService.instance.shieldBox.toMap().entries) {
      final value = entry.value.toString().trim();
      if (value.isEmpty) {
        keysToDelete.add(entry.key);
        continue;
      }
      if (!value.startsWith(_userShieldPrefix)) {
        keysToDelete.add(entry.key);
      }
    }
    shieldList.clear();
    if (keysToDelete.isNotEmpty) {
      await LocalStorageService.instance.shieldBox.deleteAll(keysToDelete);
    }
  }

  Future<void> clearUserShieldList({String? siteId}) async {
    final safeSiteId = siteId == null ? null : _normalizeShieldSiteId(siteId);
    final keysToDelete = <dynamic>[];
    for (final entry
        in LocalStorageService.instance.shieldBox.toMap().entries) {
      final value = entry.value.toString().trim();
      if (!value.startsWith(_userShieldPrefix)) {
        continue;
      }
      if (safeSiteId == null) {
        keysToDelete.add(entry.key);
        continue;
      }
      final parsed = _parseUserShieldStorageValue(value);
      if (parsed != null && parsed.key == safeSiteId) {
        keysToDelete.add(entry.key);
      }
    }
    if (safeSiteId == null) {
      userShieldList.clear();
      userShieldGroups.clear();
    } else {
      userShieldGroups.remove(safeSiteId);
      _refreshUserShieldList();
    }
    if (keysToDelete.isNotEmpty) {
      await LocalStorageService.instance.shieldBox.deleteAll(keysToDelete);
    }
  }

  void _loadUserRemarks() {
    final rawValue = LocalStorageService.instance.getValue(
      LocalStorageService.kUserRemarks,
      "",
    );
    final remarks = <String, String>{};
    if (rawValue.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString().trim();
            final value = entry.value.toString().trim();
            if (key.isEmpty || value.isEmpty) {
              continue;
            }
            remarks[key] = value;
          }
        }
      } catch (e) {
        Log.d("加载用户备注失败: $e");
      }
    }
    userRemarks.assignAll(remarks);
  }

  Future<void> _saveUserRemarks() {
    return LocalStorageService.instance.setValue(
      LocalStorageService.kUserRemarks,
      jsonEncode(userRemarks),
    );
  }

  String _buildUserRemarkKey(String siteId, String userName) {
    return "${_normalizeShieldSiteId(siteId)}::${userName.trim()}";
  }

  String? getUserRemark(
    String userName, {
    required String siteId,
  }) {
    final key = _buildUserRemarkKey(siteId, userName);
    final value = userRemarks[key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> setUserRemark({
    required String siteId,
    required String userName,
    String? remark,
  }) async {
    final normalizedUserName = userName.trim();
    if (normalizedUserName.isEmpty) {
      return;
    }
    final key = _buildUserRemarkKey(siteId, normalizedUserName);
    final value = remark?.trim() ?? "";
    if (value.isEmpty) {
      userRemarks.remove(key);
    } else {
      userRemarks[key] = value;
    }
    userRemarks.refresh();
    await _saveUserRemarks();
  }

  String generateShieldPresetJson() {
    final payload = {
      "version": 2,
      "exportedAt": DateTime.now().toIso8601String(),
      "current": {
        "keywords": shieldList.toList()..sort(),
        "users": getUserShieldValues(siteId: kGlobalUserShieldSiteId),
        "userGroups": getUserShieldGroupSnapshot(),
      },
      "presets": shieldPresetList
          .map(
            (preset) => {
              "name": preset.name,
              "keywords": preset.keywords,
              "users": preset.users,
              "userGroups": preset.userGroups,
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent("  ").convert(payload);
  }

  Future<void> importShieldPresetJson(
    String content, {
    bool applyCurrent = true,
  }) async {
    final decoded = jsonDecode(content);
    final presets = <DanmuShieldPreset>[];
    DanmuShieldPreset? currentPreset;

    DanmuShieldPreset? parsePreset(dynamic rawPreset, {String? fallbackName}) {
      if (rawPreset is! Map) {
        return null;
      }
      final name = (rawPreset["name"]?.toString().trim() ?? fallbackName ?? "")
          .trim();
      final keywords = (rawPreset["keywords"] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final users = (rawPreset["users"] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final groups = <String, List<String>>{};
      final rawGroups = rawPreset["userGroups"];
      if (rawGroups is Map) {
        for (final entry in rawGroups.entries) {
          final groupValues = (entry.value as List? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (groupValues.isEmpty) {
            continue;
          }
          groups[_normalizeShieldSiteId(entry.key.toString())] = groupValues;
        }
      }
      if (users.isNotEmpty) {
        groups[kGlobalUserShieldSiteId] = {
          ...users,
          ...?groups[kGlobalUserShieldSiteId],
        }.toList()
          ..sort();
      }
      if (name.isEmpty && fallbackName == null) {
        return DanmuShieldPreset(
          name: "__current__",
          keywords: keywords,
          users: users,
          userGroups: groups,
        );
      }
      if (name.isEmpty) {
        return null;
      }
      return DanmuShieldPreset(
        name: name,
        keywords: keywords,
        users: users,
        userGroups: groups,
      );
    }

    if (decoded is Map) {
      final parsedCurrent = parsePreset(decoded["current"]);
      if (parsedCurrent != null) {
        currentPreset = parsedCurrent;
      }
      final rawPresets = decoded["presets"];
      if (rawPresets is List) {
        for (final rawPreset in rawPresets) {
          final preset = parsePreset(rawPreset);
          if (preset == null || preset.name == "__current__") {
            continue;
          }
          presets.add(preset);
        }
      }
    } else if (decoded is List) {
      for (final rawPreset in decoded) {
        final preset = parsePreset(rawPreset);
        if (preset == null || preset.name == "__current__") {
          continue;
        }
        presets.add(preset);
      }
    } else {
      throw const FormatException("Invalid shield preset payload");
    }

    for (final preset in presets) {
      await LocalStorageService.instance.shieldPresetBox.put(
        preset.name,
        jsonEncode(preset.toJson()),
      );
    }
    _loadShieldPresetList();

    if (!applyCurrent || currentPreset == null) {
      return;
    }
    await clearShieldList();
    for (final keyword in currentPreset.keywords) {
      addShieldList(keyword);
    }
    final groups = currentPreset.userGroups.isNotEmpty
        ? currentPreset.userGroups
        : {
            if (currentPreset.users.isNotEmpty)
              kGlobalUserShieldSiteId: currentPreset.users,
          };
    for (final entry in groups.entries) {
      for (final user in entry.value) {
        addUserShieldList(user, siteId: entry.key);
      }
    }
  }

  Map<String, String>? getLastLiveRoom() {
    final rawValue = LocalStorageService.instance.getValue(
      LocalStorageService.kLastLiveRoom,
      "",
    );
    if (rawValue.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return null;
      }
      final siteId = decoded["siteId"]?.toString().trim() ?? "";
      final roomId = decoded["roomId"]?.toString().trim() ?? "";
      if (siteId.isEmpty ||
          roomId.isEmpty ||
          !Sites.allSites.containsKey(siteId)) {
        return null;
      }
      return {
        "siteId": siteId,
        "roomId": roomId,
      };
    } catch (e) {
      Log.d("读取上次直播间失败: $e");
      return null;
    }
  }

  Future<void> saveLastLiveRoom({
    required String siteId,
    required String roomId,
    bool resumePending = false,
  }) async {
    final safeSiteId = siteId.trim();
    final safeRoomId = roomId.trim();
    if (safeSiteId.isEmpty ||
        safeRoomId.isEmpty ||
        !Sites.allSites.containsKey(safeSiteId)) {
      return clearLastLiveRoom();
    }
    await LocalStorageService.instance.setValue(
      LocalStorageService.kLastLiveRoom,
      jsonEncode({
        "siteId": safeSiteId,
        "roomId": safeRoomId,
        "savedAt": DateTime.now().toIso8601String(),
      }),
    );
    await LocalStorageService.instance.setValue(
      LocalStorageService.kLastLiveRoomResumePending,
      resumePending,
    );
  }

  Future<void> clearLastLiveRoom() async {
    await LocalStorageService.instance
        .removeValue(LocalStorageService.kLastLiveRoom);
    await LocalStorageService.instance.setValue(
      LocalStorageService.kLastLiveRoomResumePending,
      false,
    );
  }

  Future<void> setLastLiveRoomResumePending(bool value) {
    return LocalStorageService.instance.setValue(
      LocalStorageService.kLastLiveRoomResumePending,
      value,
    );
  }

  Future<Map<String, String>?> consumePendingLastLiveRoom() async {
    final pending = LocalStorageService.instance.getValue(
      LocalStorageService.kLastLiveRoomResumePending,
      false,
    );
    if (!pending) {
      return null;
    }
    await setLastLiveRoomResumePending(false);
    return getLastLiveRoom();
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
