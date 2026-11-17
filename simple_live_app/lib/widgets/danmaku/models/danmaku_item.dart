import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../inline_image_slot.dart';

import 'package:simple_live_app/widgets/danmaku/models/danmaku_content_item.dart';
import 'package:simple_live_app/widgets/danmaku/utils/utils.dart';

class DanmakuItem<T> {
  bool _imagesActive = true;
  List<InlineImageSlot>? _inlineImages;
  final VoidCallback? onImageChanged;
  String? fontFamily;
  int get inlineImageCount => _inlineImages?.length ?? 0;
  int get loadedInlineImageCount =>
      _inlineImages?.where((e) => e.loaded).length ?? 0;

  void setImagesActive(bool active) {
    _imagesActive = active;
    for (final slot in _inlineImages ?? <InlineImageSlot>[]) {
      slot.setActive(active);
    }
  }

  /// 弹幕内容
  final DanmakuContentItem<T> content;

  /// 弹幕宽度
  double width;

  /// 弹幕高度
  double height;

  /// 弹幕水平方向位置
  double xPosition;

  /// 弹幕竖直方向位置
  double yPosition;

  /// 上次绘制时间
  int? drawTick;

  /// 弹幕布局缓存
  ui.Image? image;

  bool expired = false;

  bool suspend = false;

  /// Identity can arrive after the receive event. Rebuild only changed bullets,
  /// preserving their position and lifetime, including while playback is paused.
  void updateSelfSend(bool value) {
    if (content.type == DanmakuItemType.special || content.selfSend == value) return;
    content.selfSend = value;
    dispose(); // Releases both the old raster and its shifted inline-image slots.
    onImageChanged?.call();
  }

  @pragma("vm:prefer-inline")
  bool needRemove(bool needRemove) {
    if (needRemove) {
      dispose();
    }
    return needRemove;
  }

  void dispose() {
    for (final slot in _inlineImages ?? <InlineImageSlot>[]) {
      slot.dispose();
    }
    _inlineImages = null;
    image?.dispose();
    image = null;
  }

  DanmakuItem({
    required this.content,
    required this.height,
    required this.width,
    this.xPosition = 0,
    this.yPosition = 0,
    this.image,
    this.drawTick,
    this.onImageChanged,
    this.fontFamily,
  });

  // Reuse the admission/rasterization paragraph instead of laying out spans
  // a second time just to recover their placeholder boxes.
  void initializeInlineImages(
      ui.Paragraph paragraph, double fontSize, double strokeWidth) {
    if (_inlineImages == null && content.spans != null) {
      final boxes = paragraph.getBoxesForPlaceholders();
      final images = content.spans!.where((e) => e.image != null).toList();
      _inlineImages = [
        for (var i = 0; i < images.length; i++)
          InlineImageSlot(
              rect: boxes[i].toRect().shift(ui.Offset(
                  strokeWidth / 2 + (content.selfSend ? 2 : 0),
                  strokeWidth / 2)),
              provider: images[i].image!,
              active: _imagesActive,
              text: images[i].text,
              style: TextStyle(
                  color: content.color,
                  fontSize: fontSize,
                  fontFamily: fontFamily),
              onChanged: () => onImageChanged?.call())
      ];
    }
  }

  void drawParagraphIfNeeded(
    double fontSize,
    int fontWeight,
    double strokeWidth,
    double devicePixelRatio,
  ) {
    if (image == null) {
      final paragraph = DmUtils.generateParagraph(
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
      );
      initializeInlineImages(paragraph, fontSize, strokeWidth);
      image = DmUtils.recordDanmakuImage(
        contentParagraph: paragraph,
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
        strokeWidth: strokeWidth,
        devicePixelRatio: devicePixelRatio,
        fontFamily: fontFamily,
      );
      width = paragraph.maxIntrinsicWidth +
          strokeWidth +
          (content.selfSend ? 4.0 : 0.0);
      height = paragraph.height + strokeWidth;
      paragraph.dispose();
    } else if (_inlineImages == null && content.spans != null) {
      final paragraph = DmUtils.generateParagraph(
          content: content,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: fontFamily);
      initializeInlineImages(paragraph, fontSize, strokeWidth);
      paragraph.dispose();
    }
  }

  void paintInlineImages(ui.Canvas canvas, ui.Offset offset) {
    for (final slot in _inlineImages ?? <InlineImageSlot>[]) {
      slot.paint(canvas, offset);
    }
  }

  @override
  String toString() {
    return 'DanmakuItem(content=$content, xPos=$xPosition, yPos=$yPosition, size=${ui.Size(width, height)}, drawTick=$drawTick)';
  }
}
