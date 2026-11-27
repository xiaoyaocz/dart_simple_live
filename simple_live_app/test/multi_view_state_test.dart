import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_slot.dart';

void main() {
  group('MultiViewLayoutState', () {
    const roomA = MultiViewRoomRef(
      siteId: 'bilibili',
      roomId: '101',
      userName: '主播A',
    );
    const roomB = MultiViewRoomRef(
      siteId: 'douyu',
      roomId: '202',
      userName: '主播B',
    );
    const roomC = MultiViewRoomRef(
      siteId: 'huya',
      roomId: '303',
      userName: '主播C',
    );

    test('assigns first room as active audio and routes single-slot volume', () {
      final state = MultiViewLayoutState(initialLayout: 2);
      expect(state.activeAudioIndex, -1);

      expect(state.assignSlot(0, roomA), isTrue);
      expect(state.activeAudioIndex, 0);
      expect(state.volumeForSlot(0, masterVolume: 80), 80);
      expect(state.volumeForSlot(1, masterVolume: 80), 0);

      expect(state.assignSlot(1, roomB), isTrue);
      // Active audio stays on slot 0 until user switches
      expect(state.activeAudioIndex, 0);
      expect(state.volumeForSlot(0, masterVolume: 80), 80);
      expect(state.volumeForSlot(1, masterVolume: 80), 0);

      // Click slot 1 to switch audio
      expect(state.setActiveAudio(1), isTrue);
      expect(state.activeAudioIndex, 1);
      expect(state.volumeForSlot(0, masterVolume: 80), 0);
      expect(state.volumeForSlot(1, masterVolume: 80), 80);

      // Global mute silences all, selecting a slot unmutes
      state.toggleMutedAll();
      expect(state.volumeForSlot(1, masterVolume: 80), 0);
      state.setActiveAudio(0);
      expect(state.mutedAll, isFalse);
      expect(state.volumeForSlot(0, masterVolume: 80), 80);
    });

    test('prevents duplicate rooms across slots', () {
      final state = MultiViewLayoutState(initialLayout: 2);
      expect(state.assignSlot(0, roomA), isTrue);
      expect(state.assignSlot(1, roomA), isFalse);
      expect(state.slotAt(1), isNull);
      // Replacing same slot with same room is allowed
      expect(state.assignSlot(0, roomA), isTrue);
    });

    test('evicts extra slots on 4 -> 2 shrink and reassigns audio focus', () {
      final state = MultiViewLayoutState(initialLayout: 4);
      expect(state.assignSlot(0, roomA), isTrue);
      expect(state.assignSlot(2, roomC), isTrue);
      expect(state.setActiveAudio(2), isTrue);

      final evicted = state.setLayoutCount(2);
      expect(evicted, [2]);
      expect(state.layoutCount, 2);
      expect(state.activeAudioIndex, 0);
      expect(state.volumeForSlot(0, masterVolume: 60), 60);

      // Removing last remaining slot sets activeAudioIndex to -1
      state.clearSlot(0);
      expect(state.activeAudioIndex, -1);
      expect(state.volumeForSlot(0, masterVolume: 60), 0);
    });
  });
}
