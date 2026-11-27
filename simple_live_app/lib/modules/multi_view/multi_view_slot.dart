class MultiViewRoomRef {
  const MultiViewRoomRef({
    required this.siteId,
    required this.roomId,
    required this.userName,
    this.face = '',
  });

  final String siteId;
  final String roomId;
  final String userName;
  final String face;

  String get roomKey => '${siteId}_$roomId';
}

/// Pure layout & single-audio-focus state machine for Windows multi-view.
class MultiViewLayoutState {
  MultiViewLayoutState({int initialLayout = 2})
      : _layoutCount = initialLayout == 4 ? 4 : 2,
        _slots = List<MultiViewRoomRef?>.filled(4, null);

  static const int maxSlots = 4;

  int _layoutCount;
  final List<MultiViewRoomRef?> _slots;
  int _activeAudioIndex = -1;
  bool _mutedAll = false;

  int get layoutCount => _layoutCount;
  int get activeAudioIndex => _activeAudioIndex;
  bool get mutedAll => _mutedAll;

  List<MultiViewRoomRef?> get visibleSlots =>
      List<MultiViewRoomRef?>.unmodifiable(_slots.take(_layoutCount));

  MultiViewRoomRef? slotAt(int index) {
    if (index < 0 || index >= _layoutCount) return null;
    return _slots[index];
  }

  bool containsRoom(String roomKey, {int? ignoreIndex}) {
    for (var i = 0; i < _layoutCount; i++) {
      if (i == ignoreIndex) continue;
      if (_slots[i]?.roomKey == roomKey) return true;
    }
    return false;
  }

  /// Assigns [room] to visible slot [index]. Returns false if [index] is out
  /// of bounds or the same room is already assigned to another slot.
  bool assignSlot(int index, MultiViewRoomRef room) {
    if (index < 0 || index >= _layoutCount) return false;
    if (containsRoom(room.roomKey, ignoreIndex: index)) return false;
    _slots[index] = room;
    if (_activeAudioIndex < 0 ||
        _activeAudioIndex >= _layoutCount ||
        _slots[_activeAudioIndex] == null) {
      _activeAudioIndex = index;
    }
    return true;
  }

  /// Clears slot [index] and reassigns audio focus if needed.
  void clearSlot(int index) {
    if (index < 0 || index >= maxSlots) return;
    _slots[index] = null;
    if (_activeAudioIndex == index) {
      _activeAudioIndex = _firstOccupiedIndex();
    }
  }

  /// Switches audio focus to occupied slot [index] and unmutes global mute.
  bool setActiveAudio(int index) {
    if (index < 0 || index >= _layoutCount || _slots[index] == null) {
      return false;
    }
    _activeAudioIndex = index;
    _mutedAll = false;
    return true;
  }

  void setMutedAll(bool muted) {
    _mutedAll = muted;
  }

  void toggleMutedAll() {
    _mutedAll = !_mutedAll;
  }

  /// Changes visible slot count between 2 and 4.
  /// Returns indices that were evicted (when shrinking 4 -> 2) so callers can
  /// stop and release their players immediately.
  List<int> setLayoutCount(int count) {
    final normalized = count == 4 ? 4 : 2;
    if (normalized == _layoutCount) return const [];
    final evicted = <int>[];
    if (normalized < _layoutCount) {
      for (var i = normalized; i < _layoutCount; i++) {
        if (_slots[i] != null) {
          evicted.add(i);
        }
        _slots[i] = null;
      }
    }
    _layoutCount = normalized;
    if (_activeAudioIndex >= _layoutCount ||
        (_activeAudioIndex >= 0 && _slots[_activeAudioIndex] == null)) {
      _activeAudioIndex = _firstOccupiedIndex();
    }
    return evicted;
  }

  double volumeForSlot(int index, {required double masterVolume}) {
    if (_mutedAll) return 0.0;
    if (index < 0 || index >= _layoutCount) return 0.0;
    if (_slots[index] == null || _activeAudioIndex != index) return 0.0;
    return masterVolume.clamp(0.0, 100.0).toDouble();
  }

  int _firstOccupiedIndex() {
    for (var i = 0; i < _layoutCount; i++) {
      if (_slots[i] != null) return i;
    }
    return -1;
  }
}
