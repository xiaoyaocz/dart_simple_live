import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveRoomNewController extends PlayerController {
  final Site site;
  final String roomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomNewController({
    required this.site,
    required this.roomId,
  }) {
    liveDanmaku = site.liveSite.getDanmaku();
  }
  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();
  final ScrollController scrollController = ScrollController();
  RxList<LiveMessage> messages = RxList<LiveMessage>();

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

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;

  @override
  void onInit() {
    initAutoExit();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    loadData();
    super.onInit();
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (AppSettingsController.instance.autoExitEnable.value) {
      countdown.value =
          AppSettingsController.instance.autoExitDuration.value * 60;
      autoExitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        countdown.value -= 1;
        if (countdown.value <= 0) {
          timer.cancel();
          await WakelockPlus.disable();
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
      for (var keyword in AppSettingsController.instance.shieldList) {
        if (msg.message.contains(keyword)) {
          Log.d("关键词：$keyword\n消息内容：${msg.message}");
          return;
        }
      }

      messages.add(msg);

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => chatScrollToBottom(),
      );
      if (!liveStatus.value) {
        return;
      }
      addDanmaku([
        DanmakuItem(
          msg.message,
          color: Color.fromARGB(
            255,
            msg.color.r,
            msg.color.g,
            msg.color.b,
          ),
        ),
      ]);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      superChats.add(msg.data);
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

      if (AppSettingsController.instance.qualityLevel.value == 2) {
        //最高
        currentQuality = 0;
      } else if (AppSettingsController.instance.qualityLevel.value == 0) {
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

    player.open(
      Media(
        playUrls[currentUrl],
        httpHeaders: headers,
      ),
    );

    Log.d("播放链接\r\n：${playUrls[currentUrl]}");
  }

  @override
  void mediaEnd() {
    // 遍历线路，如果全部链接都断开就是直播结束了
    if (playUrls.length - 1 == currentUrl) {
      liveStatus.value = false;
    } else {
      currentUrl += 1;
      setPlayer();
    }
  }

  @override
  void mediaError(String error) {
    if (playUrls.length - 1 == currentUrl) {
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败:$error");
    } else {
      currentUrl += 1;
      setPlayer();
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

  Widget buildDanmuSettings() {
    return Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕区域: ${(AppSettingsController.instance.danmuArea.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuArea.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuArea(e);
              updateDanmuOption(
                danmakuController?.option.copyWith(area: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "不透明度: ${(AppSettingsController.instance.danmuOpacity.value * 100).toInt()}%",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuOpacity.value,
            max: 1.0,
            min: 0.1,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuOpacity(e);

              updateDanmuOption(
                danmakuController?.option.copyWith(opacity: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕大小: ${(AppSettingsController.instance.danmuSize.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuSize.value,
            min: 8,
            max: 36,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSize(e);

              updateDanmuOption(
                danmakuController?.option.copyWith(fontSize: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕速度: ${(AppSettingsController.instance.danmuSpeed.value).toInt()} (越小越快)",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuSpeed.value,
            min: 4,
            max: 20,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuSpeed(e);

              updateDanmuOption(
                danmakuController?.option.copyWith(duration: e),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "弹幕描边: ${(AppSettingsController.instance.danmuStrokeWidth.value).toInt()}",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Slider(
            value: AppSettingsController.instance.danmuStrokeWidth.value,
            min: 0,
            max: 10,
            onChanged: (e) {
              AppSettingsController.instance.setDanmuStrokeWidth(e);

              updateDanmuOption(
                danmakuController?.option.copyWith(strokeWidth: e),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    autoExitTimer?.cancel();

    liveDanmaku.stop();
    danmakuController = null;
    super.onClose();
  }
}
