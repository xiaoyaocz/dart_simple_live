import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// Room-scoped: an old network response can never overwrite a new room's map.
class RoomEmoticons extends ChangeNotifier {
  // Identity keys avoid retaining every message for the room's entire lifetime.
  // LRU lookups and eviction are O(1); catalog changes invalidate stale tokens.
  final _resolved =
      LinkedHashMap<LiveMessage, List<LiveMessagePart>>.identity();
  final EmoticonCatalog _catalog;
  final String _platform;
  String get platform => _platform;
  final _sendTokens = <String, String>{};
  final _entries = <String, LiveEmoticon>{};
  List<LiveEmoticon> get available {
    final images = <String, LiveEmoticon>{};
    for (final image in _entries.values) {
      images.putIfAbsent(image.url, () => image);
    }
    return List.unmodifiable(images.values);
  }

  void _remember(Iterable<LiveEmoticon> images) {
    for (final image in images) {
      if (image.text.isNotEmpty && image.text.length <= 200 && LiveEmoticon.normalizeUrl(image.url) != null) {
        _entries[image.text] = image;
        if (_platform == 'huya' && image.text.startsWith('/{')) {
          _sendTokens[image.url] = image.text;
        }
      }
    }
  }
  final Future<List<LiveEmoticon>> Function(CancelToken) _fetch;
  final DateTime Function() _clock;
  int _attempts = 0;
  DateTime? _retryAt;
  CancelToken? _cancel;
  Future<void>? _pending;
  bool _disposed = false;
  bool _loaded = false;
  bool get loading => _pending != null;
  RoomEmoticons(
      {required String platform,
      required String roomId,
      dynamic args,
      Future<List<LiveEmoticon>> Function()? fetch,
      DateTime Function()? clock})
      : _platform = platform,
        _catalog = EmoticonCatalog(emoticonSeeds(platform)),
        _clock = clock ?? DateTime.now,
        _fetch = ((cancel) => fetch != null
            ? fetch()
            : PlatformEmoticons()
                .load(platform, roomId, args: args, cancel: cancel)) {
    _remember(emoticonSeeds(platform));
  }

  /// Display aliases are useful in chat/pickers, but Huya's wire format is /{code.
  /// Convert only known catalog entries; never rewrite unknown text or the draft.
  String encodeForSend(String text) {
    if (_platform != 'huya') return text;
    return _catalog.split(text).map((part) => part.emoticon == null
        ? part.text
        : _sendTokens[part.emoticon!.url] ?? part.text).join();
  }

  Future<void> load() {
    if (_disposed || _loaded) return Future.value();
    return _pending ??= Future<void>.microtask(_load);
  }

  /// Automatic retries are driven by unknown incoming tokens, not a timer;
  /// at most three requests per room, separated by 2s then 4s backoff.
  Future<void>? retryIfDue() {
    if (_disposed || _loaded) return null;
    if (_pending != null) return _pending;
    if (_attempts >= 3 || (_retryAt != null && _clock().isBefore(_retryAt!)))
      return null;
    return load();
  }

  Future<void> _load() async {
    _attempts++;
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final entries = await _fetch(cancel).timeout(const Duration(seconds: 5));
      if (_disposed) return;
      _catalog.addAll(entries);
      _remember(entries);
      _resolved.clear();
      _loaded = true;
      notifyListeners();
    } catch (_) {
      _retryAt = _clock().add(Duration(seconds: 1 << _attempts.clamp(1, 4)));
      cancel.cancel('emoticon catalog unavailable');
      // Missing credentials, offline or a changed schema must never block
      // playback/chat. Keep seed/native images and allow a later retry.
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
      _pending = null;
    }
  }

  List<LiveMessagePart> resolve(LiveMessage message) {
    if (_disposed) return _resolve(message);
    final cached = _resolved.remove(message);
    final parts =
        cached ?? List<LiveMessagePart>.unmodifiable(_resolve(message));
    _resolved[message] = parts;
    if (_resolved.length > 512) _resolved.remove(_resolved.keys.first);
    return parts;
  }

  List<LiveMessagePart> _resolve(LiveMessage message) {
    if (message.emoticonKey != null) {
      final match = _catalog.split(message.emoticonKey!).firstOrNull?.emoticon;
      if (match != null)
        return [
          LiveMessagePart.image(LiveEmoticon(
              text: message.message.isEmpty ? match.text : message.message,
              url: match.url,
              width: match.width,
              height: match.height,
              headers: match.headers))
        ];
    }
    return _catalog.enrich(message.parts);
  }

  @override
  void dispose() {
    _disposed = true;
    _resolved.clear();
    _cancel?.cancel('room closed');
    super.dispose();
  }
}
