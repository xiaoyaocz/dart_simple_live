import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/desktop_startup_args.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/routes/app_pages.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/services/kuaishou_account_service.dart';
import 'package:simple_live_tv_app/services/local_storage_service.dart';
import 'package:simple_live_tv_app/services/profile_backup_service.dart';
import 'package:simple_live_tv_app/services/sync_service.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DesktopStartupArgs.initialize(args);
  await writeDesktopStartupLog(
    "start args=${args.join(" ")} "
    "secondary=${DesktopStartupArgs.isSecondaryDesktopInstance} "
    "startupRoom=${DesktopStartupArgs.startupRoom} "
    "startupBounds=${DesktopStartupArgs.startupWindowBounds} "
    "frameless=${DesktopStartupArgs.startupFramelessTile}",
  );
  await initWindow();
  MediaKit.ensureInitialized();
  final hivePath = await resolveHivePath();
  await writeDesktopStartupLog("hive init path=$hivePath");
  await Hive.initFlutter(hivePath);
  //初始化服务
  await initServices();
  if (!isDesktop) {
    // 强制横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    // 全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }
  runApp(const MyApp());
  unawaited(setupDesktopWindowLifecycle());
}

bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> writeDesktopStartupLog(String message) async {
  if (!isDesktop) {
    return;
  }
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(appSupportDir.path, "log"));
    await logDir.create(recursive: true);
    final logFile = File(p.join(logDir.path, "tv-windows-startup.log"));
    final line =
        "${DateTime.now().toIso8601String()} pid=$pid $message${Platform.lineTerminator}";
    await logFile.writeAsString(line, mode: FileMode.append, flush: true);
  } catch (_) {
    // Startup diagnostics must never block the app from opening.
  }
}

Future<String?> resolveHivePath() async {
  if (!isDesktop) {
    return null;
  }
  final appSupportDir = await getApplicationSupportDirectory();
  if (!DesktopStartupArgs.isSecondaryDesktopInstance) {
    await writeDesktopStartupLog("primary hive source=${appSupportDir.path}");
    return appSupportDir.path;
  }
  final instanceDir = await prepareSecondaryHiveDirectory(appSupportDir);
  await writeDesktopStartupLog("secondary hive snapshot=${instanceDir.path}");
  return instanceDir.path;
}

Future<Directory> prepareSecondaryHiveDirectory(Directory sourceDir) async {
  final instancesRoot = Directory(p.join(sourceDir.path, "tv_instances"));
  await instancesRoot.create(recursive: true);
  final instanceDir = Directory(
    p.join(
      instancesRoot.path,
      "${DateTime.now().millisecondsSinceEpoch}_$pid",
    ),
  );
  await instanceDir.create(recursive: true);
  await writeDesktopStartupLog(
    "prepare secondary hive source=${sourceDir.path} target=${instanceDir.path}",
  );
  await copyHiveSnapshot(sourceDir, instanceDir);
  await cleanupOldSecondaryHiveDirectories(instancesRoot, instanceDir);
  return instanceDir;
}

Future<void> copyHiveSnapshot(Directory sourceDir, Directory targetDir) async {
  if (!await sourceDir.exists()) {
    await writeDesktopStartupLog(
        "hive snapshot source missing=${sourceDir.path}");
    return;
  }
  var copied = 0;
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
      copied += 1;
    } catch (e) {
      await writeDesktopStartupLog(
          "hive snapshot copy failed file=$fileName error=$e");
      Log.logPrint(e);
    }
  }
  await writeDesktopStartupLog("hive snapshot copied files=$copied");
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
        await writeDesktopStartupLog(
            "deleted old secondary hive=${entity.path}");
      }
    } catch (e) {
      Log.logPrint(e);
    }
  }
}

Future<void> initWindow() async {
  if (!isDesktop) {
    return;
  }
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    minimumSize: Size(320, 240),
    title: "Simple Live TV",
  );
  await windowManager.waitUntilReadyToShow(windowOptions);
}

Future<void> setupDesktopWindowLifecycle() async {
  if (!isDesktop) {
    return;
  }
  await WidgetsBinding.instance.endOfFrame;
  final startupBounds = DesktopStartupArgs.startupWindowBounds;
  await writeDesktopStartupLog("window lifecycle startupBounds=$startupBounds");
  if (startupBounds != null) {
    if (DesktopStartupArgs.startupFramelessTile) {
      await windowManager.setAsFrameless();
      await windowManager.setResizable(false);
      await windowManager.setHasShadow(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    await windowManager.setBounds(startupBounds);
  } else {
    await windowManager.center();
  }
  await windowManager.show();
  await windowManager.focus();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await windowManager.show();
  await windowManager.focus();
  await writeDesktopStartupLog("window shown and focused");
}

Future initServices() async {
  //日志信息
  CoreLog.enableLog = !kReleaseMode;
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

  Hive.registerAdapter(FollowUserAdapter());
  Hive.registerAdapter(HistoryAdapter());

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
  Get.put(ProfileBackupService());

  if (DesktopStartupArgs.isSecondaryDesktopInstance) {
    Log.i("Skip SyncService for TV-Windows secondary player instance");
  } else {
    Get.put(SyncService());
  }

  Get.put(FollowUserService());
}

class MyApp extends StatelessWidget {
  static const MethodChannel _desktopShortcutChannel =
      MethodChannel("simple_live_tv/desktop_shortcuts");
  static bool _desktopShortcutHandlerBound = false;

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_desktopShortcutHandlerBound) {
      _desktopShortcutChannel.setMethodCallHandler(
        _handleDesktopShortcutMethod,
      );
      _desktopShortcutHandlerBound = true;
    }
    final startupRoom = DesktopStartupArgs.startupRoom;
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: 'Simple Live TV',
          theme: AppStyle.lightTheme,
          initialRoute: AppSettingsController.instance.firstRun
              ? RoutePath.kAgreement
              : RoutePath.kHome,
          getPages: AppPages.routes,
          debugShowCheckedModeBanner: false,
          builder: FlutterSmartDialog.init(
            loadingBuilder: (msg) => Center(
              child: SizedBox(
                width: 64.w,
                height: 64.w,
                child: CircularProgressIndicator(
                  strokeWidth: 8.w,
                  color: Colors.white,
                ),
              ),
            ),
            //字体大小不跟随系统变化
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child!,
            ),
          ),
          onReady: () {
            if (startupRoom == null ||
                AppSettingsController.instance.firstRun) {
              unawaited(
                writeDesktopStartupLog(
                  "onReady no startup room firstRun=${AppSettingsController.instance.firstRun}",
                ),
              );
              return;
            }
            final site = Sites.allSites[startupRoom["siteId"]];
            final roomId = startupRoom["roomId"];
            if (site == null || roomId == null || roomId.isEmpty) {
              unawaited(
                writeDesktopStartupLog(
                  "onReady invalid startup room=$startupRoom",
                ),
              );
              return;
            }
            unawaited(
              writeDesktopStartupLog(
                "onReady open startup room site=${site.id} roomId=$roomId",
              ),
            );
            AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
          },
        );
      },
    );
  }

  Future<dynamic> _handleDesktopShortcutMethod(MethodCall call) async {
    if (call.method != "shortcutKeyDown" || !isDesktop) {
      return null;
    }
    final args = call.arguments;
    if (args is! Map) {
      return null;
    }
    final key = args["key"]?.toString().trim() ?? "";
    if (key != "keyM") {
      return null;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return null;
    }
    if (!Get.isRegistered<LiveRoomController>()) {
      return null;
    }
    Get.find<LiveRoomController>().handleDesktopShortcut(
      key,
      source: "channel",
    );
    return null;
  }
}
