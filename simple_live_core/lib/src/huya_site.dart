import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:crypto/crypto.dart';
import 'package:simple_live_core/src/model/tars/get_cdn_token_req.dart';
import 'package:simple_live_core/src/model/tars/get_cdn_token_resp.dart';
import 'package:tars_dart/tars/net/base_tars_http.dart';

class HuyaSite implements LiveSite {
  final String kUserAgent =
      "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36 Edg/117.0.0.0";
  final BaseTarsHttp tupClient = BaseTarsHttp("http://wup.huya.com", "liveui");
  String? playUserAgent;
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
      var gid = "";

      if (item["gid"] is Map) {
        gid = item["gid"]["value"].toString().split(",").first;
      } else if (item["gid"] is double) {
        gid = item["gid"].toInt().toString();
      } else if (item["gid"] is int) {
        gid = item["gid"].toString();
      } else {
        gid = item["gid"].toString();
      }

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
      // var urls = <String>[];
      // for (var line in urlData.lines) {
      //   var src = line.line;
      //   src += "/${line.streamName}";
      //   if (line.lineType == HuyaLineType.flv) {
      //     //src = src.replaceAll(".m3u8", ".flv");
      //     src += ".flv";
      //   }
      //   if (line.lineType == HuyaLineType.hls) {
      //     src += ".m3u8";
      //   }
      //   var parms = processAnticode(
      //     line.lineType == HuyaLineType.flv
      //         ? line.flvAntiCode
      //         : line.hlsAntiCode,
      //     urlData.uid,
      //     line.streamName,
      //   );
      //   src += "?$parms";
      //   if (item.bitRate > 0) {
      //     src += "&ratio=${item.bitRate}";
      //   }
      //   urls.add(src);
      // }

      qualities.add(LivePlayQuality(
        data: {
          "urls": urlData.lines,
          "bitRate": item.bitRate,
        },
        quality: item.name,
      ));
    }

    return Future.value(qualities);
  }

  // 每次访问播放虎牙都需要获取一次，不太合理，倾向于在客户端获取保存替换
  Future<String> getHuYaUA() async {
    if (playUserAgent != null) {
      return playUserAgent!;
    }
    try {
      var result = await HttpClient.instance.getJson(
        "https://github.iill.moe/xiaoyaocz/dart_simple_live/master/assets/play_config.json",
        queryParameters: {
          "ts": DateTime.now().millisecondsSinceEpoch,
        },
      );
      playUserAgent = json.decode(result)['huya']['user_agent'];
    } catch (e) {
      CoreLog.error(e);
    }
    return playUserAgent ??
        "HYSDK(Windows, 30000002)_APP(pc_exe&6080100&official)_SDK(trans&2.23.0.4969)";
  }

  @override
  Future<LivePlayUrl> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    var ls = <String>[];
    for (var element in quality.data["urls"]) {
      var line = element as HuyaLineModel;
      var url = await getPlayUrl(line, quality.data["bitRate"]);
      ls.add(url);
    }
    // from stream-rec url:https://github.com/stream-rec/stream-rec
    var ua = await getHuYaUA();
    return LivePlayUrl(
      urls: ls,
      headers: {"user-agent": ua},
    );
  }

  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    var req = GetCdnTokenReq();
    req.cdnType = line.cdnType;
    req.streamName = line.streamName;
    var resp =
        await tupClient.tupRequest("getCdnTokenInfo", req, GetCdnTokenResp());
    var url =
        '${line.line}/${resp.streamName}.flv?${resp.flvAntiCode}&codec=264';
    if (bitRate > 0) {
      url += "&ratio=$bitRate";
    }
    return url;
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
    var roomInfo = await _getRoomInfo(roomId);
    var tLiveInfo = roomInfo["roomInfo"]["tLiveInfo"];
    var tProfileInfo = roomInfo["roomInfo"]["tProfileInfo"];

    var title = tLiveInfo["sIntroduction"]?.toString() ?? "";
    if (title.isEmpty) {
      title = tLiveInfo["sRoomName"]?.toString() ?? "";
    }
    var huyaLines = <HuyaLineModel>[];
    var huyaBiterates = <HuyaBitRateModel>[];
    //读取可用线路
    var lines = tLiveInfo["tLiveStreamInfo"]["vStreamInfo"]["value"];
    for (var item in lines) {
      if ((item["sFlvUrl"]?.toString() ?? "").isNotEmpty) {
        huyaLines.add(HuyaLineModel(
          line: item["sFlvUrl"].toString(),
          lineType: HuyaLineType.flv,
          flvAntiCode: item["sFlvAntiCode"].toString(),
          hlsAntiCode: item["sHlsAntiCode"].toString(),
          streamName: item["sStreamName"].toString(),
          cdnType: item["sCdnType"].toString(),
        ));
      }
    }

    //清晰度
    var biterates = tLiveInfo["tLiveStreamInfo"]["vBitRateInfo"]["value"];
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

    var topSid = roomInfo["topSid"];
    var subSid = roomInfo["subSid"];

    return LiveRoomDetail(
      cover: tLiveInfo["sScreenshot"].toString(),
      online: tLiveInfo["lTotalCount"],
      roomId: tLiveInfo["lProfileRoom"].toString(),
      title: title,
      userName: tProfileInfo["sNick"].toString(),
      userAvatar: tProfileInfo["sAvatar180"].toString(),
      introduction: tLiveInfo["sIntroduction"].toString(),
      notice: roomInfo["welcomeText"].toString(),
      status: roomInfo["roomInfo"]["eLiveStatus"] == 2,
      data: HuyaUrlDataModel(
        url:
            "https:${utf8.decode(base64.decode(roomInfo["roomProfile"]["liveLineUrl"].toString()))}",
        lines: huyaLines,
        bitRates: huyaBiterates,
        uid: getUid(t: 13, e: 10),
      ),
      danmakuData: HuyaDanmakuArgs(
        ayyuid: tLiveInfo["lYyid"] ?? 0,
        topSid: topSid ?? 0,
        subSid: subSid ?? 0,
      ),
      url: "https://www.huya.com/$roomId",
    );
  }

  Future<Map> _getRoomInfo(String roomId) async {
    var resultText = await HttpClient.instance.getText(
      "https://m.huya.com/$roomId",
      queryParameters: {},
      header: {
        "user-agent": kUserAgent,
      },
    );
    var text = RegExp(
            r"window\.HNF_GLOBAL_INIT.=.\{[\s\S]*?\}[\s\S]*?</script>",
            multiLine: false)
        .firstMatch(resultText)
        ?.group(0);
    var jsonText = text!
        .replaceAll(RegExp(r"window\.HNF_GLOBAL_INIT.=."), '')
        .replaceAll("</script>", "")
        .replaceAllMapped(RegExp(r'function.*?\(.*?\).\{[\s\S]*?\}'), (match) {
      return '""';
    });

    var jsonObj = json.decode(jsonText);
    var topSid = int.tryParse(
        RegExp(r'lChannelId":([0-9]+)').firstMatch(resultText)?.group(1) ??
            "0");
    var subSid = int.tryParse(
        RegExp(r'lSubChannelId":([0-9]+)').firstMatch(resultText)?.group(1) ??
            "0");
    jsonObj["topSid"] = topSid;
    jsonObj["subSid"] = subSid;
    return jsonObj;
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
    var roomInfo = await _getRoomInfo(roomId);
    return roomInfo["roomInfo"]["eLiveStatus"] == 2;
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
        "user-agent": kUserAgent,
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

  String getUid({int? t, int? e}) {
    var n = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        .split("");
    var o = List.filled(36, '');
    if (t != null) {
      for (var i = 0; i < t; i++) {
        o[i] = n[Random().nextInt(e ?? n.length)];
      }
    } else {
      o[8] = o[13] = o[18] = o[23] = "-";
      o[14] = "4";
      for (var i = 0; i < 36; i++) {
        if (o[i].isEmpty) {
          var r = Random().nextInt(16);
          o[i] = n[19 == i ? 3 & r | 8 : r];
        }
      }
    }
    return o.join("");
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
    // https://github.com/SeaHOH/ykdl/blob/master/ykdl/extractors/huya/live.py
    // 通过ChatGPT转换的Dart代码
    var query = Uri.splitQueryString(anticode);

    query["t"] = "103";
    query["ctype"] = "tars_mobile";

    final wsTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600)
        .toRadixString(16);
    final seqId =
        (DateTime.now().millisecondsSinceEpoch + int.parse(uid)).toString();

    final fm = utf8.decode(base64.decode(Uri.decodeComponent(query['fm']!)));
    final wsSecretPrefix = fm.split('_').first;
    final wsSecretHash = md5
        .convert(utf8.encode('$seqId|${query["ctype"]}|${query["t"]}'))
        .toString();
    final wsSecret = md5
        .convert(utf8.encode(
            '${wsSecretPrefix}_${uid}_${streamname}_${wsSecretHash}_$wsTime'))
        .toString();

    return Uri(queryParameters: {
      "wsSecret": wsSecret,
      "wsTime": wsTime,
      "seqid": seqId,
      "ctype": query["ctype"]!,
      "ver": "1",
      "fs": query["fs"]!,
      // "sphdcdn": query["sphdcdn"] ?? "",
      // "sphdDC": query["sphdDC"] ?? "",
      // "sphd": query["sphd"] ?? "",
      // "exsphd": query["exsphd"] ?? "",
      "dMod": "mseh-0",
      "sdkPcdn": "1_1",
      "uid": uid,
      "uuid": getUUid(),
      "t": query["t"]!,
      "sv": "202411221719",
      "sdk_sid": "1732862566708",
      "a_block": "0"
    }).query;
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

  @override
  String toString() {
    return json.encode({
      "url": url,
      "uid": uid,
      "lines": lines.map((e) => e.toString()).toList(),
      "bitRates": bitRates.map((e) => e.toString()).toList(),
    });
  }
}

enum HuyaLineType {
  flv,
  hls,
}

class HuyaLineModel {
  final String line;
  final String cdnType;
  final String flvAntiCode;
  final String hlsAntiCode;
  final String streamName;
  final HuyaLineType lineType;
  int bitRate;

  HuyaLineModel({
    required this.line,
    required this.lineType,
    required this.flvAntiCode,
    required this.hlsAntiCode,
    required this.streamName,
    required this.cdnType,
    this.bitRate = 0,
  });

  @override
  String toString() {
    return json.encode({
      "line": line,
      "cdnType": cdnType,
      "flvAntiCode": flvAntiCode,
      "hlsAntiCode": hlsAntiCode,
      "streamName": streamName,
      "lineType": lineType.toString(),
    });
  }
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;

  HuyaBitRateModel({
    required this.bitRate,
    required this.name,
  });

  @override
  String toString() {
    return json.encode({
      "name": name,
      "bitRate": bitRate,
    });
  }
}
