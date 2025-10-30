import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/platforms/twitch/models.dart';

class TwitchSite implements LiveSite {
  @override
  String id = 'twitch';

  @override
  String name = 'Twitch';

  var _playUrlList = <String>[];

  static const defaultUa =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";
  static const gplApiUrl = "https://gql.twitch.tv/gql";

  static const baseUrl = "https://www.twitch.tv";

  Map<String, dynamic> headers = {
    'user-agent': defaultUa,
    'accept-language': 'en-US,en;q=0.9',
    'accept': 'application/vnd.twitchtv.v5+json',
    'accept-encoding': 'gzip, deflate',
    'client-id': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
  };

  final playSessionIds = [
    "bdd22331a986c7f1073628f2fc5b19da",
    "064bc3ff1722b6f53b0b5b8c01e46ca5"
  ];

  void getRequestHeaders() {
    headers['device-id'] = getDeviceId();
    // no token
    // no cookie
  }

  // 生成设备id
  String getDeviceId() {
    final random = Random();
    final deviceId = 1000000000000000 + random.nextInt(1 << 32);
    return deviceId.toString();
  }

  String buildPersistedRequest(
      String operationName, String sha265Hash, Map<String, dynamic> variables) {
    final variablesJson = jsonEncode(variables);
    final query = '''
     {
       "operationName": "$operationName",
       "extensions": {
         "persistedQuery": {
           "version": 1,
           "sha256Hash": "$sha265Hash"
         }
       },
       "variables": $variablesJson
     }
     ''';
    return query.trim();
  }

  @override
  Future<List<LiveCategory>> getCategores() {
    //尚不支持
    return Future.value([]);
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) {
    //尚不支持
    return Future.value(LiveCategoryResult(hasMore: false, items: []));
  }

  @override
  LiveDanmaku getDanmaku() {
    throw Exception("twitch暂不支持弹幕");
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var detail = await getRoomDetail(roomId: roomId);
    var status = detail.status;
    return status;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoomDetail detail}) async {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    var liveGpl = buildPersistedRequest(
      "PlaybackAccessToken",
      "0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712",
      {
        "isLive": true,
        "login": detail.roomId,
        "isVod": false,
        "vodID": "",
        "playerType": "site",
        "isClip": false,
        "clipID": ""
      },
    );
    var response = await HttpClient.instance.postJson(
      gplApiUrl,
      header: headers,
      data: liveGpl,
    );
    var token = response['data']['streamPlaybackAccessToken']['value'];
    var sign = response['data']['streamPlaybackAccessToken']['signature'];
    var anchorName = detail.userName;
    var liveStatus = detail.status;
    if (liveStatus) {
      // 随机选择一个sessionId
      var random = Random();
      var playSessionId = playSessionIds[random.nextInt(playSessionIds.length)];
      var epochSecondsStr = DateTime.timestamp().second.toString();
      var params = {
        "acmb": "e30=",
        "allow_source": "true",
        "cdm": "wv",
        "fast_bread": "true",
        "p": epochSecondsStr,
        "platform": "web",
        "play_session_id": playSessionId,
        "player_backend": "mediaplayer",
        "player_version": "1.28.0-rc.1",
        "playlist_include_framerate": "true",
        "reassignments_supported": "true",
        "sig": sign,
        "token": token,
        "transcode_mode": "cbr_v1"
      };
      var m3u8Url =
          "https://usher.ttvnw.net/api/channel/hls/${detail.roomId}.m3u8";
      var content = await HttpClient.instance.getText(
        m3u8Url,
        queryParameters: params,
        header: headers,
      );
      // 这里需要一个 m3u8解析器
      _playUrlList.clear(); // 重置
      final lines = content.split("\n");

      for (var i in lines) {
        if (i.startsWith("https://")) {
          _playUrlList.add(i.trim());
        }
      }

      if (_playUrlList.isEmpty) {
        for (final i in lines) {
          if (i.trim().endsWith('m3u8')) {
            _playUrlList.add(i.trim());
          }
        }
      }
      // 匹配带宽信息
      final bandwidthPattern = RegExp(r'BANDWIDTH=(\d+)');
      final bandwidthList = bandwidthPattern
          .allMatches(content)
          .map((match) => match.group(1)!)
          .toList();
      // 映射
      final urlToBandwidth = <String, int>{};
      for (int i = 0; i < _playUrlList.length; i++) {
        final bandwidth =
            i < bandwidthList.length ? int.parse(bandwidthList[i]) : 0;
        urlToBandwidth[_playUrlList[i]] = bandwidth;
      }
      _playUrlList
          .sort((a, b) => urlToBandwidth[b]!.compareTo(urlToBandwidth[a]!));

      qualities = _playUrlList.map((url) {
        final bandwidth = urlToBandwidth[url] ?? 0;
        return LivePlayQuality(
          quality: _getQualityName(bandwidth),
          data: url, // 这里data直接存储播放URL
          sort: bandwidth,
        );
      }).toList();
    }
    return qualities;
  }

  // twitch的清晰度转换
  String _getQualityName(int bandwidth) {
    if (bandwidth > 5000000) return '1080P';
    if (bandwidth > 2500000) return '720P';
    if (bandwidth > 1000000) return '480P';
    if (bandwidth > 500000) return '360P';
    return '自动';
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    return LivePlayUrl(
      urls: _playUrlList,
    );
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var roomInfo = await _getRoomInfo(roomId);
    var channelShell = roomInfo.first;
    var streamMetaData = roomInfo[1];

    final userOrError = channelShell.data.userOrError;
    if (userOrError == null) {
      final error = channelShell.data.userOrError;
      if (error?.typename == 'UserNotFoundError') {
        CoreLog.e('User not found: ${error?.displayName}', StackTrace.empty);
        throw Exception('Could not find user_or_error');
      }
    }
    var user = streamMetaData.data.user;
    if (user == null) {
      CoreLog.e(
          'User not found: ${userOrError?.displayName}', StackTrace.empty);
      throw Exception('Could not find user');
    }
    bool online = switch (user.stream) {
      Stream stream when stream.streamType == 'live' => true,
      _ => false,
    };
    var title = user.lastBroadcast?.title ?? "null";
    return LiveRoomDetail(
        roomId: roomId,
        title: title,
        cover: user.profileImageUrl,
        userName: userOrError!.displayName,
        userAvatar: user.profileImageUrl,
        online: online ? user.stream!.viewersCount : 0,
        status: online,
        url: "$baseUrl/$roomId",
        introduction: "",
        notice: "",
        danmakuData: null,
        data: null);
  }

  Future<List<TwitchResponse>> _getRoomInfo(String roomId) async {
    var queries = [
      buildPersistedRequest(
        "ChannelShell",
        "c3ea5a669ec074a58df5c11ce3c27093fa38534c94286dc14b68a25d5adcbf55",
        {
          "login": roomId,
          "lcpVideosEnabled": false,
        },
      ),
      buildPersistedRequest(
        "StreamMetadata",
        "059c4653b788f5bdb2f5a2d2a24b0ddc3831a15079001a3d927556a96fb0517f",
        {
          "channelLogin": roomId,
          "previewImageURL": "",
        },
      )
    ];
    String requestQuery = "[${queries.map((q) => q.toString()).join(',')}]";
    CoreLog.i("twitch-queries:$requestQuery");
    getRequestHeaders();
    var response = await HttpClient.instance.postJson(
      gplApiUrl,
      header: headers,
      data: requestQuery,
    );
    CoreLog.d("twitch-response:$response");

    final List<dynamic> decoded = response;
    final responses = decoded
        .map((item) => TwitchResponse.fromJson(item as Map<String, dynamic>))
        .toList();
    if (responses.length < 2) {
      CoreLog.error('Invalid response from Twitch API');
    }
    return responses;
  }

  // gql 查询demo
  Future<List<dynamic>> _post_gql({required String body}) async {
    getRequestHeaders();
    var response = await HttpClient.instance.postJson(
      gplApiUrl,
      header: headers,
      data: body,
    );
    CoreLog.d("twitch-response:$response");

    final List<dynamic> decoded = jsonDecode(response);
    final responses = decoded
        .map((item) => TwitchResponse.fromJson(item as Map<String, dynamic>))
        .toList();
    return responses;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    //尚不支持
    return Future.value([]);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) {
    throw Exception("twitch暂不支持搜索主播");
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) {
    throw Exception("twitch暂不支持搜索房间");
  }
}
