import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/models/danmaku_content_item.dart';

class Utils {
  static final RegExp _emojiTokenPattern = RegExp(r'\[[^\[\]]{1,16}\]');

  static String normalizeImageUrl(String url) {
    final value = url.trim();
    if (value.startsWith("asset://")) {
      return value;
    }
    if (value.startsWith("//")) {
      return "https:$value";
    }
    return value;
  }

  static Size measureContent(
    DanmakuContentItem content,
    double fontSize,
    int fontWeight, [
    double emojiScale = 1.25,
    String? fontFamily,
  ]) {
    final parts = contentParts(content);
    final text = parts
        .where((part) => part.isText)
        .map((part) => part.text ?? "")
        .join();
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.values[fontWeight],
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final imageCount = imageUrlsForContent(content).length;
    final imageSize = fontSize * emojiScale;
    return Size(
      textPainter.width + imageCount * imageSize,
      textPainter.height > imageSize ? textPainter.height : imageSize,
    );
  }

  static ui.Paragraph generateParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight, [
    double emojiScale = 1.25,
    String? fontFamily,
  ]) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.values[fontWeight],
        fontFamily: fontFamily,
        textDirection: TextDirection.ltr,
      ),
    )..pushStyle(ui.TextStyle(color: content.color, fontFamily: fontFamily));
    _appendContent(builder, content, fontSize, emojiScale);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static ui.Paragraph generateStrokeParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight, [
    double emojiScale = 1.25,
    String? fontFamily,
  ]) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final ui.ParagraphBuilder strokeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.values[fontWeight],
        fontFamily: fontFamily,
        textDirection: TextDirection.ltr,
      ),
    )..pushStyle(ui.TextStyle(foreground: strokePaint, fontFamily: fontFamily));
    _appendContent(strokeBuilder, content, fontSize, emojiScale);

    return strokeBuilder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static void drawEmojiImages(
    Canvas canvas,
    ui.Paragraph paragraph,
    DanmakuContentItem content,
    Offset offset,
    Map<String, ui.Image> imageCache,
  ) {
    final imageUrls = imageUrlsForContent(content);
    if (imageUrls.isEmpty) {
      return;
    }
    final boxes = paragraph.getBoxesForPlaceholders();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < imageUrls.length && i < boxes.length; i++) {
      final image = imageCache[imageUrls[i]];
      if (image == null) {
        continue;
      }
      final box = boxes[i];
      final dst = Rect.fromLTRB(
        offset.dx + box.left,
        offset.dy + box.top,
        offset.dx + box.right,
        offset.dy + box.bottom,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        paint,
      );
    }
  }

  static List<DanmakuContentPart> contentParts(DanmakuContentItem content) {
    final parts = content.parts ?? const <DanmakuContentPart>[];
    if (parts.isNotEmpty) {
      return parts;
    }
    final imageUrls = (content.imageUrls ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (imageUrls.isEmpty) {
      return [
        if (content.text.isNotEmpty) DanmakuContentPart.text(content.text),
      ];
    }

    final result = <DanmakuContentPart>[];
    var start = 0;
    var imageIndex = 0;
    for (final match in _emojiTokenPattern.allMatches(content.text)) {
      if (imageIndex >= imageUrls.length) {
        break;
      }
      if (match.start > start) {
        result.add(
          DanmakuContentPart.text(content.text.substring(start, match.start)),
        );
      }
      result.add(DanmakuContentPart.image(imageUrls[imageIndex]));
      imageIndex += 1;
      start = match.end;
    }
    if (start < content.text.length) {
      result.add(DanmakuContentPart.text(content.text.substring(start)));
    }
    for (; imageIndex < imageUrls.length; imageIndex += 1) {
      result.add(DanmakuContentPart.image(imageUrls[imageIndex]));
    }
    return result;
  }

  static List<String> imageUrlsForContent(DanmakuContentItem content) {
    return contentParts(content)
        .where((part) => part.isImage)
        .map((part) => normalizeImageUrl(part.imageUrl ?? ""))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static void _appendContent(
    ui.ParagraphBuilder builder,
    DanmakuContentItem content,
    double fontSize,
    double emojiScale,
  ) {
    final imageSize = fontSize * emojiScale;
    for (final part in contentParts(content)) {
      if (part.isText) {
        builder.addText(part.text ?? "");
      } else if (part.isImage && (part.imageUrl ?? "").trim().isNotEmpty) {
        builder.addPlaceholder(
          imageSize,
          imageSize,
          ui.PlaceholderAlignment.middle,
        );
      }
    }
  }
}
