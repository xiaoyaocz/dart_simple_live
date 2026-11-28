import 'dart:convert';
import 'package:dio/dio.dart';
import '../common/http_client.dart';
import '../model/live_emoticon.dart';
import 'bilibili_danmaku.dart';
import 'huya_danmaku.dart';
import 'huya_emoticons.dart';
import 'emoticon_parser.dart';

class PlatformEmoticons {
  final Dio dio;
  PlatformEmoticons({Dio? dio}) : dio = dio ?? HttpClient.instance.dio;

  Future<List<LiveEmoticon>> load(
    String platform,
    String roomId, {
    dynamic args,
    CancelToken? cancel,
  }) async {
    final options = Options(
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
      headers: {'User-Agent': 'Mozilla/5.0'},
    );
    dynamic data;
    switch (platform) {
      case 'douyin':
        options.headers!['Referer'] = 'https://live.douyin.com/';
        data = (await dio.get(
          'https://live.douyin.com/aweme/v1/web/emoji/list',
          queryParameters: {'aid': 6383, 'device_platform': 'web'},
          options: options,
          cancelToken: cancel,
        )).data;
        return _notEmpty(parseDouyin(_json(data)));
      case 'douyu':
        options.responseType = ResponseType.plain;
        options.headers!['Referer'] = 'https://m.douyu.com/';
        data = (await dio.get(
          'https://m.douyu.com/${Uri.encodeComponent(roomId)}',
          options: options,
          cancelToken: cancel,
        )).data;
        return _notEmpty(parseDouyuPage('$data'));
      case 'bilibili':
        options.headers!['Referer'] = 'https://live.bilibili.com/';
        if (args is BiliBiliDanmakuArgs && args.cookie.isNotEmpty)
          options.headers!['Cookie'] = args.cookie;
        data = _json(
          (await dio.get(
            'https://api.live.bilibili.com/xlive/web-ucenter/v2/emoticon/GetEmoticons',
            queryParameters: {'platform': 'pc', 'room_id': roomId},
            options: options,
            cancelToken: cancel,
          )).data,
        );
        if (data is! Map || data['code'] != 0) throw StateError('B站表情目录暂不可用');
        return _notEmpty(parseBilibili(data));
      case 'huya':
        return _notEmpty(
          await HuyaEmoticons.load(
            dio,
            args is HuyaDanmakuArgs ? args.ayyuid : int.tryParse(roomId) ?? 0,
            cancel: cancel,
          ),
        );
      default:
        return [];
    }
  }

  static dynamic _json(dynamic data) =>
      data is String ? jsonDecode(data) : data;
  static List<LiveEmoticon> _notEmpty(Iterable<LiveEmoticon> values) {
    final result = values.toList(growable: false);
    if (result.isEmpty) throw StateError('平台未返回可用表情');
    return result;
  }

  static Iterable<LiveEmoticon> parseDouyin(dynamic data) sync* {
    if (data is! Map || data['emoji_list'] is! List) return;
    for (final entry in data['emoji_list']) {
      if (entry is! Map || entry['display_name'] is! String) continue;
      final image = entry['emoji_url'];
      if (image is! Map || image['url_list'] is! List) continue;
      final url = (image['url_list'] as List)
          .map(LiveEmoticon.normalizeUrl)
          .whereType<String>()
          .firstOrNull;
      if (url != null)
        yield LiveEmoticon(text: entry['display_name'], url: url);
    }
  }

  static Iterable<LiveEmoticon> parseBilibili(dynamic data) sync* {
    if (data is! Map) return;
    dynamic groups = data['data'];
    if (groups is Map) groups = groups['data'] ?? groups['emoticon'];
    if (groups is Map) groups = groups.values.toList();
    if (groups is! List) return;
    for (final group in groups) {
      if (group is! Map || group['emoticons'] is! List) continue;
      for (final item in group['emoticons']) {
        if (item is! Map || item['emoji'] is! String) continue;
        final image = EmoticonParser.image(item['emoji'], item);
        if (image != null) yield image;
      }
    }
  }

  static Iterable<LiveEmoticon> parseDouyuPage(String html) sync* {
    final match = RegExp(
      r'''<script\b[^>]*\bid=["']vike_pageContext["'][^>]*>([\s\S]*?)</script>''',
    ).firstMatch(html);
    if (match == null) return;
    final data = jsonDecode(match.group(1)!);
    final info = data['pageProps']?['room']?['faceInfo'];
    if (info is! Map) return;
    if (info['faceConfig'] is List) {
      for (final entry in info['faceConfig']) {
        if (entry is! Map || entry['title'] is! String) continue;
        final title = entry['title'];
        final url = LiveEmoticon.normalizeUrl(entry['url1'] ?? entry['url']);
        if (url == null) continue;
        for (final token in ['[$title]', '[emot:dy$title]'])
          yield LiveEmoticon(text: token, url: url);
      }
    }
    if (info['genDanmuConfig'] is List) {
      for (final entry in info['genDanmuConfig']) {
        if (entry is! Map || entry['msgId'] == null) continue;
        final image = EmoticonParser.image('[gag:${entry['msgId']}]', {
          'url': entry['webPic'],
          'width': entry['webPicWidth'],
          'height': entry['webPicHeight'],
        });
        if (image != null) yield image;
      }
    }
  }
}
