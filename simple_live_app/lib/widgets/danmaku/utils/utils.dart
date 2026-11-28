import 'dart:math';
import 'dart:ui' as ui;

import 'package:simple_live_app/widgets/danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';

abstract final class DmUtils {
  static void addContent(ui.ParagraphBuilder builder,
      DanmakuContentItem content, double fontSize) {
    if (content.spans == null) {
      builder.addText(content.text);
      return;
    }
    for (final span in content.spans!) {
      if (span.image == null) {
        builder.addText(span.text);
      } else {
        builder.addPlaceholder(span.width(fontSize), fontSize * 1.15,
            ui.PlaceholderAlignment.middle);
      }
    }
  }

  static final Random random = Random();

  static const maxRasterizeSize = 8192.0;

  static String generateRandomString(int length) {
    const characters = '0123456789abcdefghijklmnopqrstuvwxyz';

    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => characters.codeUnitAt(random.nextInt(characters.length)),
      ),
    );
  }

  static final Paint _selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.green;

  static void updateSelfSendPaint(double strokeWidth) {
    _selfSendPaint.strokeWidth = strokeWidth;
  }

  static ui.Paragraph generateParagraph({
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    String? fontFamily,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      maxLines: 1,
      fontFamily: fontFamily,
    ));

    if (content.count case final count?) {
      builder
        ..pushStyle(ui.TextStyle(
          color: content.color,
          fontSize: fontSize * 0.6,
          fontFamily: fontFamily,
        ))
        ..addText('($count)')
        ..pop();
    }

    builder
      ..pushStyle(ui.TextStyle(
          color: content.color, fontSize: fontSize, fontFamily: fontFamily));
    addContent(builder, content, fontSize);

    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  static ui.Image recordDanmakuImage({
    required ui.Paragraph contentParagraph,
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
    required double devicePixelRatio,
    String? fontFamily,
  }) {
    double w = contentParagraph.maxIntrinsicWidth + strokeWidth;
    double h = contentParagraph.height + strokeWidth;

    final offset = Offset(
      (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0),
      strokeWidth / 2.0,
    );

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec)..scale(devicePixelRatio);

    if (strokeWidth != 0) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
        maxLines: 1,
        fontFamily: fontFamily,
      ));
      final Paint strokePaint = Paint()
        ..shader = content.isColorful
            ? const LinearGradient(
                    colors: [Color(0xFFF2509E), Color(0xFF308BCD)])
                .createShader(Rect.fromLTWH(0, 0, w, h))
            : null
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      if (!content.isColorful) {
        strokePaint.color = Colors.black;
      }

      if (content.count case final count?) {
        builder
          ..pushStyle(ui.TextStyle(
            fontSize: fontSize * 0.6,
            foreground: strokePaint,
            fontFamily: fontFamily,
          ))
          ..addText('($count)')
          ..pop();
      }

      builder
        ..pushStyle(ui.TextStyle(
            fontSize: fontSize,
            foreground: strokePaint,
            fontFamily: fontFamily));
      addContent(builder, content, fontSize);

      final strokeParagraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));

      canvas.drawParagraph(strokeParagraph, offset);
      strokeParagraph.dispose();
    }

    canvas.drawParagraph(contentParagraph, offset);

    if (content.selfSend) {
      w += 4;
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil(),
      (h * devicePixelRatio).ceil(),
    );
    pic.dispose();
    return img;
  }

  static ui.Image recordSpecialDanmakuImg({
    required SpecialDanmakuContentItem content,
    required int fontWeight,
    required double strokeWidth,
    required double devicePixelRatio,
    String? fontFamily,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontSize: content.fontSize,
      fontFamily: fontFamily,
    ))
      ..pushStyle(ui.TextStyle(
        color: content.color,
        fontSize: content.fontSize,
        fontFamily: fontFamily,
        shadows: content.hasStroke
            ? [Shadow(color: Colors.black, blurRadius: strokeWidth)]
            : null,
      ))
      ..addText(content.text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final strokeOffset = strokeWidth / 2;
    final totalWidth = paragraph.maxIntrinsicWidth + strokeWidth;
    final totalHeight = paragraph.height + strokeWidth;

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);

    final Rect rect;
    double adjustDevicePixelRatio = devicePixelRatio;

    if (content.rotateZ != 0 || content.matrix != null) {
      rect = _calculateRotatedBounds(
        totalWidth,
        totalHeight,
        content.rotateZ,
        content.matrix,
      );

      final imgLongestSide = rect.size.longestSide * devicePixelRatio;
      if (imgLongestSide > maxRasterizeSize) {
        // force resize
        adjustDevicePixelRatio = maxRasterizeSize / imgLongestSide;
      }
      canvas
        ..scale(adjustDevicePixelRatio)
        ..translate(strokeOffset - rect.left, strokeOffset - rect.top);

      if (content.matrix case final matrix?) {
        canvas.transform(matrix.storage);
      } else {
        canvas.rotate(content.rotateZ);
      }
      canvas.drawParagraph(paragraph, Offset.zero);
    } else {
      rect = Rect.fromLTRB(0, 0, totalWidth, totalHeight);

      final imgLongestSide = max(totalWidth, totalHeight) * devicePixelRatio;
      if (imgLongestSide > maxRasterizeSize) {
        final scale = maxRasterizeSize / imgLongestSide;
        adjustDevicePixelRatio = scale;
      }
      canvas
        ..scale(adjustDevicePixelRatio)
        ..drawParagraph(paragraph, Offset(strokeOffset, strokeOffset));
    }

    content.rect = rect;

    final imgSize = rect.size * adjustDevicePixelRatio;
    final pic = rec.endRecording();
    final img = pic.toImageSync(imgSize.width.ceil(), imgSize.height.ceil());
    pic.dispose();
    paragraph.dispose();

    return img;
  }

  static Rect _calculateRotatedBounds(
    double w,
    double h,
    double rotateZ,
    Matrix4? matrix,
  ) {
    final double cosZ;
    final double cosY;
    final double sinZ;
    if (matrix == null) {
      cosZ = cos(rotateZ);
      sinZ = sin(rotateZ);
      cosY = 1;
    } else {
      cosZ = matrix[5];
      sinZ = matrix[1];
      cosY = matrix[10];
    }

    final wx = w * cosZ * cosY;
    final wy = w * sinZ;
    final hx = -h * sinZ * cosY;
    final hy = h * cosZ;

    final minX = _min4(0.0, wx, hx, wx + hx);
    final maxX = _max4(0.0, wx, hx, wx + hx);
    final minY = _min4(0.0, wy, hy, wy + hy);
    final maxY = _max4(0.0, wy, hy, wy + hy);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @pragma("vm:prefer-inline")
  static double _min4(double a, double b, double c, double d) {
    final ab = a < b ? a : b;
    final cd = c < d ? c : d;
    return ab < cd ? ab : cd;
  }

  @pragma("vm:prefer-inline")
  static double _max4(double a, double b, double c, double d) {
    final ab = a > b ? a : b;
    final cd = c > d ? c : d;
    return ab > cd ? ab : cd;
  }
}
