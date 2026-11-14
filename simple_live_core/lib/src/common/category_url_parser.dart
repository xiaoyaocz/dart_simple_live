import '../douyin_site.dart';
import 'live_url_parser.dart';

/// 平台分区链接解析结果。
class CategoryParsedUrl {
  final String siteId;
  final String categoryId;
  final String parentId;
  final String nameHint;
  final bool needsHtmlFetch;
  final String? hintMessage;
  final Uri uri;

  const CategoryParsedUrl({
    required this.siteId,
    required this.uri,
    this.categoryId = '',
    this.parentId = '',
    this.nameHint = '',
    this.needsHtmlFetch = false,
    this.hintMessage,
  });

  bool get hasCategoryId => categoryId.isNotEmpty;
}

/// 直播平台分区网页链接解析器。
class CategoryUrlParser {
  static final RegExp _numericPattern = RegExp(r'^\d+$');

  /// 解析平台分区网页链接，无法识别时返回 null。
  static CategoryParsedUrl? parse(String value) {
    final uri = _parseUri(value);
    if (uri == null) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 抖音：live.douyin.com/categorynew/4_103_1_2_1_1010016 或 live.douyin.com/category/1_1010016
    if (host == 'live.douyin.com' &&
        segments.length >= 2 &&
        (segments[0] == 'categorynew' || segments[0] == 'category')) {
      final rawToken = segments[1];
      final normalized = DouyinSite.normalizeCategoryId(rawToken);
      if (normalized.isEmpty) {
        return null;
      }
      final parts = rawToken
          .split('_')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      var parentId = '';
      if (parts.length >= 4 &&
          _numericPattern.hasMatch(parts[0]) &&
          _numericPattern.hasMatch(parts[1])) {
        parentId = '${parts[1]},${parts[0]}';
      }
      return CategoryParsedUrl(
        siteId: LiveUrlParser.siteDouyin,
        uri: uri,
        categoryId: normalized,
        parentId: parentId,
      );
    }

    // B站：live.bilibili.com/p/eden/area-tags?parentAreaId=2&areaId=235
    if (host == 'live.bilibili.com') {
      // 仅接受分区页路径，避免携带 areaId 参数的房间链接被误判为分区链接
      final path = uri.path.toLowerCase();
      if (path != '/p/eden/area-tags' &&
          !path.startsWith('/p/eden/area-tags/')) {
        return null;
      }
      final areaId = (uri.queryParameters['areaId'] ?? '').trim();
      final parentAreaId = (uri.queryParameters['parentAreaId'] ?? '').trim();
      if (_numericPattern.hasMatch(areaId)) {
        return CategoryParsedUrl(
          siteId: LiveUrlParser.siteBilibili,
          uri: uri,
          categoryId: areaId,
          parentId: _numericPattern.hasMatch(parentAreaId) ? parentAreaId : '',
        );
      }
      return null;
    }

    // 虎牙：www.huya.com/g/4079 或 www.huya.com/g/lol
    if ((host == 'huya.com' || host.endsWith('.huya.com')) &&
        segments.length >= 2 &&
        segments[0] == 'g') {
      final slugOrId = segments[1];
      if (_numericPattern.hasMatch(slugOrId)) {
        return CategoryParsedUrl(
          siteId: LiveUrlParser.siteHuya,
          uri: uri,
          categoryId: slugOrId,
        );
      }
      return CategoryParsedUrl(
        siteId: LiveUrlParser.siteHuya,
        uri: uri,
        needsHtmlFetch: true,
      );
    }

    // 斗鱼：www.douyu.com/g_LOL 或 directory/game/LOL（仅含英文别名，无数字 cate2Id）
    if ((host == 'douyu.com' || host.endsWith('.douyu.com')) &&
        segments.isNotEmpty &&
        (segments[0].startsWith('g_') ||
            (segments.length >= 3 &&
                segments[0] == 'directory' &&
                segments[1] == 'game'))) {
      return CategoryParsedUrl(
        siteId: LiveUrlParser.siteDouyu,
        uri: uri,
        hintMessage: '斗鱼分区链接不含数字 ID，请进入该分区任一直播间菜单点击「添加到自定义分区」，或手动填入 cate2Id',
      );
    }

    return null;
  }

  /// 从抖音分区页 SSR HTML 提取推荐游戏/分区标题（优先 `game_tag`）。
  // ponytail: regex over unescaped SSR HTML; avoids full HTML DOM dependency
  static String? extractDouyinCategoryTitleFromHtml(String html) {
    final normalized = html.replaceAll(r'\"', '"');
    final gameTagMatch = RegExp(
      r'"game_tag"\s*:\s*"([^"\\]{1,60})"',
    ).firstMatch(normalized);
    final gameTag = gameTagMatch?.group(1)?.trim() ?? '';
    if (gameTag.isNotEmpty) {
      return gameTag;
    }
    final partitionTitleMatch = RegExp(
      r'"partition_title"\s*:\s*"([^"\\]{1,60})"',
    ).firstMatch(normalized);
    final partitionTitle = partitionTitleMatch?.group(1)?.trim() ?? '';
    if (partitionTitle.isNotEmpty) {
      return partitionTitle;
    }
    return _extractCleanHtmlTitle(html, const ['抖音直播']);
  }

  /// 从虎牙分区页 HTML 提取 `GID` 与名称提示。
  static ({String id, String? name})? extractHuyaCategoryFromHtml(String html) {
    final gidMatch = RegExp(r'''\bGID\s*=\s*['"](\d+)['"]''').firstMatch(html);
    final gid = gidMatch?.group(1)?.trim() ?? '';
    if (gid.isEmpty) {
      return null;
    }
    final altMatch = RegExp(
      'gid_$gid\\.[^"]*?"[^>]*alt="([^"]+)"',
    ).firstMatch(html);
    var name = (altMatch?.group(1) ?? '').trim();
    if (name.endsWith('直播') && name.length > 2) {
      name = name.substring(0, name.length - 2).trim();
    }
    if (name.isEmpty) {
      name = _extractCleanHtmlTitle(html, const ['虎牙直播']) ?? '';
    }
    if (name.contains('_')) {
      name = name.split('_').first.trim();
    }
    if (name.endsWith('直播') && name.length > 2) {
      name = name.substring(0, name.length - 2).trim();
    }
    return (id: gid, name: name.isEmpty ? null : name);
  }

  static String? _extractCleanHtmlTitle(String html, List<String> suffixes) {
    final titleMatch = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    var title = (titleMatch?.group(1) ?? '').trim();
    if (title.isEmpty) {
      return null;
    }
    for (final suffix in suffixes) {
      title = title
          .replaceAll(RegExp('[_\\-\\s]*${RegExp.escape(suffix)}.*\$'), '')
          .trim();
    }
    if (title.endsWith('直播') && title.length > 2) {
      title = title.substring(0, title.length - 2).trim();
    }
    if (title.isEmpty || suffixes.contains(title)) {
      return null;
    }
    return title;
  }

  static Uri? _parseUri(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
