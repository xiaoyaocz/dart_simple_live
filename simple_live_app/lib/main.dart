import 'dart:async';
import 'dart:io';
import 'package:simple_live_app/services/windows_direct_network.dart';
import 'package:simple_live_app/services/window_appearance_controller.dart';
import 'package:simple_live_app/widgets/mobile_material_background.dart';

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
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/modules/other/debug_log_page.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/live_notification_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/playback_route_history.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/services/system_proxy_service.dart';
import 'package:simple_live_app/services/webdav_auto_sync_service.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:window_manager/window_manager.dart';

import 'package:path/path.dart' as p;
import 'package:dynamic_color/dynamic_color.dart';

void main() async {
  WindowsDirectNetwork.initialize();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemProxyService.instance.initialize();
  await migrateData();
  await initWindow();
  MediaKit.ensureInitialized();
  await Hive.initFlutter(
    (!Platform.isAndroid && !Platform.isIOS)
        ? (await getApplicationSupportDirectory()).path
        : null,
  );
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
  WindowOptions windowOptions = const WindowOptions(
    size: Constant.kDefaultWindowSize,
    minimumSize: Size(280, 280),
    center: true,
    title: "Simple Live",
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
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
  PlaybackRouteHistory.instance.attachPersistence(
    read: () => LocalStorageService.instance
        .getValue(LocalStorageService.kPlaybackRouteHistory, ''),
    write: (json) => LocalStorageService.instance
        .setValue(LocalStorageService.kPlaybackRouteHistory, json),
  );
  await Get.put(DBService()).init();
  //初始化设置控制器
  Get.put(AppSettingsController());
  await Get.put(WindowAppearanceController()).initialize();

  Get.put(BiliBiliAccountService());

  Get.put(DouyinAccountService());

  Get.put(SyncService());

  await Get.put(LiveNotificationService()).initialize();

  Get.put(WebDavAutoSyncService()).scheduleStartupSync();

  Get.put(FollowService());

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
        if (!kReleaseMode) {
          Log.addDebugLog(msg, Colors.red);
        }
        Log.writeLog(msg, Level.error);
        if (kDebugMode) {
          print(msg);
        }
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const _windowChannel = MethodChannel('simple_live/window');
  final _keyboardFocusNode = FocusNode();
  bool _handlingClose = false;

  Future<bool> _exitPlayerFullScreen() async {
    if (Platform.isAndroid ||
        Platform.isIOS ||
        !await windowManager.isFullScreen()) {
      return false;
    }
    final tag = Get.parameters['instance'];
    if (Get.currentRoute == RoutePath.kLiveRoomDetail &&
        Get.isRegistered<LiveRoomController>(tag: tag)) {
      final controller = Get.find<LiveRoomController>(tag: tag);
      if (controller.fullScreenState.value) {
        await controller.exitFull();
        return true;
      }
    }
    if (Get.currentRoute == RoutePath.kMultiView &&
        Get.isRegistered<MultiViewController>()) {
      final controller = Get.find<MultiViewController>();
      if (controller.fullScreen.value) {
        await controller.exitFullScreen();
        return true;
      }
    }
    await windowManager.setFullScreen(false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      _windowChannel.setMethodCallHandler((call) async {
        if (call.method == 'onCloseRequest') await _handleCloseRequest();
        if (call.method == 'onAppearanceChanged') {
          await Get.find<WindowAppearanceController>().apply();
        }
        if (call.method == 'onAppearanceInvalidated') {
          await Get.find<WindowAppearanceController>().apply(force: true);
        }
        if (call.method == 'onNotificationClick') {
          final args = call.arguments;
          if (args is Map && Get.isRegistered<LiveNotificationService>()) {
            await LiveNotificationService.instance.handleNotificationClick(
              args['siteId']?.toString() ?? '',
              args['roomId']?.toString() ?? '',
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) _windowChannel.setMethodCallHandler(null);
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (Platform.isWindows) Get.find<WindowAppearanceController>().apply();
  }

  Future<void> _handleCloseRequest() async {
    if (_handlingClose) return;
    _handlingClose = true;
    try {
      var action = LocalStorageService.instance
          .getValue(LocalStorageService.kCloseAction, 0);
      if (action != 1 && action != 2) {
        bool remember = false;
        action = await Get.dialog<int>(
              StatefulBuilder(builder: (context, update) {
                final colors = Theme.of(context).colorScheme;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Dialog(
                  backgroundColor: isDark
                      ? const Color(0xFF242424)
                      : colors.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '关闭窗口？',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => update(() => remember = !remember),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: remember,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (value) =>
                                      update(() => remember = value ?? false),
                                ),
                                const Text('不再显示，记住我的选择'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFF302F2D)
                                      : colors.surfaceContainerHighest,
                                  foregroundColor: isDark
                                      ? Colors.white70
                                      : colors.onSurface,
                                ),
                                onPressed: () => Get.back(result: 2),
                                child: const Text('最小化到系统托盘'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFFF5263E)
                                      : colors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Get.back(result: 1),
                                child: const Text('退出应用'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              barrierDismissible: true,
            ) ??
            0;
        if (remember && action != 0) {
          await LocalStorageService.instance
              .setValue(LocalStorageService.kCloseAction, action);
        }
      }
      if (action == 1 || action == 2) {
        await _windowChannel
            .invokeMethod(action == 1 ? 'exitApp' : 'hideToTray');
      }
    } catch (error, stackTrace) {
      Log.e('关闭窗口失败：$error', stackTrace);
    } finally {
      _handlingClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        theme: Get.find<WindowAppearanceController>().theme(
            AppStyle.lightTheme.copyWith(colorScheme: lightColorScheme)),
        darkTheme: Get.find<WindowAppearanceController>().theme(
            AppStyle.darkTheme.copyWith(colorScheme: darkColorScheme)),
        themeMode:
            ThemeMode.values[Get.find<AppSettingsController>().themeMode.value],
        initialRoute: RoutePath.kIndex,
        getPages: AppPages.routes,
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
            final hasAbnormalPadding =
                mediaQueryData.viewPadding.top > maxNormalPadding;

            final fixedMediaQueryData = hasAbnormalPadding
                ? mediaQueryData.copyWith(
                    viewPadding: fallbackPadding,
                    padding: fallbackPadding,
                    textScaler: const TextScaler.linear(1.0),
                  )
                : mediaQueryData.copyWith(
                    textScaler: const TextScaler.linear(1.0));

            final content = MediaQuery(
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
                          instance.onTap = () async {
                            if (await _exitPlayerFullScreen()) return;
                            Get.back();
                          };
                        },
                      ),
                    },
                    child: KeyboardListener(
                      focusNode: _keyboardFocusNode,
                      onKeyEvent: (KeyEvent event) async {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.escape) {
                          await _exitPlayerFullScreen();
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
            final appearance = Get.find<WindowAppearanceController>();
            if (Platform.isAndroid) {
              return MobileMaterialBackground(controller: appearance, child: content);
            }
            // One tint layer only: nested transparent Scaffolds must not accumulate opacity.
            return ColoredBox(
              color: Get.find<WindowAppearanceController>().tint(Theme.of(context)),
              child: content,
            );
          },
        ),
      );
    }));
  }
}
