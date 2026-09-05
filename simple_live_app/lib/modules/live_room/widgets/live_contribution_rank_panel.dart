import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveContributionRankPanel extends StatefulWidget {
  final LiveRoomController controller;

  const LiveContributionRankPanel({
    super.key,
    required this.controller,
  });

  @override
  State<LiveContributionRankPanel> createState() =>
      _LiveContributionRankPanelState();
}

class _LiveContributionRankPanelState extends State<LiveContributionRankPanel> {
  String _filter = "all";

  LiveRoomController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.contributionRanks.toList();
      final filteredItems = _applyFilter(items);
      final loading = controller.contributionRankLoading.value;
      final error = controller.contributionRankError.value;

      return RefreshIndicator(
        onRefresh: () => controller.fetchContributionRank(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppStyle.edgeInsetsA12,
          children: [
            _buildHero(
              context,
              visibleCount: filteredItems.length,
              totalCount: items.length,
              loading: loading,
            ),
            AppStyle.vGap12,
            if (items.isNotEmpty) ...[
              _buildFilterBar(context),
              AppStyle.vGap12,
            ],
            if (error != null && items.isNotEmpty) ...[
              _buildInlineError(context, error),
              AppStyle.vGap12,
            ],
            if (loading && items.isEmpty) _buildLoading(context),
            if (!loading && error != null && items.isEmpty)
              _buildError(context, error),
            if (!loading && error == null && items.isEmpty)
              _buildEmpty(context, "当前没有可显示的$_panelTitle"),
            if (!loading &&
                error == null &&
                items.isNotEmpty &&
                filteredItems.isEmpty)
              _buildEmpty(context, "当前筛选条件下没有符合要求的用户"),
            if (filteredItems.isNotEmpty) ...[
              _buildTopThree(context, filteredItems),
              if (filteredItems.length > 3) AppStyle.vGap12,
              ...filteredItems.skip(3).map(
                    (item) => Padding(
                      padding: AppStyle.edgeInsetsB8,
                      child: _buildRankTile(context, item),
                    ),
                  ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildHero(
    BuildContext context, {
    required int visibleCount,
    required int totalCount,
    required bool loading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final detail = controller.detail.value;
    final updatedAt = controller.contributionRankUpdatedAt.value;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppStyle.radius24,
      ),
      padding: AppStyle.edgeInsetsA16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(160),
                  borderRadius: AppStyle.radius12,
                ),
                padding: AppStyle.edgeInsetsA8,
                child: Image.asset(controller.site.logo),
              ),
              AppStyle.hGap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _panelTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    AppStyle.vGap4,
                    Text(
                      detail?.title ?? detail?.userName ?? controller.roomId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "刷新榜单",
                onPressed: loading
                    ? null
                    : () =>
                        controller.fetchContributionRank(forceRefresh: true),
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Remix.refresh_line),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                context,
                icon: Remix.medal_line,
                label: totalCount > 0
                    ? "显示 $visibleCount / $totalCount 位"
                    : "下拉可刷新",
              ),
              _buildInfoChip(
                context,
                icon: Remix.bar_chart_grouped_line,
                label: _scoreLabel,
              ),
              _buildInfoChip(
                context,
                icon: Remix.filter_3_line,
                label: _filterLabel,
              ),
              if (updatedAt != null)
                _buildInfoChip(
                  context,
                  icon: Remix.time_line,
                  label: "${Utils.parseTime(updatedAt)} 更新",
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    const options = [
      ("all", "全部"),
      ("top10", "前十"),
      ("fans", "粉丝牌"),
      ("high", "高贡献"),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (item) => ChoiceChip(
              selected: _filter == item.$1,
              label: Text(item.$2),
              onSelected: (_) {
                if (_filter == item.$1) {
                  return;
                }
                setState(() {
                  _filter = item.$1;
                });
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          AppStyle.vGap12,
          Text(
            "正在读取$_panelTitle",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppStyle.radius12,
      ),
      padding: AppStyle.edgeInsetsA16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "榜单加载失败",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
          ),
          AppStyle.vGap8,
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
          ),
          AppStyle.vGap12,
          FilledButton.tonalIcon(
            onPressed: () =>
                controller.fetchContributionRank(forceRefresh: true),
            icon: const Icon(Remix.refresh_line),
            label: const Text("重试"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppStyle.radius12,
      ),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Remix.inbox_archive_line,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          AppStyle.vGap12,
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(BuildContext context, String error) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withAlpha(180),
        borderRadius: AppStyle.radius12,
      ),
      padding: AppStyle.edgeInsetsA12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Remix.error_warning_line),
          AppStyle.hGap8,
          Expanded(
            child: Text(
              "刷新失败，当前显示的是上一次成功获取的榜单。\n$error",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(
    BuildContext context,
    List<LiveContributionRankItem> items,
  ) {
    final topItems = items.take(3).toList();
    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayOrder = <LiveContributionRankItem>[
      if (topItems.length > 1) topItems[1],
      topItems.first,
      if (topItems.length > 2) topItems[2],
    ];
    final heights = <int, double>{1: 176, 2: 152, 3: 140};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: displayOrder
          .map(
            (item) => Expanded(
              child: Padding(
                padding: AppStyle.edgeInsetsH4,
                child: _buildTopCard(
                  context,
                  item,
                  height: heights[item.rank] ?? 136,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTopCard(
    BuildContext context,
    LiveContributionRankItem item, {
    required double height,
  }) {
    final colors = _rankColors(item.rank, context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppStyle.radius24,
        onTap: () => controller.showUserActions(item.userName),
        onLongPress: () => controller.copyUserName(item.userName),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: AppStyle.radius24,
            boxShadow: [
              BoxShadow(
                color: colors.last.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: AppStyle.edgeInsetsA12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: item.rank == 1 ? 30 : 24,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: NetImage(
                    item.avatar,
                    width: item.rank == 1 ? 56 : 44,
                    height: item.rank == 1 ? 56 : 44,
                  ),
                ),
              ),
              AppStyle.vGap8,
              Text(
                "#${item.rank}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              AppStyle.vGap4,
              Text(
                item.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              AppStyle.vGap4,
              Text(
                _formatMetric(item.scoreText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withAlpha(220),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankTile(BuildContext context, LiveContributionRankItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppStyle.radius12,
        onTap: () => controller.showUserActions(item.userName),
        onLongPress: () => controller.copyUserName(item.userName),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: AppStyle.radius12,
            border: Border.all(color: Colors.grey.withAlpha(24)),
          ),
          padding: AppStyle.edgeInsetsA12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AppStyle.radius12,
                ),
                child: Text(
                  item.rank.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AppStyle.hGap12,
              NetImage(
                item.avatar,
                width: 44,
                height: 44,
                borderRadius: 22,
              ),
              AppStyle.hGap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    AppStyle.vGap8,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if ((item.userLevelIcon ?? "").isNotEmpty)
                          ClipRRect(
                            borderRadius: AppStyle.radius8,
                            child: NetImage(
                              item.userLevelIcon!,
                              width: 32,
                              height: 16,
                              fit: BoxFit.contain,
                            ),
                          )
                        else if ((item.userLevelText ?? "").isNotEmpty)
                          _buildTag(
                            context,
                            label: item.userLevelText!,
                            icon: Remix.vip_crown_2_line,
                          ),
                        if ((item.fansIcon ?? "").isNotEmpty)
                          ClipRRect(
                            borderRadius: AppStyle.radius8,
                            child: NetImage(
                              item.fansIcon!,
                              width: 32,
                              height: 16,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if ((item.fansName ?? "").isNotEmpty ||
                            (item.fansLevel ?? 0) > 0)
                          _buildTag(
                            context,
                            label: [
                              if ((item.fansName ?? "").isNotEmpty)
                                item.fansName!,
                              if ((item.fansLevel ?? 0) > 0)
                                "Lv.${item.fansLevel}",
                            ].join(" "),
                            icon: Remix.heart_3_line,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppStyle.hGap12,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMetric(item.scoreText),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if ((item.scoreDetail ?? "").isNotEmpty) ...[
                    AppStyle.vGap4,
                    Text(
                      item.scoreDetail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(144),
        borderRadius: AppStyle.radius32,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          AppStyle.hGap4,
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppStyle.radius32,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          AppStyle.hGap4,
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Color> _rankColors(int rank, BuildContext context) {
    switch (rank) {
      case 1:
        return const [Color(0xFFFFD86F), Color(0xFFFFA53A)];
      case 2:
        return const [Color(0xFFDCE8F7), Color(0xFF89A2C3)];
      case 3:
        return const [Color(0xFFF4C8A1), Color(0xFFD7844B)];
      default:
        final color = Theme.of(context).colorScheme.primaryContainer;
        return [color, color.withAlpha(200)];
    }
  }

  List<LiveContributionRankItem> _applyFilter(
    List<LiveContributionRankItem> items,
  ) {
    switch (_filter) {
      case "top10":
        return items.take(10).toList();
      case "fans":
        return items
            .where(
              (item) =>
                  (item.fansName ?? "").trim().isNotEmpty ||
                  (item.fansIcon ?? "").trim().isNotEmpty ||
                  (item.fansLevel ?? 0) > 0,
            )
            .toList();
      case "high":
        final parsedScores = items
            .map((item) => _parseScoreValue(item.scoreText))
            .whereType<double>()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (parsedScores.isEmpty) {
          return items.take(10).toList();
        }
        final index = ((parsedScores.length * 0.3).ceil() - 1)
            .clamp(0, parsedScores.length - 1);
        final threshold = parsedScores[index];
        return items.where((item) {
          final score = _parseScoreValue(item.scoreText);
          return score != null && score >= threshold;
        }).toList();
      case "all":
      default:
        return items;
    }
  }

  double? _parseScoreValue(String text) {
    final raw = text.trim().toLowerCase().replaceAll(",", "");
    if (raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1) ?? "");
    if (value == null) {
      return null;
    }
    if (raw.contains("亿")) {
      return value * 100000000;
    }
    if (raw.contains("万") || raw.contains("w")) {
      return value * 10000;
    }
    if (raw.contains("k")) {
      return value * 1000;
    }
    return value;
  }

  String get _panelTitle {
    if (controller.site.id == Constant.kDouyu) {
      return "直播间亲密榜";
    }
    return "直播间贡献榜";
  }

  String get _scoreLabel {
    if (controller.site.id == Constant.kDouyu) {
      return "亲密度";
    }
    return "贡献值";
  }

  String get _filterLabel {
    switch (_filter) {
      case "top10":
        return "前十";
      case "fans":
        return "粉丝牌";
      case "high":
        return "高贡献";
      case "all":
      default:
        return "全部";
    }
  }

  String _formatMetric(String value) {
    final numeric = int.tryParse(value);
    if (numeric != null) {
      return NumberFormat.decimalPattern().format(numeric);
    }
    return value;
  }
}
