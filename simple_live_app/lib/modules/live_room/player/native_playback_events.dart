import 'dart:async';
import 'dart:ffi';

import 'package:media_kit/generated/libmpv/bindings.dart';
// Use the exact binary that owns the player handle, including custom paths.
// ignore: implementation_imports
import 'package:media_kit/src/player/native/core/native_library.dart';

/// Reads terminal events from a separate weak client. media_kit keeps its
/// own event queue, and opening or disposing this client cannot stop playback.
class NativePlaybackEvents {
  NativePlaybackEvents(int playerHandle, this.onFailure)
      : _mpv = MPV(DynamicLibrary.open(NativeLibrary.path)) {
    _client = _mpv.mpv_create_weak_client(
        Pointer<mpv_handle>.fromAddress(playerHandle), nullptr);
    if (_client == nullptr) throw StateError('Cannot observe libmpv events');
  }

  final MPV _mpv;
  final void Function(int revision, int error) onFailure;
  late Pointer<mpv_handle> _client;
  Timer? _poll;
  (int, int)? _target;

  bool get tracking => _target != null;

  void reset() {
    _target = null;
    _poll?.cancel();
    _poll = null;
    _drain();
  }

  void track(int revision, int entryId) {
    if (_client == nullptr) return;
    _poll?.cancel();
    _target = (revision, entryId);
    _poll = Timer.periodic(const Duration(milliseconds: 100), (_) => _drain());
    _drain();
  }

  void _drain() {
    for (var i = 0; i < 128 && _client != nullptr; i++) {
      final event = _mpv.mpv_wait_event(_client, 0).ref;
      if (event.event_id == mpv_event_id.MPV_EVENT_NONE) return;
      if (event.event_id == mpv_event_id.MPV_EVENT_SHUTDOWN ||
          event.event_id == mpv_event_id.MPV_EVENT_QUEUE_OVERFLOW) {
        dispose();
        return;
      }
      final target = _target;
      if (target == null || event.event_id != mpv_event_id.MPV_EVENT_END_FILE) {
        continue;
      }
      final end = event.data.cast<mpv_event_end_file>().ref;
      if (end.playlist_entry_id == target.$2 &&
          end.reason == mpv_end_file_reason.MPV_END_FILE_REASON_ERROR) {
        onFailure(target.$1, end.error);
      }
    }
  }

  void dispose() {
    _target = null;
    _poll?.cancel();
    _poll = null;
    final client = _client;
    _client = nullptr;
    if (client != nullptr) _mpv.mpv_destroy(client);
  }
}
