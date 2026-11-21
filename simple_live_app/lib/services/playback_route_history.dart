/// 当前会话内的线路表现；不保存签名 URL，不探测/下载额外视频流。
class PlaybackRouteHistory {
  PlaybackRouteHistory({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static final instance = PlaybackRouteHistory();
  final DateTime Function() _now;
  final _routes = <(String, String, String), _RouteSample>{};

  (String, String, String)? _key(String site, String quality, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        !uri.path.toLowerCase().endsWith('.flv')) {
      return null;
    }
    return (site, quality, uri.origin);
  }

  void _prune() {
    _routes.removeWhere((_, sample) =>
        _now().difference(sample.at) >= const Duration(minutes: 15));
  }

  void _save((String, String, String) key, _RouteSample value) {
    _prune();
    _routes.remove(key);
    if (_routes.length >= 64) _routes.remove(_routes.keys.first);
    _routes[key] = value;
  }

  void success(String site, String quality, String url, Duration elapsed) {
    final key = _key(site, quality, url);
    if (key == null || elapsed <= Duration.zero) return;
    _prune();
    final old = _routes[key]?.milliseconds;
    final ms = elapsed.inMicroseconds / 1000;
    _save(
        key,
        _RouteSample(_now(), old == null ? ms : old * 0.7 + ms * 0.3,
            stallPenalty: _routes[key]?.stallPenalty ?? 0));
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
        _RouteSample(_now(), old?.milliseconds,
            blockedUntil: old?.blockedUntil, stallPenalty: penalty));
  }

  void failure(String site, String quality, String url) {
    final key = _key(site, quality, url);
    if (key == null) return;
    _prune();
    _save(
        key,
        _RouteSample(_now(), _routes[key]?.milliseconds,
            blockedUntil: _now().add(const Duration(minutes: 2)),
            stallPenalty: _routes[key]?.stallPenalty ?? 0));
  }

  /// 只在当前同画质、同协议的 FLV 备用 CDN 中选择，不触碰 HLS 档位。
  int select(String site, String quality, List<String> urls) {
    if (urls.isEmpty) return -1;
    _prune();
    if (_key(site, quality, urls.first) == null) return 0;
    final scheme = Uri.parse(urls.first).scheme;
    final streamFile = Uri.parse(urls.first).pathSegments.last;
    var selected = 0;
    var best = double.infinity;
    for (var i = 0; i < urls.length; i++) {
      final key = _key(site, quality, urls[i]);
      if (key == null) continue;
      final uri = Uri.parse(urls[i]);
      // 备用编码通常使用不同文件名；不让线路优选把 AVC 换成 HEVC。
      if (uri.scheme != scheme || uri.pathSegments.last != streamFile) {
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
  const _RouteSample(this.at, this.milliseconds,
      {this.blockedUntil, this.stallPenalty = 0});
}
