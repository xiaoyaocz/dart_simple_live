import 'package:simple_live_app/widgets/danmaku/base_danmaku_painter.dart';
import 'package:simple_live_app/widgets/danmaku/models/danmaku_content_item.dart';
import 'package:simple_live_app/widgets/danmaku/models/danmaku_item.dart';
import 'package:flutter/material.dart';

final class StaticDanmakuPainter extends CustomPainter {
  final int length;
  final List<DanmakuItem> danmakuItems;
  final double staticDurationInMilliseconds;
  final double fontSize;
  final int fontWeight;
  final double strokeWidth;
  final double devicePixelRatio;
  final int tick;

  StaticDanmakuPainter({
    required this.length,
    required this.danmakuItems,
    required this.staticDurationInMilliseconds,
    required this.fontSize,
    required this.fontWeight,
    required this.strokeWidth,
    required this.devicePixelRatio,
    required this.tick,
    Listenable? imageChanges,
  }) : super(repaint: imageChanges);

  @override
  void paint(Canvas canvas, Size size) {
    for (var item in danmakuItems) {
      item
        ..drawTick ??= tick
        ..drawParagraphIfNeeded(
          fontSize,
          fontWeight,
          strokeWidth,
          devicePixelRatio,
        )
        ..xPosition = (size.width - item.width) / 2;

      BaseDanmakuPainter.paintImg(
        canvas,
        item,
        item.xPosition,
        item.content.type == DanmakuItemType.bottom
            ? size.height - item.yPosition - item.height
            : item.yPosition,
        devicePixelRatio,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StaticDanmakuPainter oldDelegate) =>
      oldDelegate.length != length ||
      oldDelegate.fontSize != fontSize ||
      oldDelegate.fontWeight != fontWeight ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
