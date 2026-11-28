import 'dart:ui' as ui;

import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';

abstract base class BaseDanmakuPainter extends CustomPainter {
  final int length;
  final List<DanmakuItem> danmakuItems;
  final double fontSize;
  final int fontWeight;
  final double strokeWidth;
  final double devicePixelRatio;
  final bool running;
  final int batchThreshold;
  final int tick;

  static final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  const BaseDanmakuPainter({
    required this.length,
    required this.danmakuItems,
    required this.fontSize,
    required this.fontWeight,
    required this.strokeWidth,
    required this.devicePixelRatio,
    required this.running,
    required this.tick,
    this.batchThreshold = 10, // 默认值为10，可以自行调整
    Listenable? imageChanges,
  }) : super(repaint: imageChanges);

  static void paintImg(
    Canvas canvas,
    DanmakuItem item,
    double dx,
    double dy,
    double devicePixelRatio,
  ) {
    final img = item.image!;
    if (devicePixelRatio == 1.0) {
      canvas.drawImage(img, Offset(dx, dy), _paint);
    } else {
      final src =
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromLTWH(dx, dy, item.width, item.height);
      canvas.drawImageRect(img, src, dst, _paint);
    }
    item.paintInlineImages(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ui.PictureRecorder? pictureRecorder;
    final Canvas pictureCanvas;
    final length = danmakuItems.length;

    if (length > batchThreshold) {
      pictureRecorder = ui.PictureRecorder();
      pictureCanvas = Canvas(pictureRecorder);
    } else {
      pictureRecorder = null;
      pictureCanvas = canvas;
    }

    DanmakuItem? suspend;
    for (var i in danmakuItems) {
      if (i.expired) continue;

      if (i.suspend) {
        suspend = i;
        continue;
      }

      paintDanmaku(pictureCanvas, size, i);
    }

    if (suspend case final suspend?) {
      paintDanmaku(pictureCanvas, size, suspend);
    }

    if (pictureRecorder != null) {
      final ui.Picture picture = pictureRecorder.endRecording();
      canvas.drawPicture(picture);
      picture.dispose();
    }
  }

  void paintDanmaku(Canvas canvas, Size size, DanmakuItem item);

  @override
  bool shouldRepaint(covariant BaseDanmakuPainter oldDelegate) {
    return (running && length != 0) ||
        oldDelegate.length != length ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.fontWeight != fontWeight ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
