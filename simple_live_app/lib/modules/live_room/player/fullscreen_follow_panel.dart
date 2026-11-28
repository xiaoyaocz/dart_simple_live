import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_group.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';

class FullscreenFollowLayout {
  final bool isMobile;
  final double panelWidth;
  final int crossAxisCount;
  final double horizontalPadding;
  final double itemSpacing;
  final double rowSpacing;
  final double groupTitleFontSize;
  final double headerHeight;
  final double filterFontSize;
  final FollowUserItemCompactStyle compactStyle;

  const FullscreenFollowLayout({
    required this.isMobile,
    required this.panelWidth,
    required this.crossAxisCount,
    required this.horizontalPadding,
    required this.itemSpacing,
    required this.rowSpacing,
    required this.groupTitleFontSize,
    required this.headerHeight,
    required this.filterFontSize,
    required this.compactStyle,
  });
}

FullscreenFollowLayout computeFullscreenFollowLayout(
  Size screenSize,
  EdgeInsets padding, {
  required bool isMobile,
}) {
  final usableWidth =
      (screenSize.width - padding.left - padding.right).clamp(180.0, double.infinity);
  if (!isMobile) {
    final maxPanelWidth = math.max(240.0, usableWidth * 0.85);
    final panelWidth = (usableWidth * 0.44)
        .clamp(320.0, 660.0)
        .clamp(240.0, maxPanelWidth);
    const horizontalPadding = 12.0;
    const itemSpacing = 10.0;
    const rowSpacing = 4.0;
    final innerWidth = panelWidth - horizontalPadding * 2;
    return FullscreenFollowLayout(
      isMobile: false,
      panelWidth: panelWidth.toDouble(),
      crossAxisCount: innerWidth >= 460 ? 2 : 1,
      horizontalPadding: horizontalPadding,
      itemSpacing: itemSpacing,
      rowSpacing: rowSpacing,
      groupTitleFontSize: 15.0,
      headerHeight: 44.0,
      filterFontSize: 12.0,
      compactStyle: const FollowUserItemCompactStyle(
        avatarSize: 38,
        titleFontSize: 13.5,
        metaFontSize: 11.5,
        siteLogoSize: 15,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        borderRadius: 10,
      ),
    );
  }
  final maxPanelWidth = math.max(240.0, usableWidth * 0.62);
  final panelWidth = (usableWidth * 0.52)
      .clamp(280.0, 520.0)
      .clamp(240.0, maxPanelWidth);
  const horizontalPadding = 8.0;
  const itemSpacing = 8.0;
  const rowSpacing = 2.0;
  final innerWidth = panelWidth - horizontalPadding * 2;
  return FullscreenFollowLayout(
    isMobile: true,
    panelWidth: panelWidth.toDouble(),
    crossAxisCount: innerWidth >= 340 ? 2 : 1,
    horizontalPadding: horizontalPadding,
    itemSpacing: itemSpacing,
    rowSpacing: rowSpacing,
    groupTitleFontSize: 12.5,
    headerHeight: 38.0,
    filterFontSize: 11.0,
    compactStyle: const FollowUserItemCompactStyle(
      avatarSize: 30,
      titleFontSize: 12.0,
      metaFontSize: 10.5,
      siteLogoSize: 13,
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      borderRadius: 8,
    ),
  );
}

class FullscreenFollowPanel extends StatefulWidget {
  final LiveRoomController controller;
  final bool fromLeft;
  final bool isMobile;
  final void Function(Site site, String roomId) onSelectRoom;
  final VoidCallback? onClose;
  final bool showHeader;

  const FullscreenFollowPanel({
    super.key,
    required this.controller,
    required this.fromLeft,
    required this.isMobile,
    required this.onSelectRoom,
    this.onClose,
    this.showHeader = true,
  });

  @override
  State<FullscreenFollowPanel> createState() => _FullscreenFollowPanelState();
}

class _FullscreenFollowPanelState extends State<FullscreenFollowPanel> {
  static final List<FollowUserTag> _builtinTags = [
    FollowUserTag(id: '0', tag: '全部', userId: []),
    FollowUserTag(id: '1', tag: '直播中', userId: []),
    FollowUserTag(id: '2', tag: '未开播', userId: []),
  ];

  String _selectedFilterId = '1';
  final List<String> _categoryOrder = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<FollowUserTag> _allFilterTags(FollowService service) {
    final result = List<FollowUserTag>.from(_builtinTags);
    for (final tag in service.followTagList) {
      if (!result.any((existing) => existing.id == tag.id)) {
        result.add(tag);
      }
    }
    return result;
  }

  List<FollowUser> _filteredUsers(
    FollowService service,
    List<FollowUserTag> tags,
  ) {
    if (_selectedFilterId == '0') {
      return service.followList.toList();
    }
    if (_selectedFilterId == '1') {
      return service.liveList.toList();
    }
    if (_selectedFilterId == '2') {
      return service.notLiveList.toList();
    }
    final tag = tags.firstWhereOrNull((t) => t.id == _selectedFilterId);
    if (tag == null) {
      return service.liveList.toList();
    }
    return service.followList
        .where((user) => tag.userId.contains(user.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = computeFullscreenFollowLayout(
      media.size,
      media.padding,
      isMobile: widget.isMobile,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          _buildHeader(context, layout),
          Divider(height: 1, color: Colors.grey.withAlpha(25)),
        ],
        _buildFilterBar(context, layout),
        Expanded(
          child: _buildBody(context, layout),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, FullscreenFollowLayout layout) {
    final title = Text(
      '关注列表',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: widget.isMobile ? 14 : 15,
            fontWeight: FontWeight.w600,
          ),
    );
    final closeIcon = Icon(
      widget.fromLeft ? Icons.close : Icons.arrow_back,
      size: widget.isMobile ? 20 : 21,
    );
    final closeButton = IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      onPressed: widget.onClose,
      icon: closeIcon,
      tooltip: '关闭',
    );
    final refreshButton = _buildRefreshButton(size: widget.isMobile ? 18 : 20);

    return SizedBox(
      height: layout.headerHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.horizontalPadding),
        child: Row(
          children: widget.fromLeft
              ? [
                  refreshButton,
                  const SizedBox(width: 8),
                  Expanded(child: title),
                  closeButton,
                ]
              : [
                  closeButton,
                  const SizedBox(width: 4),
                  Expanded(child: title),
                  refreshButton,
                ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton({double size = 18}) {
    return Obx(() {
      final updating = FollowService.instance.updating.value;
      if (updating) {
        return SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        onPressed: () => FollowService.instance.loadData(),
        icon: Icon(Icons.refresh, size: size),
        tooltip: '刷新关注状态',
      );
    });
  }

  Widget _buildFilterBar(
      BuildContext context, FullscreenFollowLayout layout) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Obx(() {
      final tags = _allFilterTags(FollowService.instance);
      final activeId =
          tags.any((t) => t.id == _selectedFilterId) ? _selectedFilterId : '1';
      return Padding(
        padding: EdgeInsets.fromLTRB(
          layout.horizontalPadding,
          widget.isMobile ? 6 : 8,
          layout.horizontalPadding,
          widget.isMobile ? 4 : 6,
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: widget.isMobile ? 8 : 10,
                  children: tags.map((option) {
                    final selected = option.id == activeId;
                    return InkWell(
                      borderRadius: AppStyle.radius24,
                      onTap: () {
                        if (_selectedFilterId == option.id) return;
                        setState(() => _selectedFilterId = option.id);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isMobile ? 10 : 12,
                          vertical: widget.isMobile ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.primary.withAlpha(24)
                              : null,
                          border: Border.all(
                            color: selected
                                ? (theme.textTheme.bodyMedium?.color ??
                                    colorScheme.primary)
                                : Colors.grey,
                          ),
                          borderRadius: AppStyle.radius24,
                        ),
                        child: Text(
                          option.tag,
                          style: TextStyle(
                            fontSize: layout.filterFontSize,
                            color: selected
                                ? theme.textTheme.bodyMedium?.color
                                : Colors.grey,
                            fontWeight:
                                selected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (!widget.showHeader) ...[
              const SizedBox(width: 4),
              _buildRefreshButton(size: 18),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, FullscreenFollowLayout layout) {
    return Obx(() {
      final service = FollowService.instance;
      final tags = _allFilterTags(service);
      final activeId =
          tags.any((t) => t.id == _selectedFilterId) ? _selectedFilterId : '1';
      final users = _filteredUsers(service, tags)
          .where((u) => Sites.allSites.containsKey(u.siteId))
          .toList();
      final siteOrder = Get.isRegistered<AppSettingsController>()
          ? AppSettingsController.instance.siteSort.toList()
          : const <String>[];
      final groups = groupFollowUsersByCategory(users);
      final sortedGroups = sortFollowCategoryGroups(
        groups,
        previousOrder: _categoryOrder,
      );

      return RefreshIndicator(
        onRefresh: service.loadData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (sortedGroups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context, service, activeId),
              )
            else
              for (final group in sortedGroups)
                SliverToBoxAdapter(
                  key: ValueKey('fs-group-${group.key}'),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.horizontalPadding,
                      widget.isMobile ? 4 : 6,
                      layout.horizontalPadding,
                      widget.isMobile ? 4 : 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 2,
                            bottom: widget.isMobile ? 4 : 6,
                          ),
                          child: Text(
                            '${group.key} ${group.value.length}人',
                            style: TextStyle(
                              fontSize: layout.groupTitleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (_, constraints) {
                            final cols = widget.isMobile
                                ? (constraints.maxWidth >= 340 ? 2 : 1)
                                : (constraints.maxWidth >= 460 ? 2 : 1);
                            final width = (constraints.maxWidth -
                                    layout.itemSpacing * (cols - 1)) /
                                cols;
                            final members = sortFollowCategoryMembers(
                              group.value,
                              siteOrder,
                            );
                            return Wrap(
                              spacing: layout.itemSpacing,
                              runSpacing: layout.rowSpacing,
                              children: [
                                for (final item in members)
                                  SizedBox(
                                    key: ValueKey('fs-item-${item.id}'),
                                    width: width,
                                    child: Obx(
                                      () => FollowUserItem(
                                        item: item,
                                        compactStyle: layout.compactStyle,
                                        playing: widget
                                                    .controller.rxSite.value.id ==
                                                item.siteId &&
                                            widget.controller.rxRoomId.value ==
                                                item.roomId,
                                        onTap: () {
                                          final site =
                                              Sites.allSites[item.siteId];
                                          if (site == null) return;
                                          widget.onSelectRoom(
                                              site, item.roomId);
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyState(
    BuildContext context,
    FollowService service,
    String activeId,
  ) {
    final unresolvedStatus = activeId != '0' &&
        !service.updating.value &&
        service.followList.any((item) => item.liveStatus.value == 0);
    final String message;
    if (unresolvedStatus) {
      message = '关注记录仍在，直播状态暂未获取';
    } else if (activeId == '1' && service.followList.isNotEmpty) {
      message = '暂无直播中的关注主播';
    } else if (activeId == '2' && service.followList.isNotEmpty) {
      message = '暂无未开播的关注主播';
    } else {
      message = '暂无关注主播';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (activeId != '0' && service.followList.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedFilterId = '0'),
                    child: Text('查看全部 (${service.followList.length})'),
                  ),
                TextButton(
                  onPressed: () => service.loadData(),
                  child: const Text('刷新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
