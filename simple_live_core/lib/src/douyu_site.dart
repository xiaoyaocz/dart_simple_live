import 'common/native_quality.dart';
import 'common/core_error.dart';
import 'common/request_pool.dart';
import 'dart:async';
import 'dart:convert';
import 'model/room_category_name.dart';
import 'common/core_log.dart';
import 'dart:math';

import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/danmaku/douyu_danmaku.dart';
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
import 'package:html_unescape/html_unescape.dart';
import 'package:simple_live_core/src/scripts/douyu_sign.dart';

class DouyuSite implements LiveSite {
  @override
  String id = "douyu";

  @override
  String name = "斗鱼直播";

  @override
  LiveDanmaku getDanmaku() => DouyuDanmaku();

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson(
      "https://m.douyu.com/api/cate/list",
    );
    var subCateList = result["data"]["cate2Info"] as List;
    for (var item in result["data"]["cate1Info"]) {
      var cate1Id = item["cate1Id"];
      var cate1Name = item["cate1Name"];
      List<LiveSubCategory> subCategories = [];
      subCateList.where((x) => x["cate1Id"] == cate1Id).forEach((element) {
        subCategories.add(
          LiveSubCategory(
            pic: element["icon"],
            id: element["cate2Id"].toString(),
            parentId: cate1Id.toString(),
            name: element["cate2Name"].toString(),
          ),
        );
      });
      categories.add(
        LiveCategory(
          id: cate1Id.toString(),
          name: cate1Name.toString(),
          children: subCategories,
        ),
      );
    }
    // 根据ID排序
    categories.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/gapi/rkc/directory/mixList/2_${category.id}/$page",
      queryParameters: {},
    );

    var items = <LiveRoomItem>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoomItem(
        cover: item['rs16'].toString(),
        online: item['ol'],
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        userName: item['nn'].toString(),
      );
      items.add(roomItem);
    }
    var hasMore = page < result['data']['pgcnt'];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) => _qualityRequests.run(
    jsonEncode([detail.roomId, detail.data.toString()]),
    () => _loadPlayQualities(detail),
  );

  final _qualityRequests = InFlightRequests<List<LivePlayQuality>>();

  Future<List<LivePlayQuality>> _loadPlayQualities(LiveRoomDetail detail) async {
    var data = detail.data.toString();
    data += "&cdn=&rate=-1&ver=Douyu_223061205&iar=1&ive=1&hevc=0&fa=0";
    List<LivePlayQuality> qualities = [];
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/${detail.roomId}",
      data: data,
      formUrlEncoded: true,
    );

    var cdns = <String>[];
    for (var item in result["data"]["cdnsWithName"]) {
      cdns.add(item["cdn"].toString());
    }

    // 如果cdn以scdn开头，将其放到最后
    cdns.sort((a, b) {
      if (a.startsWith("scdn") && !b.startsWith("scdn")) {
        return 1;
      } else if (!a.startsWith("scdn") && b.startsWith("scdn")) {
        return -1;
      }
      return 0;
    });

    for (var item in result["data"]["multirates"]) {
      qualities.add(
        LivePlayQuality(
          quality: item["name"].toString(),
          data: DouyuPlayData(item["rate"], cdns),
          frameRate: metadataFrameRate(item),
        ),
      );
    }
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    var args = detail.data.toString();
    var data = quality.data as DouyuPlayData;

    final resolved = await Future.wait(
      data.cdns.map((item) async {
        try {
          return await getPlayUrl(detail.roomId, args, data.rate, item);
        } catch (e) {
          // 单条线路失败时继续读取其他线路。
          CoreLog.error(e);
          return '';
        }
      }),
    );
    final urls = resolved.where((url) => url.isNotEmpty).toSet().toList();
    return LivePlayUrl(urls: urls);
  }

  Future<String> getPlayUrl(
    String roomId,
    String args,
    int rate,
    String cdn,
  ) => _playUrlRequests.run(
    jsonEncode([roomId, args, rate, cdn]),
    () => _loadPlayUrl(roomId, args, rate, cdn),
  );

  final _playUrlRequests = InFlightRequests<String>();

  Future<String> _loadPlayUrl(
    String roomId,
    String args,
    int rate,
    String cdn,
  ) async {
    args += "&cdn=$cdn&rate=$rate";
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/$roomId",
      data: args,
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43",
      },
      formUrlEncoded: true,
    );

    var data = result["data"];
    if (data is! Map) return "";
    var host = data["rtmp_url"]?.toString() ?? "";
    var stream = data["rtmp_live"]?.toString() ?? "";
    if (host.isEmpty || stream.isEmpty) return "";
    var url = "$host/${HtmlUnescape().convert(stream)}";
    var uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != "https" && uri.scheme != "http")) {
      return "";
    }
    return url;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/weblist/apinc/allpage/6/$page",
      queryParameters: {},
    );

    if (result['error'] != 0 || result['data']?['rl'] is! List) {
      throw CoreError('斗鱼推荐接口未返回有效数据，请稍后刷新');
    }

    var items = <LiveRoomItem>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var roomItem = LiveRoomItem(
        cover: item['rs16'].toString(),
        online: item['ol'],
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        userName: item['nn'].toString(),
      );
      items.add(roomItem);
    }
    // The live endpoint can report pgcnt=0 while later pages still exist.
    // Only a positive page count is authoritative; otherwise use raw rows
    // (before filtering non-room cards) and stop on an empty upstream page.
    final pageCount = int.tryParse('${result['data']['pgcnt']}') ?? 0;
    final hasMore = pageCount > 0
        ? page < pageCount
        : (result['data']['rl'] as List).isNotEmpty;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  final _encPrefetch = PrefetchRequests<String>();
  final _h5Prefetch = PrefetchRequests<Map>();

  /// 取流加密串和 h5 房间信息都只依赖 roomId，进房时先和房间信息一起发出去。
  @override
  void prefetchRoom(String roomId) {
    _encPrefetch.prefetch(roomId, () => _fetchHomeH5Enc(roomId));
    _h5Prefetch.prefetch(roomId, () => _fetchH5Room(roomId));
  }

  Future<String> _takeHomeH5Enc(String roomId) =>
      _encPrefetch.take(roomId, () => _fetchHomeH5Enc(roomId));

  Future<Map> _takeH5Room(String roomId) =>
      _h5Prefetch.take(roomId, () => _fetchH5Room(roomId));

  Future<String> _fetchHomeH5Enc(String roomId) {
    return HttpClient.instance.getText(
      "https://www.douyu.com/swf_api/homeH5Enc?rids=$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43",
      },
    );
  }

  Future<Map> _fetchH5Room(String roomId) async {
    final result = await HttpClient.instance.getJson(
      "https://www.douyu.com/swf_api/h5room/$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      },
    );
    return result as Map;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) =>
      _roomRequests.run(roomId, () => _loadRoomDetail(roomId));

  final _roomRequests = InFlightRequests<LiveRoomDetail>();

  @override
  Future<LiveRoomDetail> refreshRoomDetail({required String roomId}) {
    _roomRequests.invalidate(roomId);
    return getRoomDetail(roomId: roomId);
  }

  Future<LiveRoomDetail> _loadRoomDetail(String roomId) async {
    Map roomInfo = await _getRoomInfo(roomId);
    final status = int.tryParse(roomInfo['show_status']?.toString() ?? '');
    if (status == null) throw StateError('斗鱼房间未返回直播状态');
    final replay = roomInfo['videoLoop']?.toString() == '1';
    if (status != 1 && !replay) {
      // No H5/signature requests after the primary API confirms offline.
      return LiveRoomDetail(
        roomId: roomInfo['room_id']?.toString() ?? roomId,
        title: roomInfo['room_name']?.toString() ?? '',
        cover: roomInfo['room_pic']?.toString() ?? '',
        userName: roomInfo['owner_name']?.toString() ?? '',
        userAvatar: roomInfo['owner_avatar']?.toString() ?? '',
        online: 0,
        status: false,
        url: 'https://www.douyu.com/$roomId',
        categoryId: roomInfo['cate_id']?.toString(),
        categoryName: firstCategoryName([
          roomInfo['cate2_name'],
          roomInfo['cate_name'],
          roomInfo['cate1_name'],
        ]),
      );
    }

    // 开播时间与取流加密串互不依赖，并发发出，少等一次往返。
    // A public URL may be a VIP alias. H5, signing and CDN APIs require rid.
    final realRoomId = roomInfo['room_id']?.toString() ?? roomId;
    final h5RoomRequest = _takeH5Room(realRoomId);
    final jsEncRequest = _takeHomeH5Enc(realRoomId);
    // 若 h5 请求先抛错，加密串请求的失败不应变成未捕获异常。
    jsEncRequest.catchError((Object _) => '');
    Map h5RoomInfo = await h5RoomRequest;
    String? showTime = h5RoomInfo["data"]?["show_time"]?.toString();
    var jsEncResult = await jsEncRequest;
    dynamic signing;
    try {
      signing = jsonDecode(jsEncResult);
    } on FormatException {
      throw CoreError('斗鱼播放签名返回异常，请刷新重试');
    }
    final crptext = signing is Map && signing['data'] is Map
        ? signing['data']['room$realRoomId']
        : null;
    if (crptext is! String || crptext.isEmpty) {
      throw CoreError('斗鱼未返回播放签名，请刷新重试');
    }

    if (showTime != null && showTime.isNotEmpty) {
      try {
        int startTimeStamp = int.parse(showTime);
        int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        int durationInSeconds = currentTimeStamp - startTimeStamp;

        int hours = durationInSeconds ~/ 3600;
        int minutes = (durationInSeconds % 3600) ~/ 60;
        int seconds = durationInSeconds % 60;

        String formattedDuration =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        print('斗鱼直播间 $roomId 开播时长: $formattedDuration');
      } catch (e) {
        print('计算开播时长出错: $e');
      }
    }

    return LiveRoomDetail(
      cover: roomInfo["room_pic"].toString(),
      online: int.tryParse(roomInfo["room_biz_all"]["hot"].toString()) ?? 0,
      roomId: roomInfo["room_id"].toString(),
      title: roomInfo["room_name"].toString(),
      userName: roomInfo["owner_name"].toString(),
      userAvatar: roomInfo["owner_avatar"].toString(),
      introduction: roomInfo["show_details"].toString(),
      notice: "",
      status: status == 1 && !replay,
      danmakuData: roomInfo["room_id"].toString(),
      data: DouyuSign.getSign(crptext, roomInfo["room_id"].toString()),
      url: "https://www.douyu.com/$roomId",
      isRecord: replay,
      showTime: showTime,
      categoryId: roomInfo["cate_id"]?.toString(),
      categoryName: firstCategoryName([
        roomInfo['cate2_name'], h5RoomInfo['data']?['cate2_name'],
        roomInfo['cate_name'], h5RoomInfo['data']?['cate_name'],
        roomInfo['cate1_name'], h5RoomInfo['data']?['cate1_name'],
      ]),
    );
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    var did = generateRandomString(32);
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchShow",
      queryParameters: {"kw": keyword, "page": page, "pageSize": 20},
      header: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
        'Cookie': 'dy_did=$did;acf_did=$did',
      },
    );
    if (result['error'] != 0) {
      throw Exception(result['msg']);
    }
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["relateShow"]) {
      var roomItem = LiveRoomItem(
        roomId: item["rid"].toString(),
        title: item["roomName"].toString(),
        cover: item["roomSrc"].toString(),
        userName: item["nickName"].toString(),
        online: parseHotNum(item["hot"].toString()),
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["relateShow"].isNotEmpty;
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
  }

  Future<Map> _getRoomInfo(String roomId) async {
    final direct = await _getBetardRoomInfo(roomId);
    if (direct != null) return direct;

    // /betard/<VIP alias> can return a 200 HTML "room closed" page even
    // though the anchor is live. Resolve the public alias from official H5
    // page data, then query the numeric room exactly once (no recursion).
    final html = await HttpClient.instance.getText(
      'https://m.douyu.com/${Uri.encodeComponent(roomId)}',
      header: {'Referer': 'https://m.douyu.com/'},
    );
    final match = RegExp(
      r'''<script\b[^>]*\bid=["']vike_pageContext["'][^>]*>([\s\S]*?)</script>''',
    ).firstMatch(html);
    String? realRoomId;
    if (match != null) {
      try {
        final context = jsonDecode(match.group(1)!);
        final info = context is Map ? context['pageProps'] : null;
        final room = info is Map ? info['room'] : null;
        final details = room is Map ? room['roomInfo'] : null;
        final metadata = details is Map ? details['roomInfo'] : null;
        if (metadata is Map) realRoomId = metadata['rid']?.toString();
      } on FormatException {
        // A changed/error page is not room metadata.
      }
    }
    if (realRoomId == null ||
        realRoomId == roomId ||
        !RegExp(r'^[1-9]\d*$').hasMatch(realRoomId)) {
      throw CoreError('未获取到斗鱼直播间信息，请检查房间号或稍后刷新');
    }
    final resolved = await _getBetardRoomInfo(realRoomId);
    if (resolved == null) throw CoreError('斗鱼直播间信息返回异常，请稍后刷新');
    return resolved;
  }

  Future<Map?> _getBetardRoomInfo(String roomId) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/betard/$roomId",
      queryParameters: {},
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      },
    );
    if (result is String) {
      try {
        result = jsonDecode(result);
      } on FormatException {
        return null;
      }
    }
    return result is Map && result['room'] is Map
        ? result['room'] as Map
        : null;
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    var did = generateRandomString(32);
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchUser",
      queryParameters: {
        "kw": keyword,
        "page": page,
        "pageSize": 20,
        "filterType": 1,
      },
      header: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
        'Cookie': 'dy_did=$did;acf_did=$did',
      },
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["relateUser"]) {
      var liveStatus =
          (int.tryParse(item["anchorInfo"]["isLive"].toString()) ?? 0) == 1;
      var roomType =
          (int.tryParse(item["anchorInfo"]["roomType"].toString()) ?? 0);
      var roomItem = LiveAnchorItem(
        roomId: item["anchorInfo"]["rid"].toString(),
        avatar: item["anchorInfo"]["avatar"].toString(),
        userName: item["anchorInfo"]["nickName"].toString(),
        liveStatus: liveStatus && roomType == 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["relateUser"].isNotEmpty;
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    final room = await _getRoomInfo(roomId);
    final status = int.tryParse('${room["show_status"]}');
    if (status == null) throw StateError('斗鱼房间未返回直播状态');
    return status == 1 && room['videoLoop']?.toString() != '1';
  }

  int parseHotNum(String hn) {
    try {
      var num = double.parse(hn.replaceAll("万", ""));
      if (hn.contains("万")) {
        num *= 10000;
      }
      return num.round();
    } catch (_) {
      return -999;
    }
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
  }) {
    //尚不支持
    return Future.value([]);
  }
}

class DouyuPlayData {
  final int rate;
  final List<String> cdns;
  DouyuPlayData(this.rate, this.cdns);
}
