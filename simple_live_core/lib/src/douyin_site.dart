import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/scripts/douyin_sign.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  /// 使用 QQBrowser User-Agent（参考 DouyinLiveRecorder）
  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.97 Safari/537.36 Core/1.116.567.400 QQBrowser/19.7.6764.400";

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";
  static const Duration _webCookieCacheTtl = Duration(minutes: 5);
  static final Map<String, String> _webCookieCache = <String, String>{};
  static final Map<String, DateTime> _webCookieCacheAt = <String, DateTime>{};

  /// 默认 Cookie - 只需要 ttwid 字段即可获取所有画质（包括蓝光）
  /// 经过测试验证，LOGIN_STATUS=1 等其他字段都是可选的
  static const String kDefaultCookie =
      "ttwid=1%7CB1qls3GdnZhUov9o2NxOMxxYS2ff6OSvEWbv0ytbES4%7C1680522049%7C280d802d6d478e3e78d0c807f7c487e7ffec0ae4e5fdd6a0fe74c3c6af149511";

  /// 用户设置的 cookie
  String cookie = "";

  void _logDebug(String msg) {
    // 同时使用 print 和 CoreLog 确保日志输出
    print("[Douyin] $msg");
    CoreLog.d("[Douyin] $msg");
  }

  void _logElapsed(String label, Stopwatch stopwatch) {
    stopwatch.stop();
    _logDebug("$label 耗时 ${stopwatch.elapsedMilliseconds}ms");
  }

  Map<String, dynamic> _newRequestHeaders({
    String? cookieValue,
    String authority = kDefaultAuthority,
    String referer = kDefaultReferer,
  }) {
    final requestHeaders = <String, dynamic>{
      "Authority": authority,
      "Referer": referer,
      "User-Agent": kDefaultUserAgent,
    };
    final normalizedCookie = cookieValue?.trim() ?? "";
    if (normalizedCookie.isNotEmpty) {
      requestHeaders["cookie"] = normalizedCookie;
    }
    return requestHeaders;
  }

  String _defaultPlaybackCookie() {
    return DouyinCookieHelper.extractTtwid(kDefaultCookie) ?? kDefaultCookie;
  }

  String _customPlaybackCookie() {
    return DouyinCookieHelper.extractTtwid(cookie) ?? "";
  }

  String _playbackCookie() {
    final customTtwid = _customPlaybackCookie();
    return customTtwid.isNotEmpty ? customTtwid : _defaultPlaybackCookie();
  }

  String _searchCookie() {
    final savedCookie = cookie.trim();
    return savedCookie.isNotEmpty ? savedCookie : _defaultPlaybackCookie();
  }

  Future<Map<String, dynamic>> getRequestHeaders({
    bool includeFullCookie = false,
  }) {
    return Future.value(
      _newRequestHeaders(
        cookieValue: includeFullCookie ? _searchCookie() : _playbackCookie(),
      ),
    );
  }

  Future<String> _getDanmakuCookie(String webRid) async {
    final stopwatch = Stopwatch()..start();
    final requestHeaders = await getRequestHeaders();
    final baseCookie = requestHeaders["cookie"]?.toString() ?? "";
    try {
      final webCookie = await _getWebCookie(
        webRid,
      ).timeout(const Duration(seconds: 5));
      final merged = _mergeCookieValues(
        baseCookie,
        webCookie,
        preferBase: cookie.isNotEmpty,
      );
      _logElapsed("_getDanmakuCookie($webRid)", stopwatch);
      return merged;
    } catch (e) {
      CoreLog.error(e);
      _logElapsed("_getDanmakuCookie($webRid) fallback", stopwatch);
      return baseCookie;
    }
  }

  String _mergeCookieValues(
    String baseCookie,
    String extraCookie, {
    bool preferBase = false,
  }) {
    final base = _parseCookieValue(baseCookie);
    final extra = _parseCookieValue(extraCookie);
    final merged = preferBase ? {...extra, ...base} : {...base, ...extra};
    return merged.entries
        .map((entry) => "${entry.key}=${entry.value}")
        .join("; ");
  }

  Map<String, String> _parseCookieValue(String cookieValue) {
    final cookieMap = <String, String>{};
    for (final part in cookieValue.split(";")) {
      final item = part.trim();
      if (item.isEmpty) {
        continue;
      }
      final separatorIndex = item.indexOf("=");
      if (separatorIndex <= 0) {
        continue;
      }
      final key = item.substring(0, separatorIndex).trim();
      final value = item.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        cookieMap[key] = value;
      }
    }
    return cookieMap;
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    final renderDataJson = _extractCategoryRenderData(result);
    final categoryData = (renderDataJson["categoryData"] as List?) ?? const [];

    for (var item in categoryData) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';

      // 递归处理所有子分类（支持多级嵌套）
      for (var subItem in item["sub_partition"]) {
        var subCategory = _parseSubCategory(subItem, id);
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
        pic: _pickPartitionImageUrl(item["partition"]),
      );
      subs.insert(
        0,
        LiveSubCategory(
          id: category.id,
          name: category.name,
          parentId: category.id,
          pic: _pickPartitionImageUrl(item["partition"]),
        ),
      );
      categories.add(category);
    }
    return categories;
  }

  /// 递归解析子分类（支持多级嵌套）
  LiveSubCategory _parseSubCategory(dynamic item, String parentId) {
    var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
    List<LiveSubCategory> children = [];

    // 递归处理子分类的子分类（第三级、第四级...）
    final subPartitions = item["sub_partition"] as List? ?? [];
    for (var subItem in subPartitions) {
      children.add(_parseSubCategory(subItem, id));
    }

    return LiveSubCategory(
      id: id,
      name: asT<String?>(item["partition"]["title"]) ?? "",
      parentId: parentId,
      pic: _pickPartitionImageUrl(item["partition"]),
      children: children,
    );
  }

  String? _pickPartitionImageUrl(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      final value = data.trim();
      return value.isEmpty ? null : value;
    }
    if (data is List) {
      for (final item in data) {
        final value = _pickPartitionImageUrl(item);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }
    if (data is! Map) {
      return null;
    }

    for (final key in const [
      "icon",
      "icons",
      "cover",
      "background",
      "avatar_thumb",
      "image",
      "image_url",
      "url",
      "url_list",
      "static_icon",
    ]) {
      final value = _pickPartitionImageUrl(data[key]);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    for (final value in data.values) {
      final resolved = _pickPartitionImageUrl(value);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  String? _resolveCategoryValue(
    dynamic source,
    List<String> keys, {
    int depth = 0,
  }) {
    if (depth > 6) {
      return null;
    }
    if (source is List) {
      for (final item in source) {
        final value = _resolveCategoryValue(item, keys, depth: depth + 1);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }
    if (source is! Map) {
      return null;
    }
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    for (final value in source.values) {
      final resolved = _resolveCategoryValue(value, keys, depth: depth + 1);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  Map<String, String?> _resolveDouyinCategoryInfo(dynamic roomData) {
    final room = roomData is Map ? roomData : <String, dynamic>{};
    final partitionRoadMap =
        room["partition_road_map"] ?? room["partitionRoadMap"];
    final partition =
        room["partition"] ??
        room["room_partition"] ??
        room["partitionInfo"] ??
        (partitionRoadMap is List && partitionRoadMap.isNotEmpty
            ? partitionRoadMap.last
            : null);
    final parentPartition =
        room["parent_partition"] ??
        room["partition_parent"] ??
        (partition is Map
            ? partition["parent_partition"] ??
                  partition["partition_parent"] ??
                  partition["parent"]
            : null) ??
        (partitionRoadMap is List && partitionRoadMap.length > 1
            ? partitionRoadMap.first
            : null) ??
        room["partitionInfo"];

    return {
      "categoryId": _resolveCategoryValue(partition, const [
        "id_str",
        "id",
        "partition_id",
        "partition",
      ]),
      "categoryName": _resolveCategoryValue(partition, const [
        "title",
        "name",
        "partition_title",
      ]),
      "categoryParentId": _resolveCategoryValue(parentPartition, const [
        "id_str",
        "id",
        "partition_id",
        "partition",
      ]),
      "categoryParentName": _resolveCategoryValue(parentPartition, const [
        "title",
        "name",
        "partition_title",
      ]),
      "categoryPic":
          _pickPartitionImageUrl(partition) ??
          _pickPartitionImageUrl(parentPartition),
    };
  }

  Map<String, dynamic> _extractCategoryRenderData(String html) {
    const marker = r'\"categoryData\":';
    final markerIndex = html.indexOf(marker);
    if (markerIndex < 0) {
      throw CoreError("抖音分类数据解析失败");
    }
    final arrayStart = html.indexOf("[", markerIndex);
    if (arrayStart < 0) {
      throw CoreError("抖音分类数据解析失败");
    }
    final escapedArray = _extractEscapedJsonArray(html, arrayStart);
    final normalizedJson = '{"categoryData":$escapedArray}'
        .replaceAll(r'\"', '"')
        .replaceAll(r"\/", "/")
        .replaceAll(r"\\", "\\");
    return json.decode(normalizedJson) as Map<String, dynamic>;
  }

  String _extractEscapedJsonArray(String source, int startIndex) {
    final buffer = StringBuffer();
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = startIndex; i < source.length; i++) {
      final char = source[i];
      buffer.write(char);

      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == "\\") {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) {
        continue;
      }
      if (char == "[") {
        depth += 1;
      } else if (char == "]") {
        depth -= 1;
        if (depth == 0) {
          return buffer.toString();
        }
      }
    }
    throw CoreError("抖音分类数据解析失败");
  }

  List _resolveCategoryRoomData(dynamic result) {
    if (result is Map && result["status_code"] == 444) {
      throw CoreError("", statusCode: 444);
    }
    if (result is! Map) {
      throw CoreError("抖音分类接口返回异常");
    }
    final data = result["data"];
    if (data is! Map) {
      throw CoreError("抖音分类接口返回异常，可能已触发访问限制");
    }
    final rooms = data["data"];
    if (rooms is! List) {
      throw CoreError("抖音分类接口返回异常，可能已触发访问限制");
    }
    return rooms;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var ids = category.id.split(',');
    var partitionId = ids[0];
    var partitionType = ids[1];

    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "enter_from": "link_share",
        "cookie_enabled": "true",
        "screen_width": "1980",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "125.0.0.0",
        "browser_online": "true",
        "count": '15',
        "offset": ((page - 1) * 15).toString(),
        "partition": partitionId,
        "partition_type": partitionType,
        "req_from": '2',
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    final roomData = _resolveCategoryRoomData(result);
    var hasMore = roomData.length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in roomData) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online:
            int.tryParse(
              item["room"]["room_view_stats"]["display_value"].toString(),
            ) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    String serverUrl =
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "enter_from": "link_share",
        "cookie_enabled": "true",
        "screen_width": "1980",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "125.0.0.0",
        "browser_online": "true",
        "count": '15',
        "offset": ((page - 1) * 15).toString(),
        "partition": '720',
        "partition_type": '1',
        "req_from": '2',
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: await getRequestHeaders(),
    );

    final roomData = _resolveCategoryRoomData(result);
    var hasMore = roomData.length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in roomData) {
      var roomItem = LiveRoomItem(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online:
            int.tryParse(
              item["room"]["room_view_stats"]["display_value"].toString(),
            ) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    final stopwatch = Stopwatch()..start();
    try {
      // 有两种roomId，一种是webRid，一种是roomId
      // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
      // roomId一般长度为19位，例如：7376429659866598196
      // webRid是固定的，用户每次开播都是同一个webRid
      // webRid一般长度为11-12位，例如：416144012050
      // 这里简单进行判断，如果roomId长度小于15，则认为是webRid
      if (roomId.length <= 16) {
        var webRid = roomId;
        return await getRoomDetailByWebRid(webRid);
      }

      return await getRoomDetailByRoomId(roomId);
    } finally {
      _logElapsed("getRoomDetail($roomId)", stopwatch);
    }
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    final stopwatch = Stopwatch()..start();
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);
    final room = roomData["data"]?["room"];
    if (room is! Map) {
      throw CoreError("抖音直播间数据为空，可能是房间不存在、未开播或被风控限制");
    }

    // 通过房间信息获取WebRid
    var webRid = room["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = room["owner"];
    final categoryInfo = _resolveDouyinCategoryInfo(room);

    var status = asT<int?>(room["status"]) ?? 0;

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      _logElapsed("getRoomDetailByRoomId($roomId) redirect", stopwatch);
      return result;
    }

    var roomStatus = status == 2;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var danmakuCookie = await _getDanmakuCookie(webRid);

    final detail = LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: owner["nickname"].toString(),
      userAvatar: owner["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner["signature"].toString(),
      notice: "",
      categoryId: categoryInfo["categoryId"],
      categoryName: categoryInfo["categoryName"],
      categoryParentId: categoryInfo["categoryParentId"],
      categoryParentName: categoryInfo["categoryParentName"],
      categoryPic: categoryInfo["categoryPic"],
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: danmakuCookie,
      ),
      data: room["stream_url"],
    );
    _logElapsed("getRoomDetailByRoomId($roomId)", stopwatch);
    return detail;
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    final stopwatch = Stopwatch()..start();
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      _logElapsed("getRoomDetailByWebRid($webRid) api", stopwatch);
      return result;
    } catch (e) {
      CoreLog.error(e);
      if (e is CoreError && e.statusCode == 444) {
        rethrow;
      }
    }
    final result = await _getRoomDetailByWebRidHtml(webRid);
    _logElapsed("getRoomDetailByWebRid($webRid) html", stopwatch);
    return result;
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    final stopwatch = Stopwatch()..start();
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);

    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();
    final categoryInfo = _resolveDouyinCategoryInfo(roomData);

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = roomData["owner"];

    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var danmakuCookie = await _getDanmakuCookie(webRid);
    final detail = LiveRoomDetail(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : userData["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(roomData["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      categoryId: categoryInfo["categoryId"],
      categoryName: categoryInfo["categoryName"],
      categoryParentId: categoryInfo["categoryParentId"],
      categoryParentName: categoryInfo["categoryParentName"],
      categoryPic: categoryInfo["categoryPic"],
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: danmakuCookie,
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
    _logElapsed("_getRoomDetailByWebRidApi($webRid)", stopwatch);
    return detail;
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidHtml(String webRid) async {
    final stopwatch = Stopwatch()..start();
    var roomData = await _getRoomDataByHtml(webRid);
    var roomId = roomData["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    var userUniqueId = resolveUserUniqueIdFromRoomData(roomData);

    var room = roomData["roomStore"]["roomInfo"]["room"];
    var owner = room["owner"];
    var anchor = roomData["roomStore"]["roomInfo"]["anchor"];
    final categoryInfo = _resolveDouyinCategoryInfo(room);
    var roomStatus = (asT<int?>(room["status"]) ?? 0) == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var danmakuCookie = await _getDanmakuCookie(webRid);

    final detail = LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : anchor["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : anchor["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      categoryId: categoryInfo["categoryId"],
      categoryName: categoryInfo["categoryName"],
      categoryParentId: categoryInfo["categoryParentId"],
      categoryParentName: categoryInfo["categoryParentName"],
      categoryPic: categoryInfo["categoryPic"],
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: danmakuCookie,
      ),
      data: roomStatus ? room["stream_url"] : {},
    );
    _logElapsed("_getRoomDetailByWebRidHtml($webRid)", stopwatch);
    return detail;
  }

  String resolveUserUniqueIdFromRoomData(dynamic roomData) {
    final resolved = _resolveNestedString(roomData, const [
      "userStore",
      "odin",
      "user_unique_id",
    ]);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }

    final fallback = _resolveNestedString(roomData, const [
      "userStore",
      "user",
      "user_unique_id",
    ]);
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return generateRandomNumber(12).toString();
  }

  String? _resolveNestedString(dynamic source, List<String> path) {
    dynamic current = source;
    for (final key in path) {
      if (current is! Map) {
        return null;
      }
      current = current[key];
      if (current == null) {
        return null;
      }
    }
    final value = current.toString().trim();
    return value.isEmpty ? null : value;
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return resolveUserUniqueIdFromRoomData(webInfo);
    } catch (e) {
      return generateRandomNumber(12).toString();
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  Future<String> _getWebCookie(String webRid) async {
    final requestHeaders = Map<String, dynamic>.from(await getRequestHeaders());
    final baseCookie = _getCookieHeaderValue(requestHeaders);
    final cacheKey = "$webRid|${baseCookie.hashCode}";
    final cachedAt = _webCookieCacheAt[cacheKey];
    final cachedValue = _webCookieCache[cacheKey];
    if (cachedAt != null &&
        cachedValue != null &&
        DateTime.now().difference(cachedAt) < _webCookieCacheTtl) {
      _logDebug("_getWebCookie($webRid) 使用缓存");
      return cachedValue;
    }
    final stopwatch = Stopwatch()..start();
    requestHeaders["Referer"] = "https://live.douyin.com/$webRid";
    dynamic headResp;
    try {
      headResp = await HttpClient.instance.head(
        "https://live.douyin.com/$webRid",
        header: requestHeaders,
      );
    } catch (e) {
      if (baseCookie.isNotEmpty) {
        _logDebug("获取直播间 Web Cookie 的 HEAD 请求失败，使用已保存 Cookie 继续：$e");
        _webCookieCache[cacheKey] = baseCookie;
        _webCookieCacheAt[cacheKey] = DateTime.now();
        _logElapsed("_getWebCookie($webRid) fallback", stopwatch);
        return baseCookie;
      }
      rethrow;
    }
    if (headResp.statusCode == 444) {
      throw CoreError("", statusCode: 444);
    }
    var dyCookie = "";
    if (baseCookie.isNotEmpty) {
      dyCookie = _ensureCookieEndsWithSemicolon(baseCookie);
    }
    headResp.headers["set-cookie"]?.forEach((element) {
      var cookie = element.split(";")[0];
      if (cookie.contains("ttwid")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("__ac_nonce")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("msToken")) {
        dyCookie += "$cookie;";
      }
    });
    _webCookieCache[cacheKey] = dyCookie;
    _webCookieCacheAt[cacheKey] = DateTime.now();
    _logElapsed("_getWebCookie($webRid)", stopwatch);
    return dyCookie;
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    final stopwatch = Stopwatch()..start();
    var dyCookie = await _getWebCookie(webRid);
    final requestStopwatch = Stopwatch()..start();
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "Authority": kDefaultAuthority,
        "Referer": kDefaultReferer,
        "Cookie": dyCookie,
        "User-Agent": kDefaultUserAgent,
      },
    );
    _logElapsed("_getRoomDataByHtml($webRid) request", requestStopwatch);
    final parseStopwatch = Stopwatch()..start();
    if (result.trim().isEmpty) {
      throw CoreError("抖音直播间页面返回为空，请稍后再试");
    }
    if (!result.contains(r'\"state\"')) {
      throw CoreError("抖音直播间页面数据不可用，可能是访问受限或页面结构已变化");
    }

    var renderData =
        RegExp(
          r'\{\\"state\\":\{\\"appStore.*?\]\\n',
        ).firstMatch(result)?.group(0) ??
        "";
    if (renderData.isEmpty) {
      throw CoreError("抖音直播间页面数据解析失败，请稍后再试");
    }
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    final renderDataJson = json.decode(str);
    final state = renderDataJson["state"];
    if (state is! Map) {
      throw CoreError("抖音直播间页面状态数据异常");
    }
    _logElapsed("_getRoomDataByHtml($webRid) parse", parseStopwatch);
    _logElapsed("_getRoomDataByHtml($webRid)", stopwatch);
    return state;
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    final stopwatch = Stopwatch()..start();
    final result = await _requestWithCustomCookieFallback(
      label: "抖音房间接口",
      request: (cookieValue) =>
          _requestRoomDataByApi(webRid, cookieValue: cookieValue),
      hasData: _hasWebRoomData,
    );

    if (result is! Map) {
      throw Exception("抖音接口返回格式异常");
    }

    final data = result["data"];
    if (data is! Map) {
      throw CoreError("抖音直播间数据为空，请稍后再试");
    }
    final rooms = data["data"];
    if (rooms is! List || rooms.isEmpty) {
      throw CoreError("抖音直播间数据为空，可能是房间不存在、未开播或被风控限制");
    }

    _logElapsed("_getRoomDataByApi($webRid)", stopwatch);
    return data;
  }

  Future<dynamic> _requestRoomDataByApi(
    String webRid, {
    required String cookieValue,
  }) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";
    final requestHeader = _newRequestHeaders(
      cookieValue: cookieValue,
      referer: "https://live.douyin.com/$webRid",
    );

    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "aid": '6383',
        "app_name": "douyin_web",
        "live_id": '1',
        "device_platform": "web",
        "language": "zh-CN",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Chrome",
        "browser_version": "125.0.0.0",
        "web_rid": webRid,
        "msToken": "",
      },
    );
    final signStopwatch = Stopwatch()..start();
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);
    _logElapsed("_getRoomDataByApi($webRid) a_bogus", signStopwatch);

    final requestStopwatch = Stopwatch()..start();
    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: requestHeader,
    );
    _logElapsed("_getRoomDataByApi($webRid) request", requestStopwatch);
    return result;
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    final result = await _requestWithCustomCookieFallback(
      label: "抖音 reflow 接口",
      request: (cookieValue) =>
          _requestRoomDataByRoomId(roomId, cookieValue: cookieValue),
      hasData: _hasReflowRoomData,
    );
    return result;
  }

  Future<dynamic> _requestWithCustomCookieFallback({
    required String label,
    required Future<dynamic> Function(String cookieValue) request,
    required bool Function(dynamic result) hasData,
  }) async {
    final customPlaybackCookie = _customPlaybackCookie();
    dynamic result;
    try {
      result = await request(_playbackCookie());
    } catch (error) {
      if (customPlaybackCookie.isEmpty) {
        rethrow;
      }
      _logDebug("$label 使用自定义 Cookie 请求失败，使用匿名 ttwid 重试：$error");
      return request(_defaultPlaybackCookie());
    }
    if (customPlaybackCookie.isEmpty || hasData(result)) {
      return result;
    }
    _logDebug("$label 返回空数据，使用匿名 ttwid 重试一次");
    return request(_defaultPlaybackCookie());
  }

  Future<dynamic> _requestRoomDataByRoomId(
    String roomId, {
    required String cookieValue,
  }) {
    return HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: _newRequestHeaders(cookieValue: cookieValue),
    );
  }

  bool _hasWebRoomData(dynamic result) {
    if (result is! Map) {
      return false;
    }
    final data = result["data"];
    if (data is! Map) {
      return false;
    }
    final rooms = data["data"];
    return rooms is List && rooms.any((room) => room is Map && room.isNotEmpty);
  }

  bool _hasReflowRoomData(dynamic result) {
    if (result is! Map) {
      return false;
    }
    final data = result["data"];
    if (data is! Map) {
      return false;
    }
    final room = data["room"];
    return room is Map && room.isNotEmpty;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
    final stopwatch = Stopwatch()..start();
    List<LivePlayQuality> qualities = [];

    try {
      var liveCoreData = detail.data["live_core_sdk_data"];

      if (liveCoreData == null) {
        return qualities;
      }

      var pullData = liveCoreData["pull_data"];

      if (pullData == null) {
        return qualities;
      }

      var options = pullData["options"];

      var qulityList = options?["qualities"];

      var streamData = pullData["stream_data"]?.toString() ?? "";

      if (!streamData.startsWith('{')) {
        var flvList = (detail.data["flv_pull_url"] as Map).values
            .cast<String>()
            .toList();
        var hlsList = (detail.data["hls_pull_url_map"] as Map).values
            .cast<String>()
            .toList();
        for (var quality in qulityList) {
          int level = quality["level"];
          List<String> urls = [];
          var flvIndex = flvList.length - level;
          if (flvIndex >= 0 && flvIndex < flvList.length) {
            urls.add(flvList[flvIndex]);
          }
          var hlsIndex = hlsList.length - level;
          if (hlsIndex >= 0 && hlsIndex < hlsList.length) {
            urls.add(hlsList[hlsIndex]);
          }
          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: level,
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      } else {
        var qualityData = json.decode(streamData)["data"] as Map;

        for (var quality in qulityList) {
          List<String> urls = [];

          var flvUrl = qualityData[quality["sdk_key"]]?["main"]?["flv"]
              ?.toString();

          if (flvUrl != null && flvUrl.isNotEmpty) {
            urls.add(flvUrl);
          }
          var hlsUrl = qualityData[quality["sdk_key"]]?["main"]?["hls"]
              ?.toString();

          if (hlsUrl != null && hlsUrl.isNotEmpty) {
            urls.add(hlsUrl);
          }

          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: quality["level"],
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      }
    } catch (e, stackTrace) {
      CoreLog.error(e);
      CoreLog.error(stackTrace);
    }
    // var qualityData = json.decode(
    //     detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    _logDebug("获取到的画质列表: ${qualities.map((q) => q.quality).toList()}");
    _logElapsed("getPlayQualites(${detail.roomId})", stopwatch);
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    final stopwatch = Stopwatch()..start();
    // 返回列表的副本，防止外部 clear() 影响原始数据
    final result = LivePlayUrl(urls: List<String>.from(quality.data));
    _logElapsed("getPlayUrls(${detail.roomId}, ${quality.quality})", stopwatch);
    return result;
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    String serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/";
    var uri = Uri.parse(serverUrl).replace(
      scheme: "https",
      port: 443,
      queryParameters: {
        "device_platform": "webapp",
        "aid": "6383",
        "channel": "channel_pc_web",
        "search_channel": "aweme_live",
        "keyword": keyword,
        "search_source": "switch_tab",
        "query_correct_type": "1",
        "is_filter_search": "0",
        "from_group_id": "",
        "offset": ((page - 1) * 10).toString(),
        "count": "10",
        "pc_client_type": "1",
        "version_code": "170400",
        "version_name": "17.4.0",
        "cookie_enabled": "true",
        "screen_width": "1980",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "125.0.0.0",
        "browser_online": "true",
        "engine_name": "Blink",
        "engine_version": "125.0.0.0",
        "os_name": "Windows",
        "os_version": "10",
        "cpu_core_num": "12",
        "device_memory": "8",
        "platform": "PC",
        "downlink": "10",
        "effective_type": "4g",
        "round_trip_time": "100",
        "webid": "7382872326016435738",
      },
    );
    //var requlestUrl = await getAbogusUrl(uri.toString());
    var requlestUrl = uri.toString();
    final requestHeaders = await getRequestHeaders(includeFullCookie: true);
    var dyCookie = "";
    final savedCookie = _getCookieHeaderValue(requestHeaders);
    if (savedCookie.isNotEmpty) {
      dyCookie = _ensureCookieEndsWithSemicolon(savedCookie);
    }
    dynamic headResp;
    try {
      headResp = await HttpClient.instance.head(
        'https://live.douyin.com',
        header: requestHeaders,
      );
    } catch (e) {
      if (dyCookie.isEmpty) {
        rethrow;
      }
      _logDebug("抖音搜索预取 Cookie 的 HEAD 请求失败，使用已保存 Cookie 继续：$e");
    }
    if (headResp != null) {
      headResp.headers["set-cookie"]?.forEach((element) {
        var cookie = element.split(";")[0];
        if (cookie.contains("ttwid")) {
          dyCookie += "$cookie;";
        }
        if (cookie.contains("__ac_nonce")) {
          dyCookie += "$cookie;";
        }
      });
    }

    var result = await HttpClient.instance.getJson(
      requlestUrl,
      queryParameters: {},
      header: {
        "Authority": 'www.douyin.com',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'cookie': dyCookie,
        'priority': 'u=1, i',
        'referer':
            'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?type=live',
        'sec-ch-ua':
            '"Microsoft Edge";v="125", "Chromium";v="125", "Not.A/Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': kDefaultUserAgent,
      },
    );
    if (result == "" || result == 'blocked') {
      throw Exception("抖音直播搜索被限制，请稍后再试");
    }
    if (result is Map && result["status_code"] == 2483) {
      throw Exception("抖音搜索需要登录，请在账号管理中通过网页登录或手动配置完整抖音 Cookie");
    }
    var items = <LiveRoomItem>[];
    for (var item in result["data"] ?? []) {
      var itemData = json.decode(item["lives"]["rawdata"].toString());
      var roomItem = LiveRoomItem(
        roomId: itemData["owner"]["web_rid"].toString(),
        title: itemData["title"].toString(),
        cover: itemData["cover"]["url_list"][0].toString(),
        userName: itemData["owner"]["nickname"].toString(),
        online: int.tryParse(itemData["stats"]["total_user"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: items.length >= 10, items: items);
  }

  String _getCookieHeaderValue(Map<String, dynamic> requestHeaders) {
    return (requestHeaders["Cookie"] ?? requestHeaders["cookie"] ?? "")
        .toString()
        .trim();
  }

  String _ensureCookieEndsWithSemicolon(String value) {
    final cookie = value.trim();
    if (cookie.isEmpty || cookie.endsWith(";")) {
      return cookie;
    }
    return "$cookie;";
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    final result = await searchRooms(keyword, page: page);
    final lowerKeyword = keyword.trim().toLowerCase();
    final rooms = result.items.toList()
      ..sort((a, b) {
        final aMatched = a.userName.toLowerCase().contains(lowerKeyword);
        final bMatched = b.userName.toLowerCase().contains(lowerKeyword);
        if (aMatched != bMatched) {
          return aMatched ? -1 : 1;
        }
        return b.online.compareTo(a.online);
      });
    return LiveSearchAnchorResult(
      hasMore: result.hasMore,
      items: rooms
          .map(
            (room) => LiveAnchorItem(
              roomId: room.roomId,
              userName: room.userName,
              avatar: room.cover,
              liveStatus: true,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    final targetId = roomId.trim();
    if (targetId.isEmpty) {
      return false;
    }
    LiveRoomDetail? resolvedDetail;
    try {
      final status = await _tryGetLiveStatus(targetId);
      if (status == true) {
        return true;
      }
      resolvedDetail = await getRoomDetail(roomId: targetId);
      if (resolvedDetail.status) {
        return true;
      }
      if (status != null) {
        return status;
      }
      return resolvedDetail.status;
    } catch (e) {
      if (e is CoreError && e.statusCode == 444) {
        rethrow;
      }
      if (resolvedDetail != null) {
        return resolvedDetail.status;
      }
      CoreLog.error(e);
      return false;
    }
  }

  Future<bool?> _tryGetLiveStatus(String targetId) async {
    final attempts = <Future<bool?> Function()>[];
    if (targetId.length <= 16) {
      attempts.add(() => _getLiveStatusByWebRid(targetId));
      attempts.add(() => _getLiveStatusByRoomId(targetId));
    } else {
      attempts.add(() => _getLiveStatusByRoomId(targetId));
      attempts.add(() => _getLiveStatusByWebRid(targetId));
    }

    Object? lastError;
    for (var i = 0; i < attempts.length; i++) {
      try {
        return await attempts[i]();
      } catch (e) {
        if (e is CoreError && e.statusCode == 444) {
          rethrow;
        }
        lastError = e;
        if (i == 0) {
          _logDebug("getLiveStatus($targetId) 第1路失败，尝试第2路：$e");
        }
      }
    }

    if (lastError != null) {
      CoreLog.error(lastError);
    }
    return null;
  }

  Future<bool> _getLiveStatusByWebRid(String webRid) async {
    final data = await _getRoomDataByApi(webRid);
    final roomList = data["data"];
    if (roomList is List && roomList.isNotEmpty) {
      final roomData = roomList.first;
      return _isDouyinLiveStatus(roomData);
    }
    throw CoreError("抖音直播状态数据为空");
  }

  Future<bool?> _getLiveStatusByRoomId(String roomId) async {
    final roomData = await _getRoomDataByRoomId(roomId);
    final room = roomData["data"]?["room"];
    if (room is! Map) {
      return null;
    }
    final status = _parseDouyinStatus(
      room["status"] ?? room["live_status"] ?? room["room_status"],
    );
    if (status == null) {
      return null;
    }
    if (status == 4) {
      final webRid = room["owner"]?["web_rid"]?.toString().trim() ?? "";
      if (webRid.isNotEmpty) {
        return _getLiveStatusByWebRid(webRid);
      }
    }
    return status == 2;
  }

  bool _isDouyinLiveStatus(dynamic data) {
    if (data is! Map) {
      return false;
    }
    final candidates = <dynamic>[
      data["status"],
      data["live_status"],
      data["room_status"],
      data["status_str"],
    ];
    for (final candidate in candidates) {
      final parsed = _parseDouyinStatus(candidate);
      if (parsed != null) {
        return parsed == 2;
      }
    }
    return false;
  }

  int? _parseDouyinStatus(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    if (value is Map) {
      for (final key in const ["status", "live_status", "room_status"]) {
        final parsed = _parseDouyinStatus(value[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
    LiveRoomDetail? detail,
  }) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  @override
  Future<List<LiveContributionRankItem>> getContributionRank({
    required String roomId,
    LiveRoomDetail? detail,
  }) async {
    final roomDetail = detail ?? await getRoomDetail(roomId: roomId);
    final webRid = roomDetail.roomId.isNotEmpty ? roomDetail.roomId : roomId;
    final danmakuArgs = roomDetail.danmakuData is DouyinDanmakuArgs
        ? roomDetail.danmakuData as DouyinDanmakuArgs
        : null;

    final roomInfo = await _getRoomDataByApi(webRid);
    final roomList = (roomInfo["data"] as List?) ?? const [];
    if (roomList.isEmpty) {
      return [];
    }
    final roomData = roomList.first;
    final owner = roomData["owner"] ?? roomInfo["user"] ?? {};
    final anchorId =
        owner["id_str"]?.toString() ?? owner["id"]?.toString() ?? "";
    final secAnchorId = owner["sec_uid"]?.toString() ?? "";
    final realRoomId =
        danmakuArgs?.roomId ?? roomData["id_str"]?.toString() ?? "";
    if (anchorId.isEmpty || secAnchorId.isEmpty || realRoomId.isEmpty) {
      return [];
    }

    final requestHeader = await getRequestHeaders();
    requestHeader["Referer"] = "https://live.douyin.com/$webRid";

    final uri = Uri.parse("https://live.douyin.com/webcast/ranklist/audience/")
        .replace(
          queryParameters: {
            "aid": "6383",
            "app_name": "douyin_web",
            "live_id": "1",
            "device_platform": "web",
            "language": "zh-CN",
            "enter_from": "link_share",
            "cookie_enabled": "true",
            "screen_width": "1920",
            "screen_height": "1080",
            "browser_language": "zh-CN",
            "browser_platform": "Win32",
            "browser_name": "Chrome",
            "browser_version": "125.0.0.0",
            "os_name": "Windows",
            "os_version": "10",
            "webcast_sdk_version": "2450",
            "room_id": realRoomId,
            "anchor_id": anchorId,
            "sec_anchor_id": secAnchorId,
            "ignoreToast": "true",
            "rank_type": "30",
            "msToken": "",
          },
        );
    final requestUrl = DouyinSign.getAbogusUrl(
      uri.toString(),
      kDefaultUserAgent,
    );
    final result = await HttpClient.instance.getJson(
      requestUrl,
      header: requestHeader,
    );
    final items = (result["data"]?["ranks"] as List?) ?? const [];
    return items
        .asMap()
        .entries
        .map((entry) {
          final item = entry.value;
          final user = item["user"] ?? {};
          final payGrade = user["pay_grade"] ?? {};
          final fansData = user["fans_club"]?["data"] ?? {};
          final userLevel = int.tryParse(payGrade["level"].toString());
          final fansLevel = int.tryParse(fansData["level"].toString());
          final scoreText = _resolveDouyinRankScore(item);
          final scoreDescription =
              item["score_description"]?.toString().trim() ?? "";
          final exactlyScore = item["exactly_score"]?.toString().trim() ?? "";
          String? scoreDetail;
          if (scoreDescription.isNotEmpty && scoreDescription != scoreText) {
            scoreDetail = scoreDescription;
          } else if (exactlyScore.isNotEmpty && exactlyScore != scoreText) {
            scoreDetail = exactlyScore;
          } else {
            final gapDescription =
                item["gap_description"]?.toString().trim() ?? "";
            scoreDetail = gapDescription.isEmpty ? null : gapDescription;
          }

          return LiveContributionRankItem(
            rank: _resolveDouyinRank(item, entry.key),
            userName: user["nickname"]?.toString() ?? "",
            avatar: _firstImageUrl(user["avatar_thumb"]),
            scoreText: scoreText,
            scoreDetail: scoreDetail,
            userLevel: userLevel,
            userLevelText: userLevel == null || userLevel <= 0
                ? null
                : "财富 $userLevel",
            userLevelIcon: _firstImageUrl(payGrade["new_im_icon_with_level"]),
            fansLevel: fansLevel,
            fansName: fansData["club_name"]?.toString(),
            fansIcon: _pickDouyinBadgeIcon(fansData["badge"]?["icons"]),
          );
        })
        .where((item) => item.userName.trim().isNotEmpty)
        .toList();
  }

  int _resolveDouyinRank(Map item, int index) {
    final parsed = int.tryParse(item["rank"]?.toString() ?? "");
    if (parsed == null || parsed <= 0) {
      return index + 1;
    }
    if (parsed == 1 && index > 0) {
      return index + 1;
    }
    return parsed;
  }

  String _firstImageUrl(dynamic data) {
    if (data is! Map) {
      return "";
    }
    final urls = data["url_list"];
    if (urls is List && urls.isNotEmpty) {
      return urls.first.toString();
    }
    return "";
  }

  String? _pickDouyinBadgeIcon(dynamic icons) {
    if (icons is! Map) {
      return null;
    }
    for (final key in const ["4", "3", "2", "1", "0"]) {
      final url = _firstImageUrl(icons[key]);
      if (url.isNotEmpty) {
        return url;
      }
    }
    for (final value in icons.values) {
      final url = _firstImageUrl(value);
      if (url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  String _resolveDouyinRankScore(Map item) {
    final exactlyScore = item["exactly_score"]?.toString().trim() ?? "";
    if (exactlyScore.isNotEmpty) {
      return exactlyScore;
    }
    final scoreDescription = item["score_description"]?.toString().trim() ?? "";
    if (scoreDescription.isNotEmpty) {
      return scoreDescription;
    }
    final score = item["score"]?.toString().trim() ?? "";
    if (score.isNotEmpty) {
      return score;
    }
    final delta = item["delta"]?.toString().trim() ?? "";
    if (delta.isNotEmpty) {
      return delta;
    }
    return "0";
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

  // 生成随机的数字
  int generateRandomNumber(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(10));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item);
    }
    return int.tryParse(stringBuffer.toString()) ??
        Random().nextInt(1000000000);
  }
}
