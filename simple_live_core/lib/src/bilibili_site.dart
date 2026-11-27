import 'common/native_quality.dart';
import 'common/request_pool.dart';
import 'dart:convert';
import 'model/room_category_name.dart';

import 'package:crypto/crypto.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/danmaku/bilibili_danmaku.dart';
import 'package:simple_live_core/src/interface/live_danmaku.dart';
import 'package:simple_live_core/src/interface/live_site.dart';
import 'package:simple_live_core/src/model/live_anchor_item.dart';
import 'package:simple_live_core/src/model/live_category.dart';
import 'package:simple_live_core/src/model/live_message.dart';
import 'package:simple_live_core/src/model/live_play_url.dart';
import 'package:simple_live_core/src/model/live_room_item.dart';
import 'package:simple_live_core/src/model/live_search_result.dart';
import 'package:simple_live_core/src/model/live_room_detail.dart';
import 'package:simple_live_core/src/model/live_play_quality.dart';
import 'package:simple_live_core/src/model/live_category_result.dart';

class BiliBiliSite implements LiveSite {
  @override
  String id = "bilibili";

  @override
  String name = "哔哩哔哩直播";

  String cookie = "";
  int userId = 0;
  String _authRoomKey(String roomId) => jsonEncode([cookie, userId, roomId]);

  @override
  LiveDanmaku getDanmaku() => BiliBiliDanmaku();

  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0";
  static const String kDefaultReferer = "https://live.bilibili.com/";

  String buvid3 = "";
  String buvid4 = "";
  String accessId = "";
  Future<Map<String, String>> getHeader() async {
    if (buvid3.isEmpty) {
      var buvidInfo = await getBuvid();
      buvid3 = buvidInfo["b_3"] ?? "";
      buvid4 = buvidInfo["b_4"] ?? "";
    }
    return cookie.isEmpty
        ? {
            "user-agent": kDefaultUserAgent,
            "referer": kDefaultReferer,
            "cookie": 'buvid3=$buvid3;buvid4=$buvid4;',
          }
        : {
            "cookie": cookie.contains("buvid3")
                ? cookie
                : "$cookie;buvid3=$buvid3;buvid4=$buvid4;",
            "user-agent": kDefaultUserAgent,
            "referer": kDefaultReferer,
          };
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/room/v1/Area/getList",
      queryParameters: {"need_entrance": 1, "parent_id": 0},
      header: await getHeader(),
    );
    for (var item in result["data"]) {
      List<LiveSubCategory> subs = [];
      for (var subItem in item["list"]) {
        var subCategory = LiveSubCategory(
          id: subItem["id"].toString(),
          name: asT<String?>(subItem["name"]) ?? "",
          parentId: asT<String?>(subItem["parent_id"]) ?? "",
          pic: "${asT<String?>(subItem["pic"]) ?? ""}@100w.png",
        );
        subs.add(subCategory);
      }
      var category = LiveCategory(
        children: subs,
        id: item["id"].toString(),
        name: asT<String?>(item["name"]) ?? "",
      );
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    const baseUrl =
        "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList";

    var url =
        "$baseUrl?platform=web&parent_area_id=${category.parentId}&area_id=${category.id}&sort_type=&page=$page&w_webid=${await getAccessId()}";

    var queryParams = await getWbiSign(url);

    var result = await HttpClient.instance.getJson(
      baseUrl,
      queryParameters: queryParams,
      header: await getHeader(),
    );

    var hasMore = result["data"]["has_more"] == 1;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoomItem(
        roomId: item["roomid"].toString(),
        title: item["title"].toString(),
        cover: "${item["cover"]}@400w.jpg",
        userName: item["uname"].toString(),
        online: int.tryParse(item["online"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
    List<LivePlayQuality> qualities = [];
    final accountRoom = _authRoomKey(detail.roomId);
    var result = await _takePlayInfo(detail.roomId);
    var qualitiesMap = <int, String>{};
    final frameRates = <int, double?>{};
    for (var item in result["data"]["playurl_info"]["playurl"]["g_qn_desc"]) {
      frameRates[int.tryParse(item["qn"].toString()) ?? 0] = metadataFrameRate(item);
      qualitiesMap[int.tryParse(item["qn"].toString()) ?? 0] =
          item["desc"].toString();
    }

    final acceptQn = <int>{};
    for (final streamItem
        in (result["data"]["playurl_info"]["playurl"]["stream"] as List? ??
            const [])) {
      for (final formatItem in (streamItem["format"] as List? ?? const [])) {
        for (final codecItem in (formatItem["codec"] as List? ?? const [])) {
          for (final qn in (codecItem["accept_qn"] as List? ?? const [])) {
            final parsed = int.tryParse('$qn');
            if (parsed != null) acceptQn.add(parsed);
          }
        }
      }
    }
    final sortedQn = acceptQn.toList()..sort((a, b) => b.compareTo(a));
    for (var item in sortedQn) {
      var qualityItem = LivePlayQuality(
        quality: qualitiesMap[item] ?? "未知清晰度",
        data: item,
        frameRate: frameRates[item],
      );
      qualities.add(qualityItem);
    }
    // 同一次响应里已经带回了某个清晰度的直链，先存着，
    // 选中的清晰度与它一致时省掉一次完全相同的请求。
    if (accountRoom == _authRoomKey(detail.roomId)) {
      _cachePlayUrl(
        detail.roomId,
        result["data"]["playurl_info"]["playurl"],
      );
    }
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) => _playUrlRequests.run(
    jsonEncode([cookie, userId, detail.roomId, quality.data]),
    () => _loadPlayUrls(detail, quality),
  );

  final _playUrlRequests = InFlightRequests<LivePlayUrl>();

  Future<LivePlayUrl> _loadPlayUrls(
    LiveRoomDetail detail,
    LivePlayQuality quality,
  ) async {
    final cached = _takeCachedPlayUrl(detail.roomId, quality.data);
    if (cached != null) return cached;
    var result = await _fetchPlayInfo(detail.roomId, qn: quality.data);
    return _parsePlayUrls(
      result["data"]["playurl_info"]["playurl"],
      quality: int.tryParse('${quality.data}'),
    );
  }

  final _playInfoPrefetch = PrefetchRequests<dynamic>();

  /// 清晰度接口只认 roomId，可以在等房间详情的同时先发出去。
  @override
  void prefetchRoom(String roomId) {
    _playInfoPrefetch.prefetch(_authRoomKey(roomId), () => _fetchPlayInfo(roomId));
  }

  Future<dynamic> _takePlayInfo(String roomId) =>
      _playInfoPrefetch.take(_authRoomKey(roomId), () => _fetchPlayInfo(roomId));

  Future<dynamic> _fetchPlayInfo(String roomId, {Object? qn}) async {
    return HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
      queryParameters: {
        "room_id": roomId,
        "protocol": "0,1",
        "format": "0,1,2",
        "codec": "0,1",
        "platform": "web",
        "dolby": "5",
        "panorama": "1",
        if (qn != null) "qn": qn,
      },
      header: await getHeader(),
    );
  }

  /// 缓存有效期。直播直链本身带时效，缓存只用于抹掉同一次开播里的重复请求。
  static const _cachedPlayUrlTtl = Duration(seconds: 30);
  final _cachedPlayUrls = <String, (int, LivePlayUrl, DateTime)>{};

  static const _playHeaders = {
    "referer": "https://live.bilibili.com",
    "user-agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.188",
  };

  LivePlayUrl _parsePlayUrls(Map playurl, {required int? quality}) {
    final urlsByQuality = <int?, List<String>>{};
    for (var streamItem in playurl["stream"]) {
      var formatList = streamItem["format"];
      for (var formatItem in formatList) {
        var codecList = [...formatItem["codec"]]
          ..sort(
            (a, b) => (a["codec_name"] == "avc" ? 0 : 1).compareTo(
              b["codec_name"] == "avc" ? 0 : 1,
            ),
          );
        for (var codecItem in codecList) {
          var urlList = codecItem["url_info"];
          var baseUrl = codecItem["base_url"].toString();
          final currentQn = int.tryParse('${codecItem["current_qn"]}');
          for (var urlItem in urlList) {
            final url = "${urlItem["host"]}$baseUrl${urlItem["extra"]}";
            (urlsByQuality[currentQn] ??= []).add(url);
          }
        }
      }
    }
    final available = urlsByQuality.keys.whereType<int>().toList()..sort();
    final delivered = available.isEmpty
        ? null
        : available.lastWhere(
            (qn) => quality == null || qn <= quality,
            orElse: () => available.first,
          );
    final urls = (urlsByQuality[delivered] ?? []).toSet();
    String? actualQuality;
    if (delivered != null) {
      for (final entry in playurl["g_qn_desc"] ?? const []) {
        if (int.tryParse('${entry["qn"]}') == delivered) {
          actualQuality = entry["desc"]?.toString();
          break;
        }
      }
      if ((actualQuality?.isNotEmpty != true) && delivered != quality) {
        actualQuality = '清晰度 $delivered';
      }
    }
    // 保留接口给出的线路顺序，并将 mcdn 放在备用位置。
    return LivePlayUrl(
      urls: [
        ...urls.where((url) => !url.contains("mcdn")),
        ...urls.where((url) => url.contains("mcdn")),
      ],
      headers: _playHeaders,
      actualQuality: actualQuality,
    );
  }

  void _cachePlayUrl(String roomId, dynamic playurl) {
    try {
      int? qn;
      for (final streamItem in (playurl["stream"] as List? ?? const [])) {
        for (final formatItem in (streamItem["format"] as List? ?? const [])) {
          for (final codecItem in (formatItem["codec"] as List? ?? const [])) {
            final current = int.tryParse('${codecItem["current_qn"]}');
            if (current != null && (qn == null || current > qn)) {
              qn = current;
            }
          }
        }
      }
      if (qn == null) return;
      final playUrl = _parsePlayUrls(playurl, quality: qn);
      if (playUrl.urls.isEmpty) return;
      if (_cachedPlayUrls.length >= 8) {
        _cachedPlayUrls.remove(_cachedPlayUrls.keys.first);
      }
      _cachedPlayUrls[_authRoomKey(roomId)] = (qn, playUrl, DateTime.now());
    } catch (_) {
      // 响应结构不符预期就不缓存，下次照常单独请求。
    }
  }

  LivePlayUrl? _takeCachedPlayUrl(String roomId, Object? qualityData) {
    final key = _authRoomKey(roomId);
    final cached = _cachedPlayUrls[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.$3) > _cachedPlayUrlTtl) {
      _cachedPlayUrls.remove(key);
      return null;
    }
    if (int.tryParse("$qualityData") != cached.$1) return null;
    _cachedPlayUrls.remove(key);
    return cached.$2;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    const baseUrl =
        "https://api.live.bilibili.com/xlive/web-interface/v1/second/getListByArea";
    var url = "$baseUrl?platform=web&sort=online&page_size=30&page=$page";

    var queryParams = await getWbiSign(url);

    var result = await HttpClient.instance.getJson(
      baseUrl,
      queryParameters: queryParams,
      header: await getHeader(),
    );

    var hasMore = (result["data"]["list"] as List).isNotEmpty;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["list"]) {
      var roomItem = LiveRoomItem(
        roomId: item["roomid"].toString(),
        title: item["title"].toString(),
        cover: "${item["cover"]}@400w.jpg",
        userName: item["uname"].toString(),
        online: int.tryParse(item["online"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) =>
      _roomRequests.run(_authRoomKey(roomId), () => _loadRoomDetail(roomId));

  final _roomRequests = InFlightRequests<LiveRoomDetail>();

  @override
  Future<LiveRoomDetail> refreshRoomDetail({required String roomId}) {
    _roomRequests.invalidate(_authRoomKey(roomId));
    return getRoomDetail(roomId: roomId);
  }

  Future<LiveRoomDetail> _loadRoomDetail(String roomId) async {
    var roomInfo = await getRoomInfo(roomId: roomId);
    var realRoomId = roomInfo["room_info"]["room_id"].toString();
    final status = int.tryParse(
      roomInfo['room_info']['live_status']?.toString() ?? '',
    );
    if (status == null) throw StateError('B站房间未返回直播状态');
    if (status != 1) {
      // The room API is authoritative; an offline room needs no chat token.
      final anchor = roomInfo['anchor_info']?['base_info'];
      return LiveRoomDetail(
        roomId: realRoomId,
        status: false,
        online: 0,
        title: roomInfo['room_info']['title']?.toString() ?? '',
        cover: roomInfo['room_info']['cover']?.toString() ?? '',
        userName: anchor?['uname']?.toString() ?? '',
        userAvatar: anchor?['face']?.toString() ?? '',
        url: 'https://live.bilibili.com/$roomId',
        categoryId: roomInfo['room_info']['area_id']?.toString(),
        categoryName: firstCategoryName([
          roomInfo['room_info']['second_area_name'],
          roomInfo['room_info']['area_name'],
          roomInfo['room_info']['parent_area_name'],
        ]),
      );
    }

    const danmuInfoBaseUrl =
        "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo";
    var danmuInfoUrl = "$danmuInfoBaseUrl?id=$realRoomId";
    var queryParams = await getWbiSign(danmuInfoUrl);
    var roomDanmakuResult = await HttpClient.instance.getJson(
      danmuInfoBaseUrl,
      queryParameters: queryParams,
      header: await getHeader(),
    );
    List<String> serverHosts = (roomDanmakuResult["data"]["host_list"] as List)
        .map<String>((e) => e["host"].toString())
        .toList();

    //var buvid = await getBuvid();
    // 从 roomInfo 中提取 live_start_time
    String? liveStartTime =
        roomInfo["room_info"]?["live_start_time"]?.toString();

    // 计算开播时长并打印到控制台 (参考斗鱼的实现)
    if (liveStartTime != null &&
        liveStartTime.isNotEmpty &&
        liveStartTime != "0") {
      // 检查是否为0，0可能表示未开播或无此信息
      try {
        int startTimeStamp = int.parse(liveStartTime);
        int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        int durationInSeconds = currentTimeStamp - startTimeStamp;

        int hours = durationInSeconds ~/ 3600;
        int minutes = (durationInSeconds % 3600) ~/ 60;
        int seconds = durationInSeconds % 60;

        String formattedDuration =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        print('Bilibili直播间 $roomId 开播时长: $formattedDuration');
      } catch (e) {
        print('计算 Bilibili 开播时长出错: $e');
      }
    }

    return LiveRoomDetail(
      roomId: realRoomId,
      title: roomInfo["room_info"]["title"].toString(),
      cover: roomInfo["room_info"]["cover"].toString(),
      userName: roomInfo["anchor_info"]["base_info"]["uname"].toString(),
      userAvatar: "${roomInfo["anchor_info"]["base_info"]["face"]}@100w.jpg",
      online: asT<int?>(roomInfo["room_info"]["online"]) ?? 0,
      status: (asT<int?>(roomInfo["room_info"]["live_status"]) ?? 0) == 1,
      url: "https://live.bilibili.com/$roomId",
      introduction: roomInfo["room_info"]["description"].toString(),
      notice: "",
      danmakuData: BiliBiliDanmakuArgs(
        roomId: int.tryParse(realRoomId) ?? 0,
        uid: userId,
        token: roomDanmakuResult["data"]["token"].toString(),
        serverHost: serverHosts.isNotEmpty
            ? serverHosts.first
            : "broadcastlv.chat.bilibili.com",
        buvid: buvid3,
        cookie: cookie,
      ),
      showTime: liveStartTime, // 将 liveStartTime 赋值给 showTime 字段
      categoryId: roomInfo["room_info"]["area_id"]?.toString(),
      categoryName: firstCategoryName([
        roomInfo['room_info']['second_area_name'],
        roomInfo['room_info']['area_name'],
        roomInfo['room_info']['parent_area_name'],
      ]),
    );
  }

  Future<Map<String, dynamic>> getRoomInfo({required String roomId}) async {
    var url =
        "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom?room_id=$roomId";
    var queryParams = await getWbiSign(url);
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom",
      queryParameters: queryParams,
      header: await getHeader(),
    );
    print("【B站接口返回】roomId=$roomId, result=$result");
    return result["data"];
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page,
      },
      header: await getHeader(),
    );

    var items = <LiveRoomItem>[];
    for (var item in result["data"]["result"]["live_room"] ?? []) {
      var title = item["title"].toString();
      //移除title中的<em></em>标签
      title = title.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var roomItem = LiveRoomItem(
        roomId: item["roomid"].toString(),
        title: title,
        cover: "https:${item["cover"]}@400w.jpg",
        userName: item["uname"].toString(),
        online: int.tryParse(item["online"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: items.length >= 40, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live_user&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page,
      },
      header: await getHeader(),
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["result"] ?? []) {
      var uname = item["uname"].toString();
      //移除title中的<em></em>标签
      uname = uname.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var anchorItem = LiveAnchorItem(
        roomId: item["roomid"].toString(),
        avatar: "https:${item["uface"]}@400w.jpg",
        userName: uname,
        liveStatus: item["is_live"],
      );
      items.add(anchorItem);
    }
    return LiveSearchAnchorResult(hasMore: items.length >= 40, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/room/v1/Room/get_info",
      queryParameters: {"room_id": roomId},
      header: await getHeader(),
    );
    final status = int.tryParse('${result["data"]?["live_status"]}');
    if (status == null) throw StateError('B站房间未返回直播状态');
    return status == 1;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://api.live.bilibili.com/av/v1/SuperChat/getMessageList",
      queryParameters: {"room_id": roomId},
      header: await getHeader(),
    );
    List<LiveSuperChatMessage> ls = [];
    for (var item in result["data"]?["list"] ?? []) {
      var message = LiveSuperChatMessage(
        backgroundBottomColor: item["background_bottom_color"].toString(),
        backgroundColor: item["background_color"].toString(),
        endTime: DateTime.fromMillisecondsSinceEpoch(item["end_time"] * 1000),
        face: "${item["user_info"]["face"]}@200w.jpg",
        message: item["message"].toString(),
        price: item["price"],
        startTime: DateTime.fromMillisecondsSinceEpoch(
          item["start_time"] * 1000,
        ),
        userName: item["user_info"]["uname"].toString(),
      );
      ls.add(message);
    }
    return ls;
  }

  /// 获取 buvid3 和 buvid4
  /// 返回buvid3和buvid4
  /// ``` json
  /// {
  ///   "b_3": "buvid3",
  ///   "b_4": "buvid4",
  /// }
  /// ```
  Future<Map> getBuvid() async {
    try {
      if (cookie.contains("buvid3")) {
        return {
          "b_3": RegExp(r"buvid3=(.*?);").firstMatch(cookie)?.group(1) ?? "",
          "b_4": RegExp(r"buvid4=(.*?);").firstMatch(cookie)?.group(1) ?? "",
        };
      }

      var result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/frontend/finger/spi",
        queryParameters: {},
        header: {
          "user-agent": kDefaultUserAgent,
          "referer": kDefaultReferer,
          "cookie": cookie,
        },
      );
      return result["data"];
    } catch (e) {
      return {"b_3": "", "b_4": ""};
    }
  }

  static String kImgKey = '';
  static String kSubKey = '';
  static const List<int> mixinKeyEncTab = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];
  Future<(String, String)> getWbiKeys() async {
    if (kImgKey.isNotEmpty && kSubKey.isNotEmpty) {
      return (kImgKey, kSubKey);
    }
    // 获取最新的 img_key 和 sub_key
    var resp = await HttpClient.instance.getJson(
      'https://api.bilibili.com/x/web-interface/nav',
      header: await getHeader(),
    );

    var imgUrl = resp["data"]["wbi_img"]["img_url"].toString();
    var subUrl = resp["data"]["wbi_img"]["sub_url"].toString();
    var imgKey = imgUrl.substring(imgUrl.lastIndexOf('/') + 1).split('.').first;
    var subKey = subUrl.substring(subUrl.lastIndexOf('/') + 1).split('.').first;

    kImgKey = imgKey;
    kSubKey = subKey;

    return (imgKey, subKey);
  }

  String getMixinKey(String origin) {
    // 对 imgKey 和 subKey 进行字符顺序打乱编码
    return mixinKeyEncTab.fold("", (s, i) => s + origin[i]).substring(0, 32);
  }

  Future<Map<String, String>> getWbiSign(String url) async {
    var (imgKey, subKey) = await getWbiKeys();

    // 为请求参数进行 wbi 签名
    var mixinKey = getMixinKey(imgKey + subKey);
    var currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    var queryParams = Map<String, String>.from(Uri.parse(url).queryParameters);

    queryParams["wts"] = currentTime.toString(); // 添加 wts 字段

    //按照 key 重排参数
    Map<String, String> map = {};
    var sortedKeys = queryParams.keys.toList()..sort();
    for (var key in sortedKeys) {
      var value = queryParams[key]!;
      // 过滤 value 中的 "!'()*" 字符
      map[key] = value
          .toString()
          .split('')
          .where((c) => "!'()*".contains(c) == false)
          .join('');
    }

    var query = map.keys
        .map((key) => "$key=${Uri.encodeQueryComponent(map[key]!)}")
        .join("&");
    var wbiSign = md5.convert(utf8.encode("$query$mixinKey")).toString();
    queryParams["w_rid"] = wbiSign;
    return queryParams;
  }

  Future<String> getAccessId() async {
    if (accessId.isNotEmpty) {
      return accessId;
    }

    // 获取 access_id
    var resp = await HttpClient.instance.getText(
      "https://live.bilibili.com/lol",
      queryParameters: {},
      header: await getHeader(),
    );
    var id = RegExp(
      r'"access_id":"(.*?)"',
    ).firstMatch(resp)?.group(1)?.replaceAll("\\", "");
    accessId = id ?? "";
    return accessId;
  }
}
