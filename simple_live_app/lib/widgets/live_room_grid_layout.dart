import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class LiveRoomGridLayout {
  static const double coverAspectRatio = 16 / 9;
  static const double defaultHorizontalPadding = 12;
  static const double defaultSpacing = 12;
  static const double defaultMinCardWidth = 176;
  static const int defaultMinColumns = 2;
  static const int defaultMaxColumns = 8;

  final int crossAxisCount;
  final double itemWidth;
  final double mainAxisExtent;

  const LiveRoomGridLayout._({
    required this.crossAxisCount,
    required this.itemWidth,
    required this.mainAxisExtent,
  });

  factory LiveRoomGridLayout.resolve(
    double viewportWidth, {
    double horizontalPadding = defaultHorizontalPadding,
    double spacing = defaultSpacing,
    double minCardWidth = defaultMinCardWidth,
    int minColumns = defaultMinColumns,
    int maxColumns = defaultMaxColumns,
    required double detailsExtent,
  }) {
    assert(horizontalPadding >= 0);
    assert(spacing >= 0);
    assert(minCardWidth > 0);
    assert(minColumns > 0);
    assert(maxColumns >= minColumns);
    assert(detailsExtent >= 0);

    final fallbackWidth = minCardWidth * minColumns +
        spacing * (minColumns - 1) +
        horizontalPadding * 2;
    final safeWidth = viewportWidth.isFinite && viewportWidth > 0
        ? viewportWidth
        : fallbackWidth;
    final contentWidth = math.max(0.0, safeWidth - horizontalPadding * 2);
    final desiredColumns =
        ((contentWidth + spacing) / (minCardWidth + spacing)).floor();
    final columns = desiredColumns.clamp(minColumns, maxColumns).toInt();
    final cardsWidth = math.max(0.0, contentWidth - spacing * (columns - 1));
    final itemWidth = cardsWidth / columns;

    return LiveRoomGridLayout._(
      crossAxisCount: columns,
      itemWidth: itemWidth,
      mainAxisExtent: itemWidth / coverAspectRatio + detailsExtent,
    );
  }
}
