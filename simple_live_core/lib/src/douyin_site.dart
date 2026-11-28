import 'common/request_pool.dart';
import 'dart:convert';
import 'model/room_category_name.dart';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/core_error.dart';
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

  /// 默认 Cookie - 只需要 ttwid 字段即可获取所有画质（包括蓝光）
  /// 经过测试验证，LOGIN_STATUS=1 等其他字段都是可选的
  static const String kDefaultCookie =
      "ttwid=1%7CB1qls3GdnZhUov9o2NxOMxxYS2ff6OSvEWbv0ytbES4%7C1680522049%7C280d802d6d478e3e78d0c807f7c487e7ffec0ae4e5fdd6a0fe74c3c6af149511";

  /// 用户设置的 cookie
  String _cookie = "";
  String? _visitorCookie;
  Future<String>? _visitorCookieRequest;
  Map<String, dynamic>? _recommendHeaders;
  final Map<String, String> _webPartitionNames = {};
  Future<List<LiveCategory>>? _followCategoryRequest;

  String get cookie => _cookie;
  set cookie(String value) {
    if (_cookie == value) return;
    _cookie = value;
    _visitorCookie = null;
    _recommendHeaders = null;
  }

  void _logDebug(String msg) {
    CoreLog.d("[Douyin] $msg");
  }

  Map<String, dynamic> headers = {
    "Authority": kDefaultAuthority,
    "Referer": kDefaultReferer,
    "User-Agent": kDefaultUserAgent,
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    final configured = cookie.isNotEmpty ? cookie : kDefaultCookie;
    return {
      ...headers,
      'cookie': _visitorCookie == null
          ? configured
          : _mergeCookies(configured, [_visitorCookie!]),
    };
  }

  String _mergeCookies(String original, Iterable<String> updates) {
    final values = <String, String>{};
    for (final value in [...original.split(';'), ...updates]) {
      final entry = value.split(';').first.trim();
      final separator = entry.indexOf('=');
      if (separator > 0) values[entry.substring(0, separator)] = entry;
    }
    return values.values.join('; ');
  }

  Future<String> _fetchVisitorCookie() async {
    // 首页 HEAD 即使返回 404，也可能在响应头中发放访客会话。
    final response = await HttpClient.instance.head(
      'https://live.douyin.com/',
      header: {...headers},
    );
    final value = (response.headers['set-cookie'] ?? []).firstWhere(
      (value) => value.trimLeft().startsWith('ttwid='),
      orElse: () => '',
    );
    if (value.isEmpty) throw const FormatException('抖音未返回访客会话');
    return value.split(';').first.trim();
  }

  Future<void> _refreshVisitorCookie() async {
    final configured = cookie;
    final pending = _visitorCookieRequest ??= _fetchVisitorCookie();
    try {
      final value = await pending;
      // 并发更新关注时共享请求，不覆盖请求期间修改的账号配置。
      if (cookie == configured) _visitorCookie = value;
    } finally {
      if (identical(_visitorCookieRequest, pending)) {
        _visitorCookieRequest = null;
      }
    }
  }

  @override
  void prefetchRoom(String roomId) {}

  /// 预热抖音访客会话 Cookie（ttwid），避免首次批量刷新时现抓首页。
  Future<void> warmup() async {
    if (cookie.isNotEmpty || _visitorCookie != null) return;
    try {
      await _refreshVisitorCookie().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );
    void collect(dynamic node) {
      if (node is! Map) return;
      final partition = node['partition'];
      final id = partition is Map ? douyinWebPartitionId(partition) : null;
      final title = partition is Map
          ? firstCategoryName([partition['title']])
          : null;
      if (id != null && title != null) _webPartitionNames[id] = title;
      final children = node['sub_partition'];
      if (children is List) {
        for (final child in children) {
          collect(child);
        }
      }
    }

    for (final node in _parseCategoryData(result)) {
      collect(node);
    }
    return parseCategories(result);
  }

  /// 只供关注页使用官方网页分区；不再次获取直播间详情。
  Future<String?> getFollowCategoryName(LiveRoomDetail detail) async {
    if (detail.leafCategoryName != null && detail.leafCategoryName != '游戏') {
      return detail.leafCategoryName;
    }
    final fallback = detail.webParentCategoryName ?? '其他';
    final id = detail.categoryId;
    if (id == null) return fallback;
    if (_webPartitionNames.isEmpty) {
      final request = _followCategoryRequest ??= getCategores();
      try {
        await request;
      } catch (error) {
        // 分类目录失败仅影响分类回退，不改变直播状态或播放结果。
        CoreLog.error(error);
      } finally {
        // 失败或空目录不能永久缓存；仅在缺少叶子分类时允许下次补齐。
        if (_webPartitionNames.isEmpty &&
            identical(_followCategoryRequest, request)) {
          _followCategoryRequest = null;
        }
      }
    }
    final name = _webPartitionNames[id];
    return name == null || name == '游戏' ? fallback : name;
  }

  static List<dynamic> _parseCategoryData(String page) {
    const marker = r'\"categoryData\":';
    final markerIndex = page.indexOf(marker);
    if (markerIndex < 0) throw const FormatException('未找到抖音分类数据');
    final start = page.indexOf('[', markerIndex + marker.length);
    if (start < 0) throw const FormatException('抖音分类数据格式错误');
    var depth = 0;
    var end = -1;
    for (var i = start; i < page.length; i++) {
      if (page[i] == '[') depth++;
      if (page[i] == ']' && --depth == 0) {
        end = i;
        break;
      }
    }
    if (end < 0) throw const FormatException('抖音分类数据不完整');
    final encoded = page.substring(start, end + 1);
    return json.decode(json.decode('"$encoded"') as String) as List<dynamic>;
  }

  static List<LiveCategory> parseCategories(String page) {
    final renderDataJson = _parseCategoryData(page);
    List<LiveCategory> categories = [];

    for (var item in renderDataJson) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
        0,
        LiveSubCategory(
          id: category.id,
          name: category.name,
          parentId: category.id,
          pic: "",
        ),
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

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
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
    // Room validation may renew the visitor cookie. Changing that cookie
    // between recommendation pages resets the upstream feed to its first batch,
    // even with a nonzero offset. Pin this feed's session until refresh/account
    // change; room validation can still renew its own session independently.
    if (page == 1 || _recommendHeaders == null) {
      _recommendHeaders = await getRequestHeaders();
    }
    final recommendHeaders = _recommendHeaders!;
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
        // Sign the cache-buster too; a refresh must reach the upstream server.
        "_": DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: {
        ...recommendHeaders,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    final data = result is Map ? result['data'] : null;
    final rows = data is Map ? data['data'] : null;
    if (result is! Map || result['status_code'] != 0 || rows is! List) {
      throw CoreError('抖音推荐接口未返回有效数据，请稍后刷新');
    }
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['web_rid']?.toString() ?? '';
      if (id.isNotEmpty && id != '0') ids.add(id);
    }
    // This feed returns status=0 even for live rooms. It is NOT a live-state
    // signal. Revalidate against room detail rather than displaying stale cards
    // or dropping the entire feed. O(n) requests, at most four in flight.
    final roomIds = ids.toList();
    final verified = List<LiveRoomItem?>.filled(roomIds.length, null);
    var next = 0;
    var failures = 0;
    Future<void> worker() async {
      while (next < roomIds.length) {
        final index = next++;
        try {
          final room = await getRoomDetail(roomId: roomIds[index]);
          if (room.status) {
            verified[index] = LiveRoomItem(
              roomId: room.roomId,
              title: room.title,
              cover: room.cover,
              userName: room.userName,
              online: room.online,
            );
          }
        } catch (error) {
          failures++;
          CoreLog.w('抖音推荐房间状态校验失败: ${roomIds[index]} $error');
        }
      }
    }

    await Future.wait(List.generate(min(4, roomIds.length), (_) => worker()));
    final items = verified.whereType<LiveRoomItem>().toList();
    if (items.isEmpty && failures > 0) {
      throw CoreError('抖音推荐直播状态校验失败，请稍后刷新');
    }
    // A short recommendation batch or an all-offline filtered batch does not
    // mean the feed is exhausted. Prefer an explicit flag when available.
    final more = data['has_more'];
    final hasMore = more == null
        ? rows.isNotEmpty
        : more == true || more == 1 || more == '1';
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) =>
      _roomRequests.run(jsonEncode([cookie, roomId]), () => _loadRoomDetail(roomId));

  final _roomRequests = InFlightRequests<LiveRoomDetail>();

  @override
  Future<LiveRoomDetail> refreshRoomDetail({required String roomId}) {
    _roomRequests.invalidate(jsonEncode([cookie, roomId]));
    return getRoomDetail(roomId: roomId);
  }

  Future<LiveRoomDetail> _loadRoomDetail(String roomId) async {
    // 有两种roomId，一种是webRid，一种是roomId
    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // roomId一般长度为19位，例如：7376429659866598196
    // webRid是固定的，用户每次开播都是同一个webRid
    // webRid一般长度为11-12位，例如：416144012050
    // 这里简单进行判断，如果roomId长度小于15，则认为是webRid
    Future<LiveRoomDetail> load() => roomId.length <= 16
        ? getRoomDetailByWebRid(roomId)
        : getRoomDetailByRoomId(roomId);
    try {
      return await load();
    } catch (e) {
      CoreLog.error(e);
      if (e is CoreError && const [400, 401, 403, 404].contains(e.statusCode)) {
        rethrow;
      }
      await Future.delayed(const Duration(milliseconds: 400));
      return load();
    }
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    // 读取房间信息
    var roomData = await _getRoomDataByRoomId(roomId);

    // 通过房间信息获取WebRid
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var room = roomData["data"]["room"];
    final webPartition = douyinWebPartition(room, roomData['data']);
    var owner = room["owner"];

    final status = int.tryParse(room['status']?.toString() ?? '');
    if (status == null) throw StateError('抖音房间未返回直播状态');

    // roomId是一次性的，用户每次重新开播都会生成一个新的roomId
    // 所以如果roomId对应的直播间状态不是直播中，就通过webRid获取直播间信息
    if (status == 4) {
      var result = await getRoomDetailByWebRid(webRid);
      return result;
    }

    var roomStatus = status == 2;
    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      categoryName: douyinCategoryName(room),
      categoryId: douyinWebPartitionId(webPartition),
      leafCategoryName: firstCategoryName([webPartition?['title']]),
      webParentCategoryName: douyinWebParentCategoryName(
        room,
        roomData['data'],
      ),
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
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: room["stream_url"],
    );
  }

  /// 通过WebRid获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e, stackTrace) {
      CoreLog.error(e);
      try {
        return await _getRoomDetailByWebRidHtml(webRid);
      } catch (fallbackError) {
        // 备用页面失败时保留首个接口错误，便于判断重试条件与真实原因。
        CoreLog.error(fallbackError);
        Error.throwWithStackTrace(e, stackTrace);
      }
    }
  }

  /// 通过WebRid访问直播间API，从API中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    // 读取房间信息
    var data = await _getRoomDataByApi(webRid);

    var roomData = data["data"][0];
    final webPartition = douyinWebPartition(roomData, data);
    var userData = data["user"];
    final status = int.tryParse(roomData['status']?.toString() ?? '');
    if (status == null) throw StateError('抖音房间未返回直播状态');
    if (status != 2) {
      // A confirmed offline response is complete even without stream/owner fields.
      return _offlineRoomDetail(
        webRid,
        roomData,
        userData ?? roomData['owner'],
        data,
      );
    }
    var roomId = roomData["id_str"].toString();

    // 读取用户唯一ID，用于弹幕连接
    // 似乎这个参数不是必须的，先随机生成一个
    //var userUniqueId = await _getUserUniqueId(webRid);
    var userUniqueId = generateRandomNumber(12).toString();

    var owner = roomData["owner"];

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();
    return LiveRoomDetail(
      roomId: webRid,
      categoryName: douyinCategoryName(roomData, data),
      categoryId: douyinWebPartitionId(webPartition),
      leafCategoryName: firstCategoryName([webPartition?['title']]),
      webParentCategoryName: douyinWebParentCategoryName(roomData, data),
      title: roomData["title"].toString(),
      cover: _firstRoomImage(roomData['cover']),
      userName: (owner?['nickname'] ?? userData?['nickname'])?.toString() ?? '',
      userAvatar: _firstRoomImage(owner?['avatar_thumb'] ?? userData?['avatar_thumb']),
      online: int.tryParse('${roomData['room_view_stats']?['display_value']}') ?? 0,
      status: true,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomData['stream_url'],
    );
  }

  String _firstRoomImage(dynamic image) {
    final urls = image?['url_list'];
    return urls is List && urls.isNotEmpty ? urls.first.toString() : '';
  }

  LiveRoomDetail _offlineRoomDetail(
    String webRid,
    Map room,
    dynamic user,
    Map context,
  ) {
    final partition = douyinWebPartition(room, context);
    final avatars = user?['avatar_thumb']?['url_list'];
    return LiveRoomDetail(
      roomId: webRid,
      status: false,
      online: 0,
      title: room['title']?.toString() ?? '',
      cover: '',
      userName: user?['nickname']?.toString() ?? '',
      userAvatar: avatars is List && avatars.isNotEmpty
          ? avatars.first.toString()
          : '',
      url: 'https://live.douyin.com/$webRid',
      categoryName: douyinCategoryName(room, context),
      categoryId: douyinWebPartitionId(partition),
      leafCategoryName: firstCategoryName([partition?['title']]),
      webParentCategoryName: douyinWebParentCategoryName(room, context),
    );
  }

  /// 通过WebRid访问直播间网页，从网页HTML中获取直播间信息
  /// - [webRid] 直播间RID
  /// - 返回直播间信息
  Future<LiveRoomDetail> _getRoomDetailByWebRidHtml(String webRid) async {
    var roomData = await _getRoomDataByHtml(webRid);
    var roomId = roomData["roomStore"]["roomInfo"]["room"]["id_str"].toString();
    var userUniqueId =
        roomData["userStore"]?["odin"]?["user_unique_id"]?.toString() ??
        generateRandomNumber(12).toString();

    var room = roomData["roomStore"]["roomInfo"]["room"];
    final webPartition = douyinWebPartition(
      room,
      roomData['roomStore']['roomInfo'],
    );
    var owner = room["owner"];
    var anchor = roomData["roomStore"]["roomInfo"]["anchor"];
    final status = int.tryParse(room['status']?.toString() ?? '');
    if (status == null) throw StateError('抖音网页未返回直播状态');
    if (status != 2) {
      return _offlineRoomDetail(
        webRid,
        room,
        anchor ?? owner,
        roomData['roomStore']['roomInfo'],
      );
    }
    var roomStatus = status == 2;

    // 主要是为了获取cookie,用于弹幕websocket连接
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      categoryName: douyinCategoryName(room, roomData['roomStore']['roomInfo']),
      categoryId: douyinWebPartitionId(webPartition),
      leafCategoryName: firstCategoryName([webPartition?['title']]),
      webParentCategoryName: douyinWebParentCategoryName(
        room,
        roomData['roomStore']['roomInfo'],
      ),
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
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["cookie"],
      ),
      data: roomStatus ? room["stream_url"] : {},
    );
  }

  /// 读取用户的唯一ID
  /// - [webRid] 直播间RID
  // ignore: unused_element
  Future<String> _getUserUniqueId(String webRid) async {
    try {
      var webInfo = await _getRoomDataByHtml(webRid);
      return webInfo["userStore"]["odin"]["user_unique_id"].toString();
    } catch (e) {
      return generateRandomNumber(12).toString();
    }
  }

  /// 进入直播间前需要先获取cookie
  /// - [webRid] 直播间RID
  Future<String> _getWebCookie(String webRid) async {
    final requestHeaders = await getRequestHeaders();
    var headResp = await HttpClient.instance.head(
      "https://live.douyin.com/$webRid",
      header: requestHeaders,
    );
    return _mergeCookies(
      requestHeaders['cookie'] as String,
      (headResp.headers['set-cookie'] ?? []).where(
        (value) =>
            value.startsWith('ttwid=') ||
            value.startsWith('__ac_nonce=') ||
            value.startsWith('msToken='),
      ),
    );
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByHtml(String webRid) async {
    var dyCookie = await _getWebCookie(webRid);
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

    // 先解码脚本中的 JSON 字符串，避免手动反转义破坏标题等字段。
    final chunks = RegExp(
      r'self\.__(?:next|pace)_f\.push\(\s*\[\s*\d+\s*,\s*("(?:\\.|[^"\\])*")\s*\]\s*\)',
    ).allMatches(result);
    for (final chunk in chunks) {
      try {
        final payload = json.decode(chunk.group(1)!) as String;
        final start = RegExp(r'\{\s*"state"\s*:').firstMatch(payload)?.start;
        if (start == null) continue;
        var depth = 0;
        var inString = false;
        var escaped = false;
        for (var i = start; i < payload.length; i++) {
          final char = payload[i];
          if (inString) {
            if (escaped) {
              escaped = false;
            } else if (char == r'\') {
              escaped = true;
            } else if (char == '"') {
              inString = false;
            }
          } else if (char == '"') {
            inString = true;
          } else if (char == '{') {
            depth++;
          } else if (char == '}' && --depth == 0) {
            final data = json.decode(payload.substring(start, i + 1)) as Map;
            final state = data['state'];
            final store = state is Map ? state['roomStore'] : null;
            final info = store is Map ? store['roomInfo'] : null;
            if (info is Map && info['room'] is Map) return state as Map;
            break;
          }
        }
      } on FormatException {
        // 页面可能包含多个数据块，继续查找有效的房间数据。
        continue;
      }
    }
    throw CoreError('抖音网页未返回有效直播间数据，可能需要验证或页面结构已变化');
  }

  Future<LiveSubCategory?> getRoomGameCategory(String webRid) async {
    final data = await _getRoomDataByHtml(webRid);
    final roadMap = data["roomStore"]?["roomInfo"]?["partition_road_map"];
    final parent = roadMap?["partition"];
    final game = roadMap?["sub_partition"]?["partition"];
    if (parent == null || game == null) return null;
    final gameId = game["id_str"]?.toString() ?? "";
    if (gameId.isEmpty) return null;
    return LiveSubCategory(
      id: '$gameId,${game["type"]}',
      parentId: '${parent["id_str"]},${parent["type"]}',
      name: game["title"]?.toString().isNotEmpty == true
          ? game["title"].toString()
          : parent["title"]?.toString() ?? "同类游戏",
    );
  }

  Uri _buildWebEnterUri(String webRid) {
    return Uri.parse("https://live.douyin.com/webcast/room/web/enter/").replace(
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
      },
    );
  }

  Future<Map> _loadWebEnterData(
    String url,
    Map<String, dynamic> requestHeaders,
  ) async {
    final result = await HttpClient.instance.getJson(
      url,
      header: requestHeaders,
    );
    final data = result is Map ? result['data'] : null;
    final rooms = data is Map ? data['data'] : null;
    if (rooms is! List || rooms.isEmpty || rooms.first is! Map) {
      throw const FormatException('抖音直播间接口未返回有效数据');
    }
    return data as Map;
  }

  /// 关注刷新专用轻量接口：只走签名 enter API，444/空响应时刷新访客会话并重签重试一次，
  /// 不回退重型 HTML 抓取、不做二次睡眠重试。
  Future<Map> _getFollowRoomDataByApi(String webRid) async {
    final requestHeader = {
      ...await getRequestHeaders(),
      "Referer": "https://live.douyin.com/$webRid",
    };
    final uri = _buildWebEnterUri(webRid);
    try {
      return await _loadWebEnterData(
        DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent),
        requestHeader,
      );
    } catch (error) {
      if (error is! FormatException &&
          !(error is CoreError && error.statusCode == 444)) {
        rethrow;
      }
      try {
        await _refreshVisitorCookie();
      } catch (refreshError) {
        CoreLog.error(refreshError);
      }
      final refreshedHeaders = {
        ...await getRequestHeaders(),
        'Referer': 'https://live.douyin.com/$webRid',
      };
      return _loadWebEnterData(
        DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent),
        refreshedHeaders,
      );
    }
  }

  /// 通过webRid获取直播间Web信息
  /// - [webRid] 直播间RID
  Future<Map> _getRoomDataByApi(String webRid) async {
    // 提前获取 headers
    var requestHeader = await getRequestHeaders();

    // 使用动态 Referer（包含房间号，参考 DouyinLiveRecorder）
    requestHeader["Referer"] = "https://live.douyin.com/$webRid";

    var uri = _buildWebEnterUri(webRid);
    var requestUrl = DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent);

    try {
      return await _loadWebEnterData(requestUrl, requestHeader);
    } catch (error) {
      if (error is! FormatException &&
          !(error is CoreError && error.statusCode == 444)) {
        rethrow;
      }
      // 空响应或 444 时更新访客会话，先尝试现有备用请求。
      try {
        await _refreshVisitorCookie();
      } catch (refreshError) {
        CoreLog.error(refreshError);
      }
      final refreshedHeaders = {
        ...await getRequestHeaders(),
        'Referer': 'https://live.douyin.com/$webRid',
      };
      try {
        return await _loadWebEnterData(uri.toString(), refreshedHeaders);
      } catch (fallbackError, stackTrace) {
        if (fallbackError is! FormatException &&
            !(fallbackError is CoreError && fallbackError.statusCode == 444)) {
          rethrow;
        }
        // 备用请求也被拒绝时，新会话重新签名一次，不复用失败的签名。
        try {
          return await _loadWebEnterData(
            DouyinSign.getAbogusUrl(uri.toString(), kDefaultUserAgent),
            refreshedHeaders,
          );
        } catch (signedError) {
          CoreLog.error(signedError);
          Error.throwWithStackTrace(fallbackError, stackTrace);
        }
      }
    }
  }

  /// 通过roomId获取直播间信息
  /// - [roomId] 直播间ID
  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: await getRequestHeaders(),
    );
    return result;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
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
            frameRate: metadataFrameRate(quality),
            data: urls,
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
          }
        }
      } else {
        var qualityData = json.decode(streamData)["data"] as Map;
        final streams =
            <String, ({LivePlayQuality quality, Set<String> urls, Map stream})>{};

        for (var quality in qulityList) {
          final key = quality["sdk_key"];
          final stream = qualityData[key];
          if (stream is! Map) continue;
          final urls = <String>{};
          // Try the alternate CDN before switching transports.
          for (final format in ['flv', 'hls']) {
            for (final route in ['main', 'backup']) {
              final endpoint = stream[route];
              final url = endpoint is Map ? endpoint[format] : null;
              if (url is! String) continue;
              final uri = Uri.tryParse(url);
              if (uri != null &&
                  uri.host.isNotEmpty &&
                  (uri.scheme == 'http' || uri.scheme == 'https')) {
                urls.add(url);
              }
            }
          }

          var qualityItem = LivePlayQuality(
            quality: quality["name"],
            sort: quality["level"],
            frameRate:
                metadataFrameRate(quality) ??
                _streamFrameRate(stream["main"]) ??
                _streamFrameRate(stream["backup"]),
            data: urls.toList(),
          );
          if (urls.isNotEmpty) {
            qualities.add(qualityItem);
            if (key is String) {
              streams[key] = (quality: qualityItem, urls: urls, stream: stream);
            }
          }
        }

        // 原画有时重复下发某个低档的全部地址。独立原画流始终保留。
        final original = streams['origin'];
        if (original != null) {
          for (final entry in streams.entries) {
            final alias = entry.value;
            if (entry.key == 'origin' ||
                alias.quality.sort >= original.quality.sort ||
                alias.urls.length != original.urls.length ||
                !alias.urls.containsAll(original.urls)) {
              continue;
            }
            var selected = alias;
            final originalPixels = _streamPixels(original.stream) ??
                _streamPixels(alias.stream);
            if (originalPixels != null) {
              var bestPixels = originalPixels;
              for (final candidate in streams.values) {
                if (candidate.urls.any(original.urls.contains)) continue;
                final pixels = _streamPixels(candidate.stream);
                if (pixels != null && pixels > bestPixels) {
                  bestPixels = pixels;
                  selected = candidate;
                }
              }
            }
            final index = qualities.indexOf(original.quality);
            qualities[index] = LivePlayQuality(
              quality: original.quality.quality,
              sort: original.quality.sort,
              frameRate: selected.quality.frameRate,
              data: LivePlayUrl(
                urls: selected.urls.toList(),
                actualQuality: selected.quality.quality,
              ),
            );
            break;
          }
        }
      }
    } catch (e) {
      CoreLog.error('抖音清晰度解析失败：${e.runtimeType}');
    }
    // var qualityData = json.decode(
    //     detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    _logDebug("获取到的画质列表: ${qualities.map((q) => q.quality).toList()}");
    return qualities;
  }

  double? _streamFrameRate(dynamic main) {
    final direct = metadataFrameRate(main);
    return direct ?? metadataFrameRate(_streamParams(main));
  }

  Map? _streamParams(dynamic route) {
    if (route is! Map) return null;
    final params = route['sdk_params'];
    try {
      final decoded = params is String ? json.decode(params) : params;
      return decoded is Map ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  int? _streamPixels(Map stream) {
    final size = _streamParams(stream['main'])?['resolution'] ??
        _streamParams(stream['backup'])?['resolution'];
    if (size is! String) return null;
    final match = RegExp(r'^(\d+)\s*[xX×]\s*(\d+)$').firstMatch(size.trim());
    if (match == null) return null;
    final width = int.tryParse(match[1]!) ?? 0;
    final height = int.tryParse(match[2]!) ?? 0;
    return width > 0 && height > 0 ? width * height : null;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    final data = quality.data;
    // 返回列表的副本，防止外部 clear() 影响原始数据
    return data is LivePlayUrl
        ? LivePlayUrl(urls: [...data.urls], actualQuality: data.actualQuality)
        : LivePlayUrl(urls: List<String>.from(data));
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
    var headResp = await HttpClient.instance.head(
      'https://live.douyin.com',
      header: headers,
    );
    var dyCookie = "";
    headResp.headers["set-cookie"]?.forEach((element) {
      var cookie = element.split(";")[0];
      if (cookie.contains("ttwid")) {
        dyCookie += "$cookie;";
      }
      if (cookie.contains("__ac_nonce")) {
        dyCookie += "$cookie;";
      }
    });

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

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    throw Exception("抖音暂不支持搜索主播，请直接搜索直播间");
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId);
    return result.status;
  }

  LiveFollowStatus _resolveDouyinFollowStatus({
    required bool isLive,
    required String resolvedRoomId,
    required int online,
    String? title,
    String? showTime,
    String? leafCategoryName,
    String? categoryId,
    String? parentCategoryName,
  }) {
    if (!isLive) {
      return LiveFollowStatus(
        isLive: false,
        resolvedRoomId: resolvedRoomId,
        needsDetailFallback: false,
      );
    }
    final trimmedLeaf = leafCategoryName?.trim();
    if (trimmedLeaf != null && trimmedLeaf.isNotEmpty && trimmedLeaf != '游戏') {
      return LiveFollowStatus(
        isLive: true,
        resolvedRoomId: resolvedRoomId,
        online: online > 0 ? online : null,
        categoryName: trimmedLeaf,
        showTime: showTime,
        title: title,
        categoryId: categoryId,
        parentCategoryName: parentCategoryName,
        needsDetailFallback: false,
      );
    }
    if (categoryId != null && _webPartitionNames.containsKey(categoryId)) {
      final cached = _webPartitionNames[categoryId]!;
      final resolved = cached != '游戏'
          ? cached
          : ((parentCategoryName?.trim().isNotEmpty == true)
              ? parentCategoryName!.trim()
              : '其他');
      return LiveFollowStatus(
        isLive: true,
        resolvedRoomId: resolvedRoomId,
        online: online > 0 ? online : null,
        categoryName: resolved,
        showTime: showTime,
        title: title,
        categoryId: categoryId,
        parentCategoryName: parentCategoryName,
        needsDetailFallback: false,
      );
    }
    if (categoryId == null) {
      final fallback =
          (parentCategoryName?.trim().isNotEmpty == true)
              ? parentCategoryName!.trim()
              : '其他';
      return LiveFollowStatus(
        isLive: true,
        resolvedRoomId: resolvedRoomId,
        online: online > 0 ? online : null,
        categoryName: fallback,
        showTime: showTime,
        title: title,
        needsDetailFallback: false,
      );
    }
    // 命中“游戏”且尚未加载网页分类映射时，只做轻量的二级分类查表，不再重拉房间详情。
    return LiveFollowStatus(
      isLive: true,
      resolvedRoomId: resolvedRoomId,
      online: online > 0 ? online : null,
      showTime: showTime,
      title: title,
      categoryId: categoryId,
      parentCategoryName: parentCategoryName,
      needsDetailFallback: true,
    );
  }

  LiveFollowStatus _buildFollowStatusFromRoom({
    required String webRid,
    required bool isLive,
    required Map room,
    required Map? webPartition,
    required Map? context,
  }) {
    final onlineVal =
        int.tryParse('${room['room_view_stats']?['display_value']}') ?? 0;
    return _resolveDouyinFollowStatus(
      isLive: isLive,
      resolvedRoomId: webRid,
      online: onlineVal,
      title: room['title']?.toString(),
      leafCategoryName: firstCategoryName([webPartition?['title']]),
      categoryId: douyinWebPartitionId(webPartition),
      parentCategoryName: douyinWebParentCategoryName(room, context),
    );
  }

  @override
  Future<LiveFollowStatus> getFollowStatus({required String roomId}) async {
    if (runtimeType != DouyinSite) {
      final detail = await getRoomDetail(roomId: roomId);
      return _resolveDouyinFollowStatus(
        isLive: detail.status,
        resolvedRoomId: detail.roomId,
        online: detail.online,
        title: detail.title,
        showTime: detail.showTime,
        leafCategoryName: detail.leafCategoryName,
        categoryId: detail.categoryId,
        parentCategoryName: detail.webParentCategoryName,
      );
    }
    Map data;
    if (roomId.length > 16) {
      final reflow = await _getRoomDataByRoomId(roomId);
      final room = reflow['data']?['room'];
      if (room is! Map) throw StateError('抖音房间未返回数据');
      final webRid = room['owner']?['web_rid']?.toString() ?? roomId;
      final status = int.tryParse(room['status']?.toString() ?? '');
      if (status == null) throw StateError('抖音房间未返回直播状态');
      if (status == 4) {
        data = await _getFollowRoomDataByApi(webRid);
      } else {
        final context = reflow['data'] is Map ? reflow['data'] as Map : null;
        return _buildFollowStatusFromRoom(
          webRid: webRid,
          isLive: status == 2,
          room: room,
          webPartition: douyinWebPartition(room, context),
          context: context,
        );
      }
      final rooms = data['data'];
      final roomData = rooms is List && rooms.isNotEmpty ? rooms.first : null;
      if (roomData is! Map) throw StateError('抖音房间未返回直播数据');
      final nextStatus = int.tryParse(roomData['status']?.toString() ?? '');
      if (nextStatus == null) throw StateError('抖音房间未返回直播状态');
      return _buildFollowStatusFromRoom(
        webRid: webRid,
        isLive: nextStatus == 2,
        room: roomData,
        webPartition: douyinWebPartition(roomData, data),
        context: data,
      );
    }
    data = await _getFollowRoomDataByApi(roomId);
    final rooms = data['data'];
    final roomData = rooms is List && rooms.isNotEmpty ? rooms.first : null;
    if (roomData is! Map) throw StateError('抖音房间未返回直播数据');
    final status = int.tryParse(roomData['status']?.toString() ?? '');
    if (status == null) throw StateError('抖音房间未返回直播状态');
    return _buildFollowStatusFromRoom(
      webRid: roomId,
      isLive: status == 2,
      room: roomData,
      webPartition: douyinWebPartition(roomData, data),
      context: data,
    );
  }

  @override
  bool get supportsFollowStatusBatch => false;

  @override
  Future<Map<String, LiveFollowStatus>> getFollowStatusBatch({
    required List<String> roomIds,
  }) async {
    return const {};
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({
    required String roomId,
  }) {
    return Future.value(<LiveSuperChatMessage>[]);
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
