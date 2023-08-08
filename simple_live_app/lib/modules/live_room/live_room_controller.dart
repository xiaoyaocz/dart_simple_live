import 'dart:async';
import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:remixicon/remixicon.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:wakelock/wakelock.dart';

class LiveRoomController extends BaseController {
  final Site site;
  final String roomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.site,
    required this.roomId,
  }) {
    liveDanmaku = site.liveSite.getDanmaku();
  }

  final AppSettingsController settingsController =
      Get.find<AppSettingsController>();
  final ScrollController scrollController = ScrollController();
  RxList<LiveMessage> messages = RxList<LiveMessage>();
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();
  final screenBrightness = ScreenBrightness();
  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  GlobalKey globalPlayerKey = GlobalKey();
  GlobalKey globalDanmuKey = GlobalKey();
  var online = 0.obs;
  var fullScreen = false.obs;
  var enableDanmaku = true.obs;
  var followed = false.obs;

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;

  /// 直播状态
  var liveStatus = false.obs;

  /// 播放器加载中
  var playerLoadding = false.obs;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  var showDanmuSettings = false.obs;
  var showQualites = false.obs;
  var showLines = false.obs;
  DanmakuController? danmakuController;
  late final player = Player();
  late final videoController = VideoController(
    player,
    configuration: settingsController.playerCompatMode.value
        ? const VideoControllerConfiguration(
            vo: 'mediacodec_embed',
            hwdec: 'mediacodec',
          )
        : VideoControllerConfiguration(
            enableHardwareAcceleration: settingsController.hardwareDecode.value,
          ),
  );

  DanmakuView? danmakuView;

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  /// 当前线路
  var currentUrl = -1;
  var currentUrlInfo = "".obs;

  /// 显示播放控制
  Rx<bool> showControls = true.obs;

  Timer? hideControlsTimer;

  @override
  void onInit() {
    initAutoExit();
    playerListener();
    enableDanmaku.value = settingsController.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    setSystem();
    loadData();

    super.onInit();
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (settingsController.autoExitEnable.value) {
      countdown.value = settingsController.autoExitDuration.value * 60;
      autoExitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        countdown.value -= 1;
        if (countdown.value <= 0) {
          timer.cancel();
          await Wakelock.disable();
          exit(0);
        }
      });
    }
  }

  void refreshRoom() {
    superChats.clear();
    liveDanmaku.stop();

    loadData();
  }

  /// 设置系统状态
  void setSystem() {
    PerfectVolumeControl.hideUI = false;

    //屏幕常亮
    Wakelock.enable();

    if (settingsController.autoFullScreen.value) {
      //如果是抖音直接设置成竖屏
      if (site.id == "douyin") {
        isVertical.value = true;
      }
      setFull();
    }

    hideControlsTimer = Timer(const Duration(milliseconds: 3000), () {
      //3秒后隐藏控制UI
      showControls.value = false;
    });
  }

  /// 弹幕控制器初始化，初始化一些选项
  void setDanmakuController(DanmakuController controller) {
    danmakuController = controller;
    danmakuController?.updateOption(
      DanmakuOption(
        fontSize: settingsController.danmuSize.value,
        area: settingsController.danmuArea.value,
        duration: settingsController.danmuSpeed.value,
        opacity: settingsController.danmuOpacity.value,
        strokeWidth: settingsController.danmuStrokeWidth.value,
      ),
    );
  }

  /// 更新弹幕选项
  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  /// 聊天栏始终滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
    liveDanmaku.onClose = onWSClose;
    liveDanmaku.onReady = onWSReady;
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) {
    if (msg.type == LiveMessageType.chat) {
      if (messages.length > 200) {
        messages.removeAt(0);
      }

      // 关键词屏蔽检查
      for (var keyword in settingsController.shieldList) {
        if (msg.message.contains(keyword)) {
          Log.d("关键词：$keyword\n消息内容：${msg.message}");
          return;
        }
      }

      messages.add(msg);

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chatScrollToBottom(),
      );
      addDanmaku(msg);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      superChats.add(msg.data);
    }
  }

  /// 接收到WebSocket关闭信息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket准备就绪
  void onWSReady() {
    addSysMsg("弹幕服务器连接正常");
  }

  /// 加载直播间信息
  void loadData() async {
    try {
      SmartDialog.showLoading(msg: "");
      errorMsg.value = "";
      addSysMsg("正在读取直播间信息");
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);
      getSuperChatMessage();

      addHistory();
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status;
      if (liveStatus.value) {
        getPlayQualites();
      }

      addSysMsg("开始连接弹幕服务器");
      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  /// 读取SC
  void getSuperChatMessage() async {
    try {
      var sc =
          await site.liveSite.getSuperChatMessage(roomId: detail.value!.roomId);
      superChats.addAll(sc);
    } catch (e) {
      Log.logPrint(e);
      addSysMsg("SC读取失败");
    }
  }

  /// 移除掉已到期的SC
  void removeSuperChats() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.value = superChats
        .where((x) => x.endTime.millisecondsSinceEpoch > now)
        .toList();
  }

  /// 初始化播放器
  void getPlayQualites() async {
    qualites.clear();
    currentQuality = -1;
    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取播放清晰度");
        return;
      }
      qualites.value = playQualites;

      if (settingsController.qualityLevel.value == 2) {
        //最高
        currentQuality = 0;
      } else if (settingsController.qualityLevel.value == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else {
        //中间值
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }

      getPlayUrl();
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法读取播放清晰度");
    }
  }

  void getPlayUrl() async {
    playUrls.clear();
    currentQualityInfo.value = qualites[currentQuality].quality;
    currentUrlInfo.value = "";
    currentUrl = -1;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.value = playUrl;
    currentUrl = 0;
    currentUrlInfo.value = "线路${currentUrl + 1}";
    setPlayer();
  }

  void setPlayer() async {
    currentUrlInfo.value = "线路${currentUrl + 1}";
    errorMsg.value = "";
    Map<String, String> headers = {};
    if (site.id == "bilibili") {
      headers = {
        "referer": "https://live.bilibili.com",
        "user-agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.188"
      };
    }
    playerLoadding.value = true;
    player.open(
      Media(
        playUrls[currentUrl],
        httpHeaders: headers,
      ),
    );

    Log.d("播放链接\r\n：${playUrls[currentUrl]}");
  }

  StreamSubscription? bufferingStream;
  StreamSubscription? errorStream;
  StreamSubscription? endStream;
  StreamSubscription? trackStream;
  StreamSubscription? widthStream;
  StreamSubscription? heightStream;

  /// 事件监听
  void playerListener() {
    bufferingStream = player.stream.buffering.listen((event) {
      Log.w('Buffering:$event');
      playerLoadding.value = event;
    });

    widthStream = player.stream.width.listen((event) {
      Log.w(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');

      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });

    heightStream = player.stream.height.listen((event) {
      Log.w(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
    });
    trackStream = player.stream.track.listen((event) {
      Log.w('Track:$event');
      //接收到轨道信息后，隐藏加载
      playerLoadding.value = false;
    });
    errorStream = player.stream.error.listen((event) {
      Log.w(event);
      // 切换清晰度时会触发此事件，暂时不做处理
      mediaError();
    });

    endStream = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
  }

  /// 取消事件监听
  void playerCancelListener() {
    bufferingStream?.cancel();
    trackStream?.cancel();
    errorStream?.cancel();
    endStream?.cancel();
    widthStream?.cancel();
    heightStream?.cancel();
  }

  void mediaEnd() {
    if (playUrls.length - 1 == currentUrl) {
      liveStatus.value = false;
    } else {
      currentUrl += 1;
      setPlayer();
    }
  }

  void mediaError() {
    if (playUrls.length - 1 == currentUrl) {
      //liveStatus.value = false;
      errorMsg.value = "播放失败";
      //Log.w(player.state..errorDescription ?? "");
    } else {
      currentUrl += 1;
      setPlayer();
    }
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    messages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 添加一条弹幕
  void addDanmaku(LiveMessage msg) {
    if (!enableDanmaku.value || !liveStatus.value) {
      return;
    }
    danmakuController?.addItems(
      [
        DanmakuItem(
          msg.message,
          color: Color.fromARGB(
            255,
            msg.color.r,
            msg.color.g,
            msg.color.b,
          ),
        ),
      ],
    );
  }

  /// 播放器全屏
  void setFull() {
    fullScreen.value = true;
    //全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    if (!isVertical.value) {
      //横屏
      setLandscapeOrientation();
    }

    danmakuController?.clear();
  }

  /// 退出全屏
  void exitFull() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    setPortraitOrientation();
    fullScreen.value = false;
    danmakuController?.clear();
  }

  /// 底部打开播放器设置
  void showBottomDanmuSettings() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 12,
              ),
              title: const Text("弹幕设置"),
              trailing: IconButton(
                onPressed: Get.back,
                icon: const Icon(Remix.close_line),
              ),
            ),
            Expanded(
              child: buildDanmuSettings(),
            ),
          ],
        ),
      ),
    );
  }

  void showQualitySheet() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 12,
              ),
              title: const Text("切换清晰度"),
              trailing: IconButton(
                onPressed: Get.back,
                icon: const Icon(Remix.close_line),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: qualites.length,
                itemBuilder: (_, i) {
                  var item = qualites[i];
                  return RadioListTile(
                    value: i,
                    groupValue: currentQuality,
                    title: Text(item.quality),
                    onChanged: (e) {
                      Get.back();
                      currentQuality = i;
                      getPlayUrl();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showPlayUrlsSheet() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 12,
              ),
              title: const Text("切换线路"),
              trailing: IconButton(
                onPressed: Get.back,
                icon: const Icon(Remix.close_line),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: playUrls.length,
                itemBuilder: (_, i) {
                  return RadioListTile(
                    value: i,
                    groupValue: currentUrl,
                    title: Text("线路${i + 1}"),
                    secondary: Text(
                      playUrls[i].contains(".flv") ? "FLV" : "HLS",
                    ),
                    onChanged: (e) {
                      Get.back();
                      currentUrl = i;
                      setPlayer();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: AppStyle.bottomBarHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("刷新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                refreshRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              trailing: const Icon(Icons.chevron_right),
              title: const Text("切换清晰度"),
              onTap: () {
                Get.back();
                showQualitySheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_video),
              title: const Text("切换线路"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                showPlayUrlsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("分享"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                share();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDanmuSettings() {
    return Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕区域: ${(settingsController.danmuArea.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: settingsController.danmuArea.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              settingsController.setDanmuArea(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(area: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "不透明度: ${(settingsController.danmuOpacity.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: settingsController.danmuOpacity.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              settingsController.setDanmuOpacity(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(opacity: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕大小: ${(settingsController.danmuSize.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: settingsController.danmuSize.value,
            min: 8,
            max: 36,
            onChanged: (e) {
              settingsController.setDanmuSize(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(fontSize: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕速度: ${(settingsController.danmuSpeed.value).toInt()} (越小越快)",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: settingsController.danmuSpeed.value,
            min: 4,
            max: 20,
            onChanged: (e) {
              settingsController.setDanmuSpeed(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(duration: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕描边: ${(settingsController.danmuStrokeWidth.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: settingsController.danmuStrokeWidth.value,
            min: 0,
            max: 10,
            onChanged: (e) {
              settingsController.setDanmuStrokeWidth(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(strokeWidth: e),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 添加历史记录
  void addHistory() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    var history = DBService.instance.getHistory(id);
    if (history != null) {
      history.updateTime = DateTime.now();
    }
    history ??= History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      updateTime: DateTime.now(),
    );

    DBService.instance.addOrUpdateHistory(history);
  }

  /// 关注用户
  void followUser() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    DBService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
      ),
    );
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注用户
  void removeFollowUser() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  void share() {
    if (detail.value == null) {
      return;
    }
    Share.share(detail.value!.url);
  }

  @override
  void onClose() {
    autoExitTimer?.cancel();
    playerCancelListener();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    setPortraitOrientation();
    screenBrightness.resetScreenBrightness();
    Wakelock.disable();

    player.dispose();

    liveDanmaku.stop();
    danmakuController = null;
    super.onClose();
  }

  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var _verStart = 0.0;
  var showTip = false.obs;
  var seekTip = "".obs;

  /// 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    verticalDragging = true;
    _verStart = details.globalPosition.dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;
    _currentVolume = await PerfectVolumeControl.volume;
    _currentBrightness = await screenBrightness.current;
    showTip.value = true;
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (verticalDragging == false) return;
    //String text = "";
    double value = 0.0;

    Log.logPrint("$_verStart/${e.globalPosition.dy}");

    //音量
    if (!leftVerticalDrag) {
      if (e.globalPosition.dy > _verStart) {
        value = ((e.globalPosition.dy - _verStart) / (Get.height * 0.5));

        var seek = _currentVolume - value;
        if (seek < 0) {
          seek = 0;
        }
        PerfectVolumeControl.setVolume(seek);
        seekTip.value = "音量 ${(seek * 100).toInt()}%";
        Log.logPrint(value);
      } else {
        value = ((e.globalPosition.dy - _verStart) / (Get.height * 0.5));
        var seek = value.abs() + _currentVolume;
        if (seek > 1) {
          seek = 1;
        }

        PerfectVolumeControl.setVolume(seek);

        seekTip.value = "音量 ${(seek * 100).toInt()}%";
        Log.logPrint(value);
      }
    } else {
      //亮度

      if (e.globalPosition.dy > _verStart) {
        value = ((e.globalPosition.dy - _verStart) / (Get.height * 0.5));

        var seek = _currentBrightness - value;
        if (seek < 0) {
          seek = 0;
        }
        screenBrightness.setScreenBrightness(seek);

        seekTip.value = "亮度 ${(seek * 100).toInt()}%";
        Log.logPrint(value);
      } else {
        value = ((e.globalPosition.dy - _verStart) / (Get.height * 0.5));
        var seek = value.abs() + _currentBrightness;
        if (seek > 1) {
          seek = 1;
        }

        screenBrightness.setScreenBrightness(seek);
        seekTip.value = "亮度 ${(seek * 100).toInt()}%";
        Log.logPrint(value);
      }
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    verticalDragging = false;
    leftVerticalDrag = false;
    showTip.value = false;
  }
}
