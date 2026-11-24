import 'dart:math' show pi;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

enum DanmakuItemType { scroll, top, bottom, special }

class DanmakuContentItem {
  /// 弹幕文本
  final String text;

  /// 弹幕颜色
  final Color color;

  /// 弹幕类型
  final DanmakuItemType type;

  /// 是否为自己发送
  final bool selfSend;

  /// 文本内表情图片地址
  final List<String>? imageUrls;

  /// 按顺序排列的文本/图片片段。
  ///
  /// 为空时兼容旧逻辑：先绘制 [text]，再把 [imageUrls] 追加到末尾。
  final List<DanmakuContentPart>? parts;

  DanmakuContentItem(
    this.text, {
    this.color = Colors.white,
    this.type = DanmakuItemType.scroll,
    this.selfSend = false,
    this.imageUrls,
    this.parts,
  });
}

class DanmakuContentPart {
  final String? text;
  final String? imageUrl;

  const DanmakuContentPart.text(this.text) : imageUrl = null;
  const DanmakuContentPart.image(this.imageUrl) : text = null;

  bool get isText => text != null;
  bool get isImage => imageUrl != null;
}

class SpecialDanmakuContentItem extends DanmakuContentItem {
  final int duration;

  final double fontSize; // 从弹幕内容外解析
  final bool hasStroke;
  final Tween<double>? alphaTween;

  final Tween<double> translateXTween; // 相对坐标
  final Tween<double> translateYTween; // 相对坐标
  final int translationDuration;
  final int translationStartDelay;

  final Matrix4? matrix;
  final PathMetric? motionPathMetric;

  final Curve easingType;

  @override
  bool get selfSend => false;
  @override
  DanmakuItemType get type => DanmakuItemType.special;

  TextPainter? painterCache;

  SpecialDanmakuContentItem(
    super.text, {
    required this.duration,
    required super.color,
    required this.fontSize,
    this.hasStroke = false,
    required this.translateXTween,
    required this.translateYTween,
    this.alphaTween,
    this.matrix,
    this.motionPathMetric,
    int? translationDuration,
    this.translationStartDelay = 0,
    this.easingType = Curves.linear,
  }) : this.translationDuration = translationDuration ?? duration;

  factory SpecialDanmakuContentItem.fromList(
    Color color,
    double fontSize,
    List list, {
    double videoX = 1920,
    double videoY = 1080,
    bool disableGradient = false,
  }) {
    var (startX, endX) = _toRelativePosition(list[0], list[7], videoX);
    var (startY, endY) = _toRelativePosition(list[1], list[8], videoY);
    List<String> alphaString = list[2].split('-');
    double startA = double.tryParse(alphaString[0]) ?? 1;
    double endA = double.tryParse(alphaString[1]) ?? 1;
    Tween<double>? alphaTween;
    if (disableGradient || startA == endA) {
      color = color.withOpacity((startA + endA) / 2);
    } else {
      alphaTween = Tween(begin: startA, end: endA);
    }
    int duration = (_parseDouble(list[3]) * 1000).round();
    String text = list[4].trim();
    int rotateZ = _parseInt(list[5]);
    int rotateY = _parseInt(list[6]);
    Matrix4? matrix;
    if (rotateZ != 0 || rotateY != 0) {
      matrix = Matrix4.identity();
      if (rotateZ != 0) matrix.rotateZ(_degreeToRadian(rotateZ));
      if (rotateY != 0) matrix.rotateY(_degreeToRadian(rotateY));
    }
    var translateXTween = _makeTween(startX, endX);
    var translateYTween = _makeTween(startY, endY);
    int translationDuration = _parseInt(list[9]);
    int translationStartDelay = _parseInt(list[10]);
    bool hasStroke = list[11] == 1;
    // 字体
    // list[12];
    var easingType = list[13] == 1 ? Curves.easeInCubic : Curves.linear;
    // TODO 路径动画
    // List<Path> path;
    // if (list.length > 15) {
    //   list[14];
    // }
    return SpecialDanmakuContentItem(
      text,
      duration: duration,
      color: color,
      fontSize: fontSize,
      hasStroke: hasStroke,
      alphaTween: alphaTween,
      translateXTween: translateXTween,
      translateYTween: translateYTween,
      translationDuration: translationDuration,
      translationStartDelay: translationStartDelay,
      matrix: matrix,
      // motionPathMetric: null,
      easingType: easingType,
    );
  }

  static (double, double) _toRelativePosition(
    dynamic rawStart,
    dynamic rawEnd,
    double videoSize,
  ) {
    double toRadix(double? value, dynamic rawValue) =>
        (value! > 1 || (rawValue is String && !rawValue.contains('.')))
        ? value /= videoSize
        : value;

    double? convert(value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    double? start = convert(rawStart);
    double? end = convert(rawEnd);

    if (start == null && end == null) return (0, 0);
    start ??= end;
    end ??= start;

    return (toRadix(start, rawStart), toRadix(end, rawEnd));
  }

  static int _parseInt(dynamic digit) => switch (digit) {
    int() => digit,
    double() => digit.toInt(),
    String() => int.tryParse(digit) ?? 0,
    _ => throw UnimplementedError(),
  };

  static double _parseDouble(dynamic digit) => switch (digit) {
    int() => digit.toDouble(),
    double() => digit,
    String() => double.tryParse(digit) ?? 0,
    _ => throw UnimplementedError(),
  };

  static Tween<T> _makeTween<T>(T start, T end) {
    return start == end
        ? ConstantTween<T>(start)
        : Tween<T>(begin: start, end: end);
  }

  static double _degreeToRadian(int degree) {
    const pi180 = pi / 180;
    return degree * pi180;
  }
}
