import 'dart:ui' as ui;

import 'package:simple_live_app/widgets/danmaku/base_danmaku_painter.dart';
import 'package:simple_live_app/widgets/danmaku/models/danmaku_item.dart';
import 'package:flutter/material.dart';

final class ScrollDanmakuPainter extends BaseDanmakuPainter {
  final double durationInMilliseconds;

  late final Paint selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..color = Colors.green;

  ScrollDanmakuPainter({
    required super.length,
    required super.danmakuItems,
    required this.durationInMilliseconds,
    required super.fontSize,
    required super.fontWeight,
    required super.strokeWidth,
    required super.devicePixelRatio,
    required super.running,
    required super.tick,
    super.batchThreshold,
    super.imageChanges,
  });

  @override
  void paintDanmaku(ui.Canvas canvas, ui.Size size, DanmakuItem item) {
    item.drawParagraphIfNeeded(
      fontSize,
      fontWeight,
      strokeWidth,
      devicePixelRatio,
    );
    if (!item.suspend) {
      final startPosition = size.width;
      final endPosition = -item.width;
      final distance = startPosition - endPosition;
      item.xPosition +=
          (((item.drawTick ??= tick) - tick) / durationInMilliseconds) *
              distance;

      if (item.xPosition < endPosition || item.xPosition > startPosition) {
        item.expired = true;
        return;
      }
    }

    BaseDanmakuPainter.paintImg(
      canvas,
      item,
      item.xPosition,
      item.yPosition,
      devicePixelRatio,
    );

    item.drawTick = tick;
  }
}
