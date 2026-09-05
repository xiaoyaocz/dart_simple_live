import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models/danmaku_item.dart';
import '/utils/utils.dart';

class ScrollDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> scrollDanmakuItems;
  final int danmakuDurationInSeconds;
  final double fontSize;
  final int fontWeight;
  final String? fontFamily;
  final bool showStroke;
  final double danmakuHeight;
  final bool running;
  final int tick;
  final Map<String, ui.Image> emojiImageCache;

  final double totalDuration;
  final Paint selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.green;

  ScrollDanmakuPainter(
    this.progress,
    this.scrollDanmakuItems,
    this.danmakuDurationInSeconds,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.showStroke,
    this.danmakuHeight,
    this.running,
    this.tick,
    this.emojiImageCache,
  ) : totalDuration = danmakuDurationInSeconds * 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final startPosition = size.width;

    for (var item in scrollDanmakuItems) {
      item.lastDrawTick ??= item.creationTime;
      final endPosition = -item.width;
      final distance = startPosition - endPosition;
      item.xPosition =
          item.xPosition +
          (((item.lastDrawTick! - tick) / totalDuration) * distance);

      if (item.xPosition < -item.width || item.xPosition > size.width) {
        continue;
      }

      item.paragraph ??= Utils.generateParagraph(
        item.content,
        size.width,
        fontSize,
        fontWeight,
        1.25,
        fontFamily,
      );

      if (showStroke) {
        item.strokeParagraph ??= Utils.generateStrokeParagraph(
          item.content,
          size.width,
          fontSize,
          fontWeight,
          1.25,
          fontFamily,
        );
        if (item.strokeParagraph != null) {
          canvas.drawParagraph(
            item.strokeParagraph!,
            Offset(item.xPosition, item.yPosition),
          );
        }
      }

      if (item.content.selfSend) {
        canvas.drawRect(
          Offset(item.xPosition, item.yPosition).translate(-2, 2) &
              (Size(item.width, item.height) + const Offset(4, 0)),
          selfSendPaint,
        );
      }

      final offset = Offset(item.xPosition, item.yPosition);
      canvas.drawParagraph(item.paragraph!, offset);
      Utils.drawEmojiImages(
        canvas,
        item.paragraph!,
        item.content,
        offset,
        emojiImageCache,
      );
      item.lastDrawTick = tick;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
