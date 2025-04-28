import 'dart:io';

import 'package:simple_live_core/simple_live_core.dart';

void main(List<String> arguments) async {
  CoreLog.enableLog = false;
  if (arguments.isEmpty) {
    printHelp();
    return;
  }

  var action = arguments.first.toLowerCase().replaceAll("-", "");
  if (arguments.length < 2) {
    print("错误的参数");
    printHelp();
    return;
  }
  var url = arguments[1];
  if (url.isEmpty) {
    print("[URL]不能为空");
    printHelp();
    return;
  }
  if (action == "i") {
    await printInfo(url);
  } else if (action == "d") {
    printDanmaku(url);
  } else if (action == "h") {
    printHelp();
  } else {
    print("未知指令:$action");
    printHelp();
  }
}

void printHelp() {
  print("-i [URL] ：获取直播间信息及播放直链");
  print("-d [URL] ：持续输出直播间弹幕");
}

Future printInfo(String url) async {
  var urlInfo = parseUrl(url);
  LiveSite site = urlInfo.first;
  var id = urlInfo.last;
  var detail = await site.getRoomDetail(roomId: id);
  print("来源：${site.name}");
  print("房间号：${detail.roomId}");
  print("房间标题：${detail.title}");
  print("直播用户：${detail.userName}");
  print("人气值：${detail.online}");
  print("状态：${(detail.status ? "直播中" : "未开播")}");
  if (detail.status) {
    print("可用清晰度：");
    var quality = await site.getPlayQualites(detail: detail);

    for (int i = 0; i < quality.length; i++) {
      print("【${i + 1}】${quality[i].quality}");
    }
    print("请输入【】内数字，获取对应清晰度的直链");
    var input = stdin.readLineSync() ?? "";
    print("正在获取直链...");
    var index = int.tryParse(input) ?? 0;
    if (index > 0) {
      var url =
          await site.getPlayUrls(detail: detail, quality: quality[index - 1]);
      for (int i = 0; i < url.urls.length; i++) {
        print("线路${i + 1}:\r\n${url.urls[i]}");
      }
    }
  }
}

Future printDanmaku(String url) async {
  var urlInfo = parseUrl(url);
  LiveSite site = urlInfo.first;
  var id = urlInfo.last;
  var detail = await site.getRoomDetail(roomId: id);
  print("来源：${site.name}");
  print("房间号：${detail.roomId}");
  print("房间标题：${detail.title}");
  print("直播用户：${detail.userName}");
  print("状态：${(detail.status ? "直播中" : "未开播")}");
  var danmaku = site.getDanmaku();
  danmaku.onMessage = (LiveMessage e) {
    if (e.type == LiveMessageType.online) {
      print("-----人气值：${e.data}-----");
    } else if (e.type == LiveMessageType.chat) {
      print("${e.userName}：${e.message}");
    }
  };
  danmaku.onClose = (String e) {
    print(e);
  };

  print("【开始获取弹幕】");
  await danmaku.start(detail.danmakuData);
  await Future(() {});
}

List parseUrl(String url) {
  if (url.contains("bilibili.com")) {
    var id =
        RegExp(r"bilibili\.com/([\d|\w]+)").firstMatch(url)?.group(1) ?? "";
    return [BiliBiliSite(), id];
  }
  if (url.contains("huya.com")) {
    var id = RegExp(r"huya\.com/([\d|\w]+)").firstMatch(url)?.group(1) ?? "";
    return [HuyaSite(), id];
  }
  if (url.contains("douyu.com")) {
    var id = RegExp(r"douyu\.com/([\d|\w]+)").firstMatch(url)?.group(1) ?? "";
    return [DouyuSite(), id];
  }
  if (url.contains("live.douyin.com")) {
    var id =
        RegExp(r"live\.douyin\.com/([\d|\w]+)").firstMatch(url)?.group(1) ?? "";
    return [DouyinSite(), id];
  }
  throw Exception("链接解析失败");
}
