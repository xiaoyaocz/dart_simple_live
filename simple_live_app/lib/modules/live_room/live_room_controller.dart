import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveRoomController extends PlayerController {
  final Site site;
  final String roomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.site,
    required this.roomId,
  }) {
    liveDanmaku = site.liveSite.getDanmaku();
    // 抖音应该默认是竖屏的
    if (site.id == "douyin") {
      isVertical.value = true;
    }
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
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

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
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        getPlayQualites();
      }
      if (detail.value!.isRecord) {
        addSysMsg("当前主播未开播，正在轮播录像");
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
    currentLineInfo.value = "";
    currentLineIndex = -1;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.value = playUrl;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    mediaErrorRetryCount = 0;
    setPlayer();
  }

  void changePlayLine(int index) {
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    setPlayer();
  }

  void setPlayer() async {
    currentLineInfo.value = "线路${currentLineIndex + 1}";
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
        playUrls[currentLineIndex],
        httpHeaders: headers,
      ),
    );

    Log.d("播放链接\r\n：${playUrls[currentLineIndex]}");
  }

  @override
  void mediaEnd() async {
    if (mediaErrorRetryCount < 2) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer();
      return;
    }

    Log.d("播放结束");
    // 遍历线路，如果全部链接都断开就是直播结束了
    if (playUrls.length - 1 == currentLineIndex) {
      liveStatus.value = false;
    } else {
      changePlayLine(currentLineIndex + 1);

      //setPlayer();
    }
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    if (mediaErrorRetryCount < 2) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      if (mediaErrorRetryCount == 1) {
        //延迟一秒再刷新
        await Future.delayed(const Duration(seconds: 1));
      }
      mediaErrorRetryCount += 1;
      //刷新一次
      setPlayer();
      return;
    }

    if (playUrls.length - 1 == currentLineIndex) {
      errorMsg.value = "播放失败";
      SmartDialog.showToast("播放失败:$error");
    } else {
      //currentLineIndex += 1;
      //setPlayer();
      changePlayLine(currentLineIndex + 1);
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
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
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
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: Obx(
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
      ),
    );
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
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
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: "切换线路",
      child: ListView.builder(
        itemCount: playUrls.length,
        itemBuilder: (_, i) {
          return RadioListTile(
            value: i,
            groupValue: currentLineIndex,
            title: Text("线路${i + 1}"),
            secondary: Text(
              playUrls[i].contains(".flv") ? "FLV" : "HLS",
            ),
            onChanged: (e) {
              Get.back();
              //currentLineIndex = i;
              //setPlayer();
              changePlayLine(i);
            },
          );
        },
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      title: "画面尺寸",
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsV12,
          children: [
            RadioListTile(
              value: 0,
              title: const Text("适应"),
              visualDensity: VisualDensity.compact,
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 0);
              },
            ),
            RadioListTile(
              value: 1,
              title: const Text("拉伸"),
              visualDensity: VisualDensity.compact,
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 1);
              },
            ),
            RadioListTile(
              value: 2,
              title: const Text("铺满"),
              visualDensity: VisualDensity.compact,
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 2);
              },
            ),
            RadioListTile(
              value: 3,
              title: const Text("16:9"),
              visualDensity: VisualDensity.compact,
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 3);
              },
            ),
            RadioListTile(
              value: 4,
              title: const Text("4:3"),
              visualDensity: VisualDensity.compact,
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 4);
              },
            ),
          ],
        ),
      ),
    );
  }

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == "bilibili") {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == "douyin") {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://www.douyu.com/${args.webRid}";
    } else if (site.id == "huya") {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site.id == "douyu") {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void onClose() {
    autoExitTimer?.cancel();

    liveDanmaku.stop();
    danmakuController = null;
    super.onClose();
  }
}
