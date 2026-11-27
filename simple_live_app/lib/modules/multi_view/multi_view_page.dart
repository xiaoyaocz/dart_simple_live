import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_name.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

bool _isEditingTextOrModifiedShortcut() {
  final keyboard = HardwareKeyboard.instance;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  final editable = focusContext?.widget is EditableText
      ? focusContext!.widget as EditableText
      : focusContext?.findAncestorWidgetOfExactType<EditableText>();
  return keyboard.isControlPressed ||
      keyboard.isAltPressed ||
      keyboard.isMetaPressed ||
      (editable != null && !editable.readOnly);
}

/// 多画面页面快捷键处理：
/// - `F`：切换全屏（与单直播间一致）
/// - `R`：刷新当前选中的直播间
/// - `Esc`：全屏状态下退出全屏
KeyEventResult handleMultiViewShortcut(
  KeyEvent event, {
  required VoidCallback onToggleFullscreen,
  required VoidCallback onRefreshSelected,
  VoidCallback? onExitFullscreen,
  bool isFullScreen = false,
}) {
  if (_isEditingTextOrModifiedShortcut()) {
    return KeyEventResult.ignored;
  }
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (event.logicalKey == LogicalKeyboardKey.keyF) {
    onToggleFullscreen();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.keyR) {
    onRefreshSelected();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.escape &&
      isFullScreen &&
      onExitFullscreen != null) {
    onExitFullscreen();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

class MultiViewPage extends StatefulWidget {
  const MultiViewPage({super.key});

  @override
  State<MultiViewPage> createState() => _MultiViewPageState();
}

class _MultiViewPageState extends State<MultiViewPage> {
  MultiViewController get controller => Get.find<MultiViewController>();

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_onEarlyKey);
  }

  KeyEventResult _onEarlyKey(KeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    return handleMultiViewShortcut(
      event,
      onToggleFullscreen: controller.toggleFullScreen,
      onRefreshSelected: controller.refreshSelectedSlot,
      onExitFullscreen: controller.exitFullScreen,
      isFullScreen: controller.fullScreen.value,
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onEarlyKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory>{
        ForwardButtonTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                ForwardButtonTapGestureRecognizer>(
          ForwardButtonTapGestureRecognizer.new,
          (recognizer) => recognizer.onTap = () {
            if (ModalRoute.of(context)?.isCurrent != true) return;
            controller.openSelectedInSingleRoom();
          },
        ),
      },
      child: Obx(
        () => Scaffold(
            backgroundColor: const Color(0xFF0E1014),
            appBar: controller.fullScreen.value
                ? null
                : AppBar(
                    title: const Text('多画面同屏'),
                    actions: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 2,
                            icon: Icon(Icons.view_column_outlined, size: 18),
                            label: Text('2画面'),
                          ),
                          ButtonSegment<int>(
                            value: 4,
                            icon: Icon(Icons.grid_view_outlined, size: 18),
                            label: Text('4画面'),
                          ),
                        ],
                        selected: {controller.layoutCount.value},
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            controller.setLayoutCount(selection.first);
                          }
                        },
                      ),
                      AppStyle.hGap8,
                      IconButton(
                        tooltip:
                            controller.mutedAll.value ? '恢复声音' : '全部静音',
                        onPressed: controller.toggleMuteAll,
                        icon: Icon(
                          controller.mutedAll.value
                              ? Icons.volume_off
                              : Icons.volume_up_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip: '全部刷新（R 刷新选中窗口）',
                        onPressed: controller.refreshAll,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: '全屏 (F)',
                        onPressed: controller.toggleFullScreen,
                        icon: const Icon(Icons.fullscreen),
                      ),
                      AppStyle.hGap8,
                    ],
                  ),
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: controller.layoutCount.value == 2
                      ? Row(
                          children: [
                            Expanded(child: _buildTile(context, 0)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildTile(context, 1)),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _buildTile(context, 0)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _buildTile(context, 1)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _buildTile(context, 2)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _buildTile(context, 3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                // 全屏悬浮工具栏置于底部居中，避免与右上角画面的工具栏按键重叠。
                if (controller.fullScreen.value)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Material(
                        color: Colors.black.withAlpha(185),
                        borderRadius: AppStyle.radius24,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: controller.layoutCount.value == 2
                                    ? '切换 4画面'
                                    : '切换 2画面',
                                onPressed: () => controller.setLayoutCount(
                                  controller.layoutCount.value == 2 ? 4 : 2,
                                ),
                                icon: Icon(
                                  controller.layoutCount.value == 2
                                      ? Icons.grid_view_outlined
                                      : Icons.view_column_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: controller.mutedAll.value
                                    ? '恢复声音'
                                    : '全部静音',
                                onPressed: controller.toggleMuteAll,
                                icon: Icon(
                                  controller.mutedAll.value
                                      ? Icons.volume_off
                                      : Icons.volume_up_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: '刷新选中直播间 (R)',
                                onPressed: controller.refreshSelectedSlot,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: '退出全屏 (F / Esc)',
                                onPressed: controller.toggleFullScreen,
                                icon: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildTile(BuildContext context, int index) {
    final tile = controller.tiles[index];
    final theme = Theme.of(context);
    return Obx(() {
      final room = tile.room.value;
      final isSelected =
          controller.activeAudioIndex.value == index && room != null;
      final isAudioActive = isSelected && !controller.mutedAll.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: const Color(0xFF151922),
          borderRadius: AppStyle.radius8,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.white.withAlpha(24),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: room == null
            ? _buildEmptyTile(context, index)
            : _buildOccupiedTile(
                context,
                index,
                tile,
                isSelected: isSelected,
                isAudioActive: isAudioActive,
              ),
      );
    });
  }

  Widget _buildEmptyTile(BuildContext context, int index) {
    return InkWell(
      onTap: () => _showRoomPicker(context, index),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 40,
              color: Colors.white.withAlpha(150),
            ),
            AppStyle.vGap8,
            Text(
              '添加直播间 #${index + 1}',
              style: TextStyle(
                color: Colors.white.withAlpha(190),
                fontSize: 14,
              ),
            ),
            AppStyle.vGap4,
            Text(
              '从关注列表中选择直播间',
              style: TextStyle(
                color: Colors.white.withAlpha(110),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupiedTile(
    BuildContext context,
    int index,
    MultiViewTileRuntime tile, {
    required bool isSelected,
    required bool isAudioActive,
  }) {
    final room = tile.room.value!;
    final site = Sites.allSites[room.siteId];
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            event.scrollDelta.dy != 0 &&
            controller.activeAudioIndex.value == index) {
          GestureBinding.instance.pointerSignalResolver.register(event,
              (signal) {
            if (signal is PointerScrollEvent) {
              controller.adjustActiveVolumeOnScroll(signal.scrollDelta.dy);
            }
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.selectAudioSlot(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tile.hasPlayer.value && tile.videoController != null)
              Video(
                controller: tile.videoController!,
                controls: NoVideoControls,
                wakelock: false,
              ),
            if (tile.loading.value)
              const ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            if (tile.offline.value)
              const ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '主播已下播',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            if (tile.errorMsg.value.isNotEmpty)
              ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tile.errorMsg.value,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      AppStyle.vGap8,
                      OutlinedButton.icon(
                        onPressed: () => controller.refreshSlot(index),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            // 顶部信息与操作栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAudioActive ? Icons.volume_up : Icons.volume_off,
                      size: 16,
                      color: isAudioActive
                          ? Colors.lightBlueAccent
                          : Colors.white60,
                    ),
                    AppStyle.hGap4,
                    if (site != null) ...[
                      Image.asset(site.logo, width: 16, height: 16),
                      AppStyle.hGap4,
                    ],
                    Expanded(
                      child: Text(
                        room.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (tile.qualities.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: () => _showQualityMenu(context, index, tile),
                        child: Text(
                          tile.currentQualityName.value.isEmpty
                              ? '画质'
                              : tile.currentQualityName.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    IconButton(
                      tooltip: '切换房间',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      onPressed: () => _showRoomPicker(context, index),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    IconButton(
                      tooltip: '刷新 (R)',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      onPressed: () => controller.refreshSlot(index),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: '进入单窗口直播间（鼠标前侧键）',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      onPressed: () => controller.openInSingleRoom(index),
                      icon: const Icon(Icons.open_in_full),
                    ),
                    IconButton(
                      tooltip: '关闭此画面',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      onPressed: () => controller.removeSlot(index),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            // 滚轮调音反馈气泡（仅在当前选中窗口显示）
            if (isSelected && controller.volumeHintText.value.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(185),
                      borderRadius: AppStyle.radius24,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppSettingsController.instance.playerVolume.value <= 0
                              ? Icons.volume_off
                              : Icons.volume_up,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          controller.volumeHintText.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showQualityMenu(
    BuildContext context,
    int index,
    MultiViewTileRuntime tile,
  ) {
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 420),
      builder: (_) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tile.qualities.length,
          itemBuilder: (_, i) {
            final q = tile.qualities[i];
            final selected = i == tile.currentQualityIndex.value;
            return ListTile(
              title: Text(q.quality),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () {
                Get.back();
                controller.changeSlotQuality(index, i);
              },
            );
          },
        ),
      ),
    );
  }

  void _showRoomPicker(BuildContext context, int slotIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 620),
      builder: (_) => _MultiViewRoomPickerSheet(
        slotIndex: slotIndex,
        controller: controller,
      ),
    );
  }
}

/// 选择直播间弹窗：复用关注列表的标签筛选、分区归类、平台与热度排序及多列布局逻辑。
class _MultiViewRoomPickerSheet extends StatefulWidget {
  const _MultiViewRoomPickerSheet({
    required this.slotIndex,
    required this.controller,
  });

  final int slotIndex;
  final MultiViewController controller;

  @override
  State<_MultiViewRoomPickerSheet> createState() =>
      _MultiViewRoomPickerSheetState();
}

class _MultiViewRoomPickerSheetState extends State<_MultiViewRoomPickerSheet> {
  static final _builtinTags = <FollowUserTag>[
    FollowUserTag(id: '0', tag: '全部', userId: []),
    FollowUserTag(id: '1', tag: '直播中', userId: []),
    FollowUserTag(id: '2', tag: '未开播', userId: []),
  ];

  late String _selectedTagId;
  late String _selectedTagName;

  @override
  void initState() {
    super.initState();
    _initDefaultFilter();
  }

  void _initDefaultFilter() {
    if (Get.isRegistered<FollowUserController>()) {
      final mode = Get.find<FollowUserController>().filterMode.value;
      _selectedTagId = mode.id;
      _selectedTagName = mode.tag;
      return;
    }
    final saved = Get.isRegistered<LocalStorageService>()
        ? LocalStorageService.instance
            .getValue<dynamic>(LocalStorageService.kFollowDefaultFilter, '1')
        : '1';
    final initial = _builtinTags.firstWhere(
      (t) => t.id == saved,
      orElse: () => _builtinTags[1],
    );
    _selectedTagId = initial.id;
    _selectedTagName = initial.tag;
  }

  List<FollowUserTag> _allTags(FollowService service) {
    final result = <FollowUserTag>[..._builtinTags];
    for (final tag in service.followTagList) {
      if (!result.any((existing) => existing.id == tag.id)) {
        result.add(tag);
      }
    }
    return result;
  }

  List<FollowUser> _filteredUsers(
    FollowService service,
    FollowUserTag selected,
  ) {
    if (selected.tag == '全部') {
      return service.followList.toList();
    }
    if (selected.tag == '直播中') {
      return service.liveList.toList();
    }
    if (selected.tag == '未开播') {
      return service.notLiveList.toList();
    }
    service.filterDataByTag(selected);
    return service.curTagFollowList.toList();
  }

  List<MapEntry<String, List<FollowUser>>> _groupAndSortCategories(
    List<FollowUser> users,
  ) {
    final groups = <String, List<FollowUser>>{};
    for (final item in users) {
      final name = normalizeFollowCategory(item.categoryName);
      groups.putIfAbsent(name, () => []).add(item);
    }
    if (Get.isRegistered<FollowUserController>()) {
      return Get.find<FollowUserController>().sortCategoryGroups(groups);
    }
    final entries = groups.entries.toList();
    final liveCounts = {
      for (final entry in entries)
        entry.key:
            entry.value.where((item) => item.liveStatus.value == 2).length,
    };
    entries.sort((a, b) {
      if (a.key == b.key) return 0;
      if (a.key == '其他') return 1;
      if (b.key == '其他') return -1;
      return liveCounts[b.key]!.compareTo(liveCounts[a.key]!);
    });
    return entries;
  }

  List<FollowUser> _sortMembers(List<FollowUser> members) {
    final siteOrder = AppSettingsController.instance.siteSort.toList();
    if (Get.isRegistered<FollowUserController>()) {
      return Get.find<FollowUserController>()
          .sortCategoryMembers(members, siteOrder);
    }
    final indexed = members.asMap().entries.toList();
    final ranks = {for (var i = 0; i < siteOrder.length; i++) siteOrder[i]: i};
    for (final item in members) {
      ranks.putIfAbsent(item.siteId, () => ranks.length);
    }
    indexed.sort((a, b) {
      final platform = ranks[a.value.siteId]!.compareTo(ranks[b.value.siteId]!);
      if (platform != 0) return platform;
      final aHeat = a.value.heat;
      final bHeat = b.value.heat;
      if (aHeat == null && bHeat != null) return 1;
      if (aHeat != null && bHeat == null) return -1;
      final heat = aHeat == null ? 0 : bHeat!.compareTo(aHeat);
      return heat != 0 ? heat : a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    final followService = FollowService.instance;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择直播间（窗口 #${widget.slotIndex + 1}）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Obx(
                  () => IconButton(
                    tooltip: '刷新开播状态',
                    onPressed: followService.updating.value
                        ? null
                        : followService.loadData,
                    icon: followService.updating.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
          // 复用关注列表的筛选标签条（全部 / 直播中 / 未开播 / 自定义标签）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Obx(() {
              final tags = _allTags(followService);
              final selected = tags.firstWhere(
                (t) => t.id == _selectedTagId && t.tag == _selectedTagName,
                orElse: () => tags.firstWhere(
                  (t) => t.id == _selectedTagId,
                  orElse: () => tags[1],
                ),
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 12,
                  children: tags.map((option) {
                    return FilterButton(
                      text: option.tag,
                      selected: option.id == selected.id &&
                          option.tag == selected.tag,
                      onTap: () {
                        setState(() {
                          _selectedTagId = option.id;
                          _selectedTagName = option.tag;
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final tags = _allTags(followService);
              final selected = tags.firstWhere(
                (t) => t.id == _selectedTagId && t.tag == _selectedTagName,
                orElse: () => tags.firstWhere(
                  (t) => t.id == _selectedTagId,
                  orElse: () => tags[1],
                ),
              );
              final users = _filteredUsers(followService, selected);
              if (users.isEmpty) {
                return Center(
                  child: Text(
                    selected.tag == '直播中'
                        ? '当前没有正在直播的关注主播'
                        : '当前筛选下没有关注主播',
                  ),
                );
              }
              final groups = _groupAndSortCategories(users);
              return LayoutBuilder(
                builder: (context, constraints) {
                  final count = (constraints.maxWidth ~/ 420).clamp(1, 3);
                  final itemWidth =
                      (constraints.maxWidth - 12 * (count - 1)) / count;
                  return CustomScrollView(
                    slivers: [
                      for (final group in groups)
                        SliverToBoxAdapter(
                          key: ValueKey(group.key),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding:
                                    AppStyle.edgeInsetsV8.copyWith(left: 16),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${group.key} ${group.value.length}人',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                children: [
                                  for (final user in _sortMembers(group.value))
                                    SizedBox(
                                      key: ValueKey(user.id),
                                      width: itemWidth,
                                      child: FollowUserItem(
                                        item: user,
                                        playing: widget.controller.layoutState
                                            .containsRoom(
                                          '${user.siteId}_${user.roomId}',
                                          ignoreIndex: widget.slotIndex,
                                        ),
                                        onTap: () {
                                          Get.back();
                                          widget.controller.assignFollowUser(
                                            widget.slotIndex,
                                            user,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
