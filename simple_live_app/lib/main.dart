import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/desktop_startup_args.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/other/debug_log_page.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/current_room_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/profile_backup_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:window_manager/window_manager.dart';

import 'package:path/path.dart' as p;
import 'package:dynamic_color/dynamic_color.dart';

void main(List<String> args) async {
  // 捕获 Flutter 框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Log.e(
      "Flutter Error: ${details.exception}",
      details.stack ?? StackTrace.current,
    );
  };

  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e("Async Error: $error", stack);
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  DesktopStartupArgs.initialize(args);
  await migrateData();
  await initWindow();
  MediaKit.ensureInitialized();
  await Hive.initFlutter(await resolveHivePath(args));
  //初始化服务
  await initServices();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  //设置状态栏为透明
  SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  );
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  runApp(const MyApp());
  unawaited(setupDesktopWindowLifecycle());
}

Future<String?> resolveHivePath(List<String> args) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return null;
  }
  final appSupportDir = await getApplicationSupportDirectory();
  if (!isSecondaryDesktopInstance(args)) {
    return appSupportDir.path;
  }
  final instanceDir = await prepareSecondaryHiveDirectory(appSupportDir);
  return instanceDir.path;
}

bool isSecondaryDesktopInstance(List<String> args) {
  return DesktopStartupArgs.isSecondaryDesktopInstance;
}

Future<Directory> prepareSecondaryHiveDirectory(Directory sourceDir) async {
  final instancesRoot = Directory(p.join(sourceDir.path, "instances"));
  await instancesRoot.create(recursive: true);
  final instanceDir = Directory(
    p.join(
      instancesRoot.path,
      "${DateTime.now().millisecondsSinceEpoch}_$pid",
    ),
  );
  await instanceDir.create(recursive: true);
  await copyHiveSnapshot(sourceDir, instanceDir);
  await cleanupOldSecondaryHiveDirectories(instancesRoot, instanceDir);
  return instanceDir;
}

Future<void> copyHiveSnapshot(Directory sourceDir, Directory targetDir) async {
  if (!await sourceDir.exists()) {
    return;
  }
  await for (final entity in sourceDir.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final fileName = p.basename(entity.path);
    final lowerFileName = fileName.toLowerCase();
    if (!lowerFileName.endsWith(".hive") && !lowerFileName.endsWith(".hivec")) {
      continue;
    }
    try {
      await entity.copy(p.join(targetDir.path, fileName));
    } catch (e) {
      Log.logPrint(e);
    }
  }
}

Future<void> cleanupOldSecondaryHiveDirectories(
  Directory instancesRoot,
  Directory currentDir,
) async {
  if (!await instancesRoot.exists()) {
    return;
  }
  final now = DateTime.now();
  await for (final entity in instancesRoot.list(followLinks: false)) {
    if (entity is! Directory || entity.path == currentDir.path) {
      continue;
    }
    try {
      final stat = await entity.stat();
      if (now.difference(stat.modified) > const Duration(days: 2)) {
        await entity.delete(recursive: true);
      }
    } catch (e) {
      Log.logPrint(e);
    }
  }
}

/// 将Hive数据迁移到Application Support
Future migrateData() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return;
  }
  var hiveFileList = [
    "followuser",
    //旧版本写错成hostiry了
    "hostiry",
    "followusertag",
    "localstorage",
    "danmushield",
    "danmushieldpreset",
  ];
  try {
    var newDir = await getApplicationSupportDirectory();
    var hiveFile = File(p.join(newDir.path, "followuser.hive"));
    if (await hiveFile.exists()) {
      return;
    }

    var oldDir = await getApplicationDocumentsDirectory();
    for (var element in hiveFileList) {
      var oldFile = File(p.join(oldDir.path, "$element.hive"));
      if (await oldFile.exists()) {
        var fileName = "$element.hive";
        if (element == "hostiry") {
          fileName = "history.hive";
        }
        await oldFile.copy(p.join(newDir.path, fileName));
        await oldFile.delete();
      }
      var lockFile = File(p.join(oldDir.path, "$element.lock"));
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    }
  } catch (e) {
    Log.logPrint(e);
  }
}

Future initWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  await windowManager.ensureInitialized();
  Log.i("桌面窗口初始化");
  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(200, 150),  // 减小最小尺寸，允许更小的窗口
    title: "Simple Live",
  );
  await windowManager.waitUntilReadyToShow(windowOptions);
}

final _desktopWindowLifecycle = _DesktopWindowLifecycle();

Future<void> setupDesktopWindowLifecycle() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  windowManager.addListener(_desktopWindowLifecycle);
  if (Platform.isWindows) {
    await windowManager.setPreventClose(true);
  }
  await WidgetsBinding.instance.endOfFrame;
  Log.i("准备显示桌面窗口");
  await _desktopWindowLifecycle.restoreWindowPlacement();
  await windowManager.show();
  await windowManager.focus();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await windowManager.show();
  await windowManager.focus();
  Log.i("桌面窗口已请求显示");
}

class _DesktopWindowLifecycle with WindowListener {
  bool _closing = false;
  bool _restoring = false;
  Timer? _saveTimer;

  Future<void> restoreWindowPlacement() async {
    _restoring = true;
    try {
      final startupBounds = DesktopStartupArgs.startupWindowBounds;
      if (startupBounds != null) {
        if (DesktopStartupArgs.startupFramelessTile) {
          await _applyFramelessTileChrome();
        }
        await windowManager.setBounds(startupBounds);
        return;
      }
      final settings = AppSettingsController.instance;
      if (settings.rememberWindowPlacement.value) {
        final bounds = await _validSavedBounds();
        if (bounds != null) {
          await windowManager.setBounds(bounds);
        } else {
          await windowManager.center();
        }
        if (settings.desktopWindowMaximized) {
          await windowManager.maximize();
        }
      } else {
        await windowManager.center();
      }
    } catch (e) {
      Log.logPrint(e);
      await windowManager.center();
    } finally {
      _restoring = false;
    }
  }

  Future<Rect?> _validSavedBounds() async {
    final bounds = AppSettingsController.instance.getDesktopWindowBounds();
    if (bounds == null) {
      return null;
    }
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final displayRect = Rect.fromLTWH(
        display.visiblePosition?.dx ?? 0,
        display.visiblePosition?.dy ?? 0,
        display.visibleSize?.width ?? display.size.width,
        display.visibleSize?.height ?? display.size.height,
      );
      if (!displayRect.contains(bounds.center)) {
        continue;
      }
      final width = bounds.width.clamp(280.0, displayRect.width).toDouble();
      final height = bounds.height.clamp(280.0, displayRect.height).toDouble();

      // Windows DWM may report edge-snapped frames a few pixels outside the
      // visible work area (commonly around -7/-8). Keep that relative overhang
      // so restoring an edge-snapped window does not leave an 8px gap.
      const maxDwmOverhang = 16.0;
      final minLeft =
          displayRect.left - (Platform.isWindows ? maxDwmOverhang : 0.0);
      final maxLeft = displayRect.right -
          width +
          (Platform.isWindows ? maxDwmOverhang : 0.0);
      final minTop =
          displayRect.top - (Platform.isWindows ? maxDwmOverhang : 0.0);
      final maxTop = displayRect.bottom -
          height +
          (Platform.isWindows ? maxDwmOverhang : 0.0);

      final left = bounds.left.clamp(minLeft, maxLeft).toDouble();
      final top = bounds.top.clamp(minTop, maxTop).toDouble();
      return Rect.fromLTWH(left, top, width, height);
    }
    return null;
  }

  Future<void> _applyFramelessTileChrome() async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    } catch (e) {
      Log.logPrint(e);
    }
  }

  void _scheduleSave() {
    if (_restoring || _closing) {
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(saveWindowPlacement());
    });
  }

  Future<void> saveWindowPlacement() async {
    if (!AppSettingsController.instance.rememberWindowPlacement.value) {
      return;
    }
    try {
      final liveRoom = Get.isRegistered<LiveRoomController>()
          ? Get.find<LiveRoomController>()
          : null;
      if (liveRoom?.smallWindowState.value == true ||
          await windowManager.isFullScreen()) {
        return;
      }
      final maximized = await windowManager.isMaximized();
      final previousBounds =
          AppSettingsController.instance.getDesktopWindowBounds();
      final bounds = maximized
          ? previousBounds ?? await windowManager.getBounds()
          : await windowManager.getBounds();
      await AppSettingsController.instance.setDesktopWindowPlacement(
        bounds: bounds,
        maximized: maximized,
      );
    } catch (e) {
      Log.logPrint(e);
    }
  }

  @override
  void onWindowMoved() {
    _scheduleSave();
  }

  @override
  void onWindowResized() {
    _scheduleSave();
  }

  @override
  void onWindowMaximize() {
    _scheduleSave();
  }

  @override
  void onWindowUnmaximize() {
    _scheduleSave();
  }

  @override
  void onWindowClose() {
    if (_closing) {
      return;
    }
    _closing = true;
    unawaited(_closeAppGracefully());
  }

  Future<void> _closeAppGracefully() async {
    _saveTimer?.cancel();
    await _closeStep(
      "保存窗口位置",
      saveWindowPlacement,
      timeout: const Duration(milliseconds: 300),
    );
    await _closeStep(
      "关闭播放器",
      () async {
        if (Get.isRegistered<LiveRoomController>()) {
          await Get.find<LiveRoomController>().closePlayerResources();
        }
      },
      timeout: const Duration(milliseconds: 900),
    );
    _closeStepSync("关闭同步服务", () {
      if (Get.isRegistered<SyncService>()) {
        SyncService.instance.onClose();
      }
    });
    await _closeStep(
      "关闭日志写入",
      Log.disposeWriter,
      timeout: const Duration(milliseconds: 600),
    );

    windowManager.removeListener(this);
    if (Platform.isWindows) {
      await _closeStep(
        "取消关闭拦截",
        () => windowManager.setPreventClose(false),
        timeout: const Duration(milliseconds: 300),
      );
    }
    await _closeStep(
      "请求窗口关闭",
      () => windowManager.close(),
      timeout: const Duration(milliseconds: 800),
    );
  }

  Future<void> _closeStep(
    String name,
    FutureOr<void> Function() action, {
    required Duration timeout,
  }) async {
    try {
      await Future.sync(action).timeout(timeout);
    } on TimeoutException {
      Log.logPrint("$name超时，继续退出");
    } catch (e) {
      Log.logPrint(e);
    }
  }

  void _closeStepSync(String name, void Function() action) {
    try {
      action();
    } catch (e) {
      Log.logPrint("$name失败: $e");
    }
  }
}

Future initServices() async {
  Hive.registerAdapter(FollowUserAdapter());
  Hive.registerAdapter(HistoryAdapter());
  Hive.registerAdapter(FollowUserTagAdapter());

  //包信息
  Utils.packageInfo = await PackageInfo.fromPlatform();
  //本地存储
  Log.d("Init LocalStorage Service");
  await Get.put(LocalStorageService()).init();
  await Get.put(DBService()).init();
  Get.put(CurrentRoomService());
  //初始化设置控制器
  Get.put(AppSettingsController());

  Get.put(BiliBiliAccountService());

  Get.put(DouyinAccountService());

  Get.put(KuaishouAccountService());

  Get.put(FollowService());
  Get.put(LiveSubtitleService());
  Get.put(ProfileBackupService());

  if (DesktopStartupArgs.isSecondaryDesktopInstance) {
    Log.i("Skip SyncService for desktop secondary player instance");
  } else {
    Get.put(SyncService());
  }

  initCoreLog();
}

void initCoreLog() {
  //日志信息
  CoreLog.enableLog =
      !kReleaseMode || AppSettingsController.instance.logEnable.value;
  CoreLog.requestLogType = RequestLogType.short;
  CoreLog.onPrintLog = (level, msg) {
    switch (level) {
      case Level.debug:
        Log.d(msg);
        break;
      case Level.error:
        Log.e(msg, StackTrace.current);
        break;
      case Level.info:
        Log.i(msg);
        break;
      case Level.warning:
        Log.w(msg);
        break;
      default:
        Log.logPrint(msg);
    }
  };
}

class MyApp extends StatelessWidget {
  static const MethodChannel _desktopShortcutChannel =
      MethodChannel("simple_live/desktop_shortcuts");
  static bool _desktopShortcutHandlerBound = false;
  static bool? _desktopShortcutCaptureEnabled;

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_desktopShortcutHandlerBound) {
      _desktopShortcutChannel.setMethodCallHandler(
        _handleDesktopShortcutMethod,
      );
      FocusManager.instance.addListener(_syncDesktopShortcutCaptureState);
      _desktopShortcutHandlerBound = true;
    }
    unawaited(_syncDesktopShortcutCaptureState());
    bool isDynamicColor = AppSettingsController.instance.isDynamic.value;
    Color styleColor = Color(AppSettingsController.instance.styleColor.value);
    return DynamicColorBuilder(
        builder: ((ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ColorScheme? lightColorScheme;
      ColorScheme? darkColorScheme;
      if (lightDynamic != null && darkDynamic != null && isDynamicColor) {
        lightColorScheme = lightDynamic;
        darkColorScheme = darkDynamic;
      } else {
        lightColorScheme = ColorScheme.fromSeed(
          seedColor: styleColor,
          brightness: Brightness.light,
        );
        darkColorScheme = ColorScheme.fromSeed(
            seedColor: styleColor, brightness: Brightness.dark);
      }
      return GetMaterialApp(
        title: "Simple Live",
        theme: AppStyle.lightTheme.copyWith(colorScheme: lightColorScheme),
        darkTheme: AppStyle.darkTheme.copyWith(colorScheme: darkColorScheme),
        themeMode:
            ThemeMode.values[Get.find<AppSettingsController>().themeMode.value],
        initialRoute: RoutePath.kIndex,
        getPages: AppPages.routes,
        routingCallback: (_) {
          unawaited(_syncDesktopShortcutCaptureState());
        },
        //国际化
        locale: const Locale("zh", "CN"),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale("zh", "CN")],
        logWriterCallback: (text, {bool? isError}) {
          Log.addDebugLog(text, (isError ?? false) ? Colors.red : Colors.grey);
          Log.writeLog(text, (isError ?? false) ? Level.error : Level.info);
        },
        // 升级后Android页面过渡动画似乎有BUG
        defaultTransition: Platform.isAndroid ? Transition.cupertino : null,
        //debugShowCheckedModeBanner: false,
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: FlutterSmartDialog.init(
          loadingBuilder: ((msg) => const AppLoaddingWidget()),
          //字体大小不跟随系统变化
          builder: (context, child) {
            // Fix for HyperOS windowed-mode Flutter bug:
            // - Values > 50 indicate the bug (windowed mode on HyperOS)
            // - Values == 0 are valid for fullscreen/immersive mode and must NOT be treated as abnormal
            const fallbackPadding = EdgeInsets.only(top: 25, bottom: 35);
            const maxNormalPadding = 50.0;

            final mediaQueryData = MediaQuery.of(context);
            final hasAbnormalPadding = Platform.isAndroid &&
                mediaQueryData.viewPadding.top > maxNormalPadding;

            final fixedMediaQueryData = hasAbnormalPadding
                ? mediaQueryData.copyWith(
                    viewPadding: fallbackPadding,
                    padding: fallbackPadding,
                    textScaler: const TextScaler.linear(1.0),
                  )
                : mediaQueryData.copyWith(
                    textScaler: const TextScaler.linear(1.0));

            return MediaQuery(
              data: fixedMediaQueryData,
              child: Stack(
                children: [
                  //侧键返回
                  RawGestureDetector(
                    excludeFromSemantics: true,
                    gestures: <Type, GestureRecognizerFactory>{
                      FourthButtonTapGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                              FourthButtonTapGestureRecognizer>(
                        () => FourthButtonTapGestureRecognizer(),
                        (FourthButtonTapGestureRecognizer instance) {
                          instance.onTapDown = (TapDownDetails details) async {
                            //如果处于全屏状态，退出全屏
                            if (!Platform.isAndroid && !Platform.isIOS) {
                              if (await windowManager.isFullScreen()) {
                                await windowManager.setFullScreen(false);
                                return;
                              }
                            }
                            Get.back();
                          };
                        },
                      ),
                    },
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      autofocus: true,
                      onKeyEvent: (KeyEvent event) async {
                        if (event is KeyDownEvent) {
                          await _handleGlobalShortcut(event);
                        }
                      },
                      child: child!,
                    ),
                  ),

                  //查看DEBUG日志按钮
                  //只在Debug、Profile模式显示
                  Visibility(
                    visible: !kReleaseMode,
                    child: Positioned(
                      right: 12,
                      bottom: 100 + context.mediaQueryViewPadding.bottom,
                      child: Opacity(
                        opacity: 0.4,
                        child: ElevatedButton(
                          child: const Text("DEBUG LOG"),
                          onPressed: () {
                            Get.bottomSheet(
                              const DebugLogPage(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }));
  }

  static bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get _hasEditableTextFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  static Future<void> _syncDesktopShortcutCaptureState() async {
    if (!_isDesktopPlatform) {
      return;
    }
    final enabled =
        Get.isRegistered<LiveRoomController>() && !_hasEditableTextFocus;
    if (_desktopShortcutCaptureEnabled == enabled) {
      return;
    }
    _desktopShortcutCaptureEnabled = enabled;
    try {
      await _desktopShortcutChannel.invokeMethod(
        "setShortcutCaptureEnabled",
        {"enabled": enabled},
      );
    } catch (e) {
      Log.d("桌面快捷键捕获状态同步失败: $e");
    }
  }

  Future<void> _handleGlobalShortcut(KeyDownEvent event) async {
    unawaited(_syncDesktopShortcutCaptureState());
    if (_hasEditableTextFocus) {
      return;
    }

    LiveRoomController? liveRoomController;
    if (Get.isRegistered<LiveRoomController>()) {
      liveRoomController = Get.find<LiveRoomController>();
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (liveRoomController != null &&
          (liveRoomController.fullScreenState.value ||
              liveRoomController.smallWindowState.value)) {
        await liveRoomController.exitPlayerWindowMode();
        return;
      }
      if (!Platform.isAndroid &&
          !Platform.isIOS &&
          await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      return;
    }

    if (liveRoomController == null) {
      return;
    }
    final settings = AppSettingsController.instance;
    final logicalKeyId = event.logicalKey.keyId;
    final physicalKey = event.physicalKey;

    bool matches(int shortcut) {
      if (shortcut == AppSettingsController.kShortcutDisabled) {
        return false;
      }
      if (shortcut == logicalKeyId) {
        return true;
      }
      // Prefer physical letter keys as a fallback so desktop shortcuts still
      // work when an IME changes the logical key mapping.
      if (shortcut == LogicalKeyboardKey.keyF.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyF;
      }
      if (shortcut == LogicalKeyboardKey.keyD.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyD;
      }
      if (shortcut == LogicalKeyboardKey.keyM.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyM;
      }
      if (shortcut == LogicalKeyboardKey.keyR.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyR;
      }
      if (shortcut == LogicalKeyboardKey.keyC.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyC;
      }
      if (shortcut == LogicalKeyboardKey.keyQ.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyQ;
      }
      if (shortcut == LogicalKeyboardKey.keyE.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyE;
      }
      if (shortcut == LogicalKeyboardKey.keyT.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyT;
      }
      if (shortcut == LogicalKeyboardKey.keyG.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyG;
      }
      if (shortcut == LogicalKeyboardKey.keyB.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyB;
      }
      if (shortcut == LogicalKeyboardKey.keyN.keyId) {
        return physicalKey == PhysicalKeyboardKey.keyN;
      }
      if (shortcut == LogicalKeyboardKey.arrowUp.keyId) {
        return physicalKey == PhysicalKeyboardKey.arrowUp;
      }
      if (shortcut == LogicalKeyboardKey.arrowDown.keyId) {
        return physicalKey == PhysicalKeyboardKey.arrowDown;
      }
      return false;
    }

    if (matches(settings.liveRoomShortcutFullScreen.value)) {
      await liveRoomController.toggleFullScreen();
      return;
    }
    if (matches(settings.liveRoomShortcutDanmaku.value)) {
      liveRoomController.toggleDanmakuByShortcut();
      return;
    }
    if (matches(settings.liveRoomShortcutMute.value)) {
      await liveRoomController.toggleMute();
      return;
    }
    if (_isDesktopPlatform &&
        matches(settings.liveRoomShortcutVolumeUp.value)) {
      await liveRoomController.adjustDesktopPlayerVolume(5);
      return;
    }
    if (_isDesktopPlatform &&
        matches(settings.liveRoomShortcutVolumeDown.value)) {
      await liveRoomController.adjustDesktopPlayerVolume(-5);
      return;
    }
    if (matches(settings.liveRoomShortcutRefresh.value)) {
      liveRoomController.refreshRoom();
      return;
    }
    if (matches(settings.liveRoomShortcutToggleChat.value) &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      liveRoomController.toggleDesktopSidePanel();
    }
  }

  Future<dynamic> _handleDesktopShortcutMethod(MethodCall call) async {
    if (call.method == "shortcutCaptureStateRequested") {
      await _syncDesktopShortcutCaptureState();
      return null;
    }
    if (call.method != "shortcutKeyDown") {
      return null;
    }
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return null;
    }
    final args = call.arguments;
    if (args is! Map) {
      return null;
    }
    final key = args["key"]?.toString().trim() ?? "";
    if (key.isEmpty) {
      return null;
    }
    await _handleDesktopShortcutByPhysicalKey(key);
    return null;
  }

  Future<void> _handleDesktopShortcutByPhysicalKey(
      String physicalKeyName) async {
    if (_hasEditableTextFocus) {
      return;
    }

    if (!Get.isRegistered<LiveRoomController>()) {
      return;
    }
    final liveRoomController = Get.find<LiveRoomController>();
    final settings = AppSettingsController.instance;

    bool matchesDesktopShortcut(int shortcut) {
      if (shortcut == AppSettingsController.kShortcutDisabled) {
        return false;
      }
      switch (physicalKeyName) {
        case "keyF":
          return shortcut == LogicalKeyboardKey.keyF.keyId;
        case "keyD":
          return shortcut == LogicalKeyboardKey.keyD.keyId;
        case "keyM":
          return shortcut == LogicalKeyboardKey.keyM.keyId;
        case "keyR":
          return shortcut == LogicalKeyboardKey.keyR.keyId;
        case "keyC":
          return shortcut == LogicalKeyboardKey.keyC.keyId;
        case "keyQ":
          return shortcut == LogicalKeyboardKey.keyQ.keyId;
        case "keyE":
          return shortcut == LogicalKeyboardKey.keyE.keyId;
        case "keyT":
          return shortcut == LogicalKeyboardKey.keyT.keyId;
        case "keyG":
          return shortcut == LogicalKeyboardKey.keyG.keyId;
        case "keyB":
          return shortcut == LogicalKeyboardKey.keyB.keyId;
        case "keyN":
          return shortcut == LogicalKeyboardKey.keyN.keyId;
        case "arrowUp":
          return shortcut == LogicalKeyboardKey.arrowUp.keyId;
        case "arrowDown":
          return shortcut == LogicalKeyboardKey.arrowDown.keyId;
        default:
          return false;
      }
    }

    if (matchesDesktopShortcut(settings.liveRoomShortcutFullScreen.value)) {
      await liveRoomController.toggleFullScreen();
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutDanmaku.value)) {
      liveRoomController.toggleDanmakuByShortcut();
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutMute.value)) {
      await liveRoomController.toggleMute();
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutVolumeUp.value)) {
      await liveRoomController.adjustDesktopPlayerVolume(5);
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutVolumeDown.value)) {
      await liveRoomController.adjustDesktopPlayerVolume(-5);
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutRefresh.value)) {
      liveRoomController.refreshRoom();
      return;
    }
    if (matchesDesktopShortcut(settings.liveRoomShortcutToggleChat.value)) {
      liveRoomController.toggleDesktopSidePanel();
    }
  }
}
