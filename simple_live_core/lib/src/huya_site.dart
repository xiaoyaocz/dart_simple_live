import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/danmaku/huya_danmaku.dart';
import 'package:simple_live_core/src/interface/live_danmaku.dart';
import 'package:simple_live_core/src/interface/live_site.dart';
import 'package:simple_live_core/src/model/live_anchor_item.dart';
import 'package:simple_live_core/src/model/live_category.dart';
import 'package:simple_live_core/src/model/live_message.dart';
import 'package:simple_live_core/src/model/live_room_item.dart';
import 'package:simple_live_core/src/model/live_search_result.dart';
import 'package:simple_live_core/src/model/live_room_detail.dart';
import 'package:simple_live_core/src/model/live_play_quality.dart';
import 'package:simple_live_core/src/model/live_category_result.dart';
import 'package:crypto/crypto.dart';

class HuyaSite implements LiveSite {
  @override
  String id = "huya";

  @override
  String name = "虎牙直播";

  @override
  LiveDanmaku getDanmaku() => HuyaDanmaku();

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "网游", children: []),
      LiveCategory(id: "2", name: "单机", children: []),
      LiveCategory(id: "8", name: "娱乐", children: []),
      LiveCategory(id: "3", name: "手游", children: []),
    ];

    for (var item in categories) {
      var items = await getSubCategores(item.id);
      item.children.addAll(items);
    }
    return categories;
  }

  Future<List<LiveSubCategory>> getSubCategores(String id) async {
    var result = await HttpClient.instance.getJson(
      "https://live.cdn.huya.com/liveconfig/game/bussLive",
      queryParameters: {
        "bussType": id,
      },
    );

    List<LiveSubCategory> subs = [];
    for (var item in result["data"]) {
      var gid = (asT<double?>(item["gid"])?.toInt() ?? 0).toString();
      var subCategory = LiveSubCategory(
        id: gid,
        name: item["gameFullName"].toString(),
        parentId: id,
        pic: "https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg",
      );
      subs.add(subCategory);
    }

    return subs;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://www.huya.com/cache.php",
      queryParameters: {
        "m": "LiveList",
        "do": "getLiveListByPage",
        "tagAll": 0,
        "gameId": category.id,
        "page": page
      },
    );
    var result = json.decode(resultText);
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }

      var roomItem = LiveRoomItem(
        roomId: item["profileRoom"].toString(),
        title: title,
        cover: cover,
        userName: item["nick"].toString(),
        online: int.tryParse(item["totalCount"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["page"] < result["data"]["totalPage"];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoomDetail detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    var urlData = detail.data as HuyaUrlDataModel;
    if (urlData.bitRates.isEmpty) {
      urlData.bitRates = [
        HuyaBitRateModel(
          name: "原画",
          bitRate: 0,
        ),
        HuyaBitRateModel(name: "高清", bitRate: 2000),
      ];
    }
    // if (urlData.lines.isEmpty) {
    //   urlData.lines = [
    //     HuyaLineModel(line: "tx.flv.huya.com", lineType: HuyaLineType.flv,),
    //     HuyaLineModel(line: "bd.flv.huya.com", lineType: HuyaLineType.flv),
    //     HuyaLineModel(line: "al.flv.huya.com", lineType: HuyaLineType.flv),
    //     HuyaLineModel(line: "hw.flv.huya.com", lineType: HuyaLineType.flv),
    //   ];
    // }
    //var url = getRealUrl(urlData.url);

    for (var item in urlData.bitRates) {
      var urls = <String>[];
      for (var line in urlData.lines) {
        var src = line.line;
        src += "/${line.streamName}";
        if (line.lineType == HuyaLineType.flv) {
          //src = src.replaceAll(".m3u8", ".flv");
          src += ".flv";
        }
        if (line.lineType == HuyaLineType.hls) {
          src += ".m3u8";
        }
        var parms = processAnticode(
          line.lineType == HuyaLineType.flv
              ? line.flvAntiCode
              : line.hlsAntiCode,
          urlData.uid,
          line.streamName,
        );
        src += "?$parms";
        if (item.bitRate > 0) {
          src += "&ratio=${item.bitRate}";
        }
        urls.add(src);
      }
      qualities.add(LivePlayQuality(
        data: urls,
        quality: item.name,
      ));
    }

    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    return quality.data as List<String>;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://www.huya.com/cache.php",
      queryParameters: {
        "m": "LiveList",
        "do": "getLiveListByPage",
        "tagAll": 0,
        "page": page
      },
    );
    var result = json.decode(resultText);
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }

      var roomItem = LiveRoomItem(
        roomId: item["profileRoom"].toString(),
        title: title,
        cover: cover,
        userName: item["nick"].toString(),
        online: int.tryParse(item["totalCount"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["page"] < result["data"]["totalPage"];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var resultText = await HttpClient.instance
        .getText("https://m.huya.com/$roomId", queryParameters: {}, header: {
      "user-agent":
          "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69",
    });
    var text = RegExp(r"window\.HNF_GLOBAL_INIT.=.\{(.*?)\}.</script>",
            multiLine: false)
        .firstMatch(resultText)
        ?.group(1);
    var jsonObj = json.decode("{$text}");
    var title =
        jsonObj["roomInfo"]["tLiveInfo"]["sIntroduction"]?.toString() ?? "";
    if (title.isEmpty) {
      title = jsonObj["roomInfo"]["tLiveInfo"]["sRoomName"]?.toString() ?? "";
    }
    var huyaLines = <HuyaLineModel>[];
    var huyaBiterates = <HuyaBitRateModel>[];
    //读取可用线路
    var lines = jsonObj["roomInfo"]["tLiveInfo"]["tLiveStreamInfo"]
        ["vStreamInfo"]["value"];
    for (var item in lines) {
      if ((item["sFlvUrl"]?.toString() ?? "").isNotEmpty) {
        huyaLines.add(HuyaLineModel(
          line: item["sFlvUrl"].toString(),
          lineType: HuyaLineType.flv,
          flvAntiCode: item["sFlvAntiCode"].toString(),
          hlsAntiCode: item["sHlsAntiCode"].toString(),
          streamName: item["sStreamName"].toString(),
        ));
      }
    }

    //清晰度
    var biterates = jsonObj["roomInfo"]["tLiveInfo"]["tLiveStreamInfo"]
        ["vBitRateInfo"]["value"];
    for (var item in biterates) {
      var name = item["sDisplayName"].toString();
      if (name.contains("HDR")) {
        continue;
      }
      huyaBiterates.add(HuyaBitRateModel(
        bitRate: item["iBitRate"],
        name: name,
      ));
    }

    var topSid = int.tryParse(
        RegExp(r'lChannelId":([0-9]+)').firstMatch(resultText)?.group(1) ??
            "0");
    var subSid = int.tryParse(
        RegExp(r'lSubChannelId":([0-9]+)').firstMatch(resultText)?.group(1) ??
            "0");
    var uid = await getAnonymousUid();
    return LiveRoomDetail(
        cover: jsonObj["roomInfo"]["tLiveInfo"]["sScreenshot"].toString(),
        online: jsonObj["roomInfo"]["tLiveInfo"]["lTotalCount"],
        roomId: jsonObj["roomInfo"]["tLiveInfo"]["lProfileRoom"].toString(),
        title: title,
        userName: jsonObj["roomInfo"]["tProfileInfo"]["sNick"].toString(),
        userAvatar:
            jsonObj["roomInfo"]["tProfileInfo"]["sAvatar180"].toString(),
        introduction:
            jsonObj["roomInfo"]["tLiveInfo"]["sIntroduction"].toString(),
        notice: jsonObj["welcomeText"].toString(),
        status: jsonObj["roomInfo"]["eLiveStatus"] == 2,
        data: HuyaUrlDataModel(
          url:
              "https:${utf8.decode(base64.decode(jsonObj["roomProfile"]["liveLineUrl"].toString()))}",
          lines: huyaLines,
          bitRates: huyaBiterates,
          uid: uid,
        ),
        danmakuData: HuyaDanmakuArgs(
          ayyuid: jsonObj["roomInfo"]["tLiveInfo"]["lYyid"] ?? 0,
          topSid: topSid ?? 0,
          subSid: subSid ?? 0,
        ),
        url: "https://www.huya.com/$roomId");
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword,
      {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 4,
        "typ": -5,
        "livestate": 0,
        "rows": 20,
        "start": (page - 1) * 20,
      },
    );
    var result = json.decode(resultText);
    var items = <LiveRoomItem>[];
    for (var item in result["response"]["3"]["docs"]) {
      var cover = item["game_screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }

      var title = item["game_introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["game_roomName"]?.toString() ?? "";
      }

      var roomItem = LiveRoomItem(
        roomId: item["room_id"].toString(),
        title: title,
        cover: cover,
        userName: item["game_nick"].toString(),
        online: int.tryParse(item["game_total_count"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["response"]["3"]["numFound"] > (page * 20);
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword,
      {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 1,
        "typ": -5,
        "livestate": 0,
        "rows": 20,
        "start": (page - 1) * 20,
      },
    );
    var result = json.decode(resultText);
    var items = <LiveAnchorItem>[];
    for (var item in result["response"]["1"]["docs"]) {
      var anchorItem = LiveAnchorItem(
        roomId: item["room_id"].toString(),
        avatar: item["game_avatarUrl180"].toString(),
        userName: item["game_nick"].toString(),
        liveStatus: item["gameLiveOn"],
      );
      items.add(anchorItem);
    }
    var hasMore = result["response"]["1"]["numFound"] > (page * 20);
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var resultText = await HttpClient.instance
        .getText("https://m.huya.com/$roomId", queryParameters: {}, header: {
      "user-agent":
          "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69",
    });
    var text = RegExp(r"window\.HNF_GLOBAL_INIT.=.\{(.*?)\}.</script>",
            multiLine: false)
        .firstMatch(resultText)
        ?.group(1);
    var jsonObj = json.decode("{$text}");
    return jsonObj["roomInfo"]["eLiveStatus"] == 2;
  }

  /// 匿名登录获取uid
  Future<String> getAnonymousUid() async {
    var result = await HttpClient.instance.postJson(
      "https://udblgn.huya.com/web/anonymousLogin",
      data: {
        "appId": 5002,
        "byPass": 3,
        "context": "",
        "version": "2.4",
        "data": {}
      },
      header: {
        "user-agent":
            "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69",
      },
    );
    return result["data"]["uid"].toString();
  }

  String getUUid() {
    var currentTime = DateTime.now().millisecondsSinceEpoch;
    var randomValue = Random().nextInt(4294967295);
    var result = (currentTime % 10000000000 * 1000 + randomValue) % 4294967295;
    return result.toString();
  }

  // String getRealUrl(String e) {
  //   //https://github.com/wbt5/real-url/blob/master/huya.py
  //   //使用ChatGPT转换的Dart代码,ChatGPT真好用
  //   List<String> iAndB = e.split('?');
  //   String i = iAndB[0];
  //   String b = iAndB[1];
  //   List<String> r = i.split('/');
  //   String s = r[r.length - 1].replaceAll(RegExp(r'.(flv|m3u8)'), '');
  //   List<String> bs = b.split('&');
  //   List<String> c = [];
  //   c.addAll(bs.take(3));
  //   c.add(bs.skip(3).join("&"));
  //   Map<String, String> n = {};
  //   for (var str in c) {
  //     List<String> keyValue = str.split('=');
  //     n[keyValue[0]] = keyValue[1];
  //   }
  //   String fm = Uri.decodeFull(n['fm'] ?? "").split("&")[0];
  //   String u = utf8.decode(base64Decode(fm));
  //   String p = u.split('_')[0];
  //   String f = (DateTime.now().millisecondsSinceEpoch * 1000).toString();
  //   String l = n['wsTime'] ?? "";
  //   String t = '0';
  //   String h = [p, t, s, f, l].join("_");
  //   String m = md5.convert(utf8.encode(h)).toString();
  //   String y = c[c.length - 1];
  //   String url = "$i?wsSecret=$m&wsTime=$l&u=$t&seqid=$f&$y";
  //   url = url.replaceAll("&ctype=tars_mobile", "");
  //   url = url.replaceAll(RegExp(r"ratio=\d+&"), "");
  //   url = url.replaceAll(RegExp(r"imgplus_\d+"), "imgplus");
  //   return url;
  // }

  String processAnticode(String anticode, String uid, String streamname) {
    // 来源：https://github.com/iceking2nd/real-url/blob/master/huya.py
    // 通过ChatGPT转换的Dart代码
    var q = Uri.splitQueryString(anticode);
    q["ver"] = "1";
    q["sv"] = "2110211124";
    q["seqid"] =
        (int.parse(uid) + (DateTime.now().millisecondsSinceEpoch)).toString();
    q["uid"] = uid;
    q["uuid"] = getUUid();

    var ss = md5
        .convert(utf8.encode("${q["seqid"]}|${q["ctype"]}|${q["t"]}"))
        .toString();

    q["fm"] = utf8
        .decode(base64.decode(q["fm"]!))
        .replaceAll("\$0", q["uid"]!)
        .replaceAll("\$1", streamname)
        .replaceAll("\$2", ss)
        .replaceAll("\$3", q["wsTime"]!);

    q["wsSecret"] = md5.convert(utf8.encode(q["fm"]!)).toString();

    q.remove("fm");
    if (q.containsKey("txyp")) {
      q.remove("txyp");
    }

    return Uri(queryParameters: q.map((x, y) => MapEntry(x, y))).query;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}

class HuyaUrlDataModel {
  final String url;
  final String uid;
  List<HuyaLineModel> lines;
  List<HuyaBitRateModel> bitRates;
  HuyaUrlDataModel({
    required this.bitRates,
    required this.lines,
    required this.url,
    required this.uid,
  });
}

enum HuyaLineType {
  flv,
  hls,
}

class HuyaLineModel {
  final String line;
  final String flvAntiCode;
  final String hlsAntiCode;
  final String streamName;
  final HuyaLineType lineType;

  HuyaLineModel({
    required this.line,
    required this.lineType,
    required this.flvAntiCode,
    required this.hlsAntiCode,
    required this.streamName,
  });
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;
  HuyaBitRateModel({
    required this.bitRate,
    required this.name,
  });
}
