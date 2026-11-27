import 'dart:async';
import 'dart:convert';

/// 线路表现记忆；仅保存平台、画质、协议与节点 origin，不保存签名 URL。
class PlaybackRouteHistory {
  PlaybackRouteHistory({
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 15),
    this.saveDebounce = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  static final instance = PlaybackRouteHistory();

  final DateTime Function() _now;
  final Duration ttl;
  final Duration saveDebounce;
  final _routes = <(String, String, String, String), _RouteSample>{};

  Future<void> Function(String json)? _persistWriter;
  Timer? _saveTimer;

  /// 绑定本地持久化：立即导入有效历史记录，后续变更防抖落盘。
  void attachPersistence({
    required String? Function() read,
    required Future<void> Function(String json) write,
  }) {
    _persistWriter = write;
    try {
      final raw = read();
      if (raw != null && raw.trim().isNotEmpty) {
        importJson(raw);
      }
    } catch (_) {}
  }

  /// 立即将当前线路历史写入持久化介质（如测试或退出前）。
  Future<void> flushPersistence() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final writer = _persistWriter;
    if (writer == null) return;
    _prune();
    try {
      await writer(exportJson());
    } catch (_) {}
  }

  void _scheduleSave() {
    if (_persistWriter == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounce, () {
      _saveTimer = null;
      unawaited(flushPersistence());
    });
  }

  String exportJson() {
    _prune();
    final items = <Map<String, dynamic>>[];
    for (final entry in _routes.entries) {
      final (site, quality, origin, ext) = entry.key;
      final sample = entry.value;
      items.add({
        's': site,
        'q': quality,
        'o': origin,
        'e': ext,
        'at': sample.at.millisecondsSinceEpoch,
        if (sample.milliseconds != null) 'ms': sample.milliseconds,
        if (sample.blockedUntil != null)
          'bu': sample.blockedUntil!.millisecondsSinceEpoch,
        if (sample.stallPenalty > 0) 'sp': sample.stallPenalty,
      });
    }
    return jsonEncode({'v': 1, 'routes': items});
  }

  void importJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final list = decoded['routes'];
      if (list is! List) return;
      final now = _now();
      for (final item in list) {
        if (item is! Map) continue;
        final site = item['s']?.toString() ?? '';
        final quality = item['q']?.toString() ?? '';
        final origin = item['o']?.toString() ?? '';
        final ext = item['e']?.toString() ?? '.flv';
        final atMs = item['at'];
        if (site.isEmpty ||
            quality.isEmpty ||
            origin.isEmpty ||
            (ext != '.flv' && ext != '.m3u8') ||
            atMs is! int) {
          continue;
        }
        final at = DateTime.fromMillisecondsSinceEpoch(atMs);
        if (now.difference(at) >= ttl) continue;
        final msRaw = item['ms'];
        final ms = msRaw is num ? msRaw.toDouble() : null;
        final buRaw = item['bu'];
        final bu = buRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(buRaw)
            : null;
        final spRaw = item['sp'];
        final sp = spRaw is num ? spRaw.toInt().clamp(0, 12000) : 0;
        final key = (site, quality, origin, ext);
        if (_routes.length >= 64 && !_routes.containsKey(key)) {
          _routes.remove(_routes.keys.first);
        }
        _routes[key] = _RouteSample(
          at,
          ms,
          blockedUntil: bu,
          stallPenalty: sp,
        );
      }
      _prune();
    } catch (_) {}
  }

  static String? _streamExt(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.flv')) return '.flv';
    if (path.endsWith('.m3u8')) return '.m3u8';
    return null;
  }

  (String, String, String, String)? _key(
      String site, String quality, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final ext = _streamExt(uri);
    if (ext == null) return null;
    return (site, quality, uri.origin, ext);
  }

  void _prune() {
    _routes.removeWhere((_, sample) => _now().difference(sample.at) >= ttl);
  }

  void _save((String, String, String, String) key, _RouteSample value) {
    _prune();
    _routes.remove(key);
    if (_routes.length >= 64) _routes.remove(_routes.keys.first);
    _routes[key] = value;
    _scheduleSave();
  }

  void success(String site, String quality, String url, Duration elapsed) {
    final key = _key(site, quality, url);
    if (key == null || elapsed <= Duration.zero) return;
    _prune();
    final old = _routes[key]?.milliseconds;
    final ms = elapsed.inMicroseconds / 1000;
    _save(
      key,
      _RouteSample(
        _now(),
        old == null ? ms : old * 0.7 + ms * 0.3,
        stallPenalty: _routes[key]?.stallPenalty ?? 0,
      ),
    );
  }

  /// Count sustained rebuffering after playback starts, independently of speed.
  void rebuffer(String site, String quality, String url, Duration elapsed) {
    if (elapsed < const Duration(milliseconds: 1500)) return;
    final key = _key(site, quality, url);
    if (key == null) return;
    _prune();
    final old = _routes[key];
    final penalty = ((old?.stallPenalty ?? 0) + elapsed.inMilliseconds)
        .clamp(0, 12000)
        .toInt();
    _save(
      key,
      _RouteSample(
        _now(),
        old?.milliseconds,
        blockedUntil: old?.blockedUntil,
        stallPenalty: penalty,
      ),
    );
  }

  void failure(String site, String quality, String url) {
    final key = _key(site, quality, url);
    if (key == null) return;
    _prune();
    _save(
      key,
      _RouteSample(
        _now(),
        _routes[key]?.milliseconds,
        blockedUntil: _now().add(const Duration(minutes: 2)),
        stallPenalty: _routes[key]?.stallPenalty ?? 0,
      ),
    );
  }

  /// 是否已存在经过验证且未被熔断的同协议/同文件名候选线路（存在则无需再次并发测速）。
  bool hasProvenRoute(String site, String quality, List<String> urls) {
    if (urls.isEmpty) return false;
    _prune();
    final firstKey = _key(site, quality, urls.first);
    if (firstKey == null) return false;
    final firstUri = Uri.parse(urls.first);
    if (firstUri.pathSegments.isEmpty) return false;
    final scheme = firstUri.scheme;
    final streamFile = firstUri.pathSegments.last;
    final ext = firstKey.$4;
    for (final url in urls) {
      final key = _key(site, quality, url);
      if (key == null || key.$4 != ext) continue;
      final uri = Uri.parse(url);
      if (uri.scheme != scheme ||
          uri.pathSegments.isEmpty ||
          uri.pathSegments.last != streamFile) {
        continue;
      }
      final sample = _routes[key];
      if (sample != null &&
          sample.milliseconds != null &&
          !(sample.blockedUntil?.isAfter(_now()) ?? false)) {
        return true;
      }
    }
    return false;
  }

  /// 只在当前同画质、同协议、同文件名的 FLV 或 HLS 备用 CDN 中选择，不跨协议或跨编码切换。
  int select(String site, String quality, List<String> urls) {
    if (urls.isEmpty) return -1;
    _prune();
    final firstKey = _key(site, quality, urls.first);
    if (firstKey == null) return 0;
    final firstUri = Uri.parse(urls.first);
    if (firstUri.pathSegments.isEmpty) return 0;
    final scheme = firstUri.scheme;
    final streamFile = firstUri.pathSegments.last;
    final ext = firstKey.$4;
    var selected = 0;
    var best = double.infinity;
    for (var i = 0; i < urls.length; i++) {
      final key = _key(site, quality, urls[i]);
      if (key == null || key.$4 != ext) continue;
      final uri = Uri.parse(urls[i]);
      // 备用编码通常使用不同文件名；不让线路优选把 AVC 换成 HEVC，也不跨协议替换。
      if (uri.scheme != scheme ||
          uri.pathSegments.isEmpty ||
          uri.pathSegments.last != streamFile) {
        continue;
      }
      final sample = _routes[key];
      if (sample?.blockedUntil?.isAfter(_now()) ?? false) continue;
      // 未测过的线路不主动抢在已经验证的线路前；相同结果保留平台顺序。
      final score =
          (sample?.milliseconds ?? 100000) + (sample?.stallPenalty ?? 0);
      if (score < best) {
        best = score;
        selected = i;
      }
    }
    return selected;
  }
}

class _RouteSample {
  final DateTime at;
  final double? milliseconds;
  final DateTime? blockedUntil;
  final int stallPenalty;
  const _RouteSample(
    this.at,
    this.milliseconds, {
    this.blockedUntil,
    this.stallPenalty = 0,
  });
}
