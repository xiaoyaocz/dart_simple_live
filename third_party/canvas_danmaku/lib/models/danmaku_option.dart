class DanmakuOption {
  /// 默认的字体大小
  final double fontSize;

  /// 字体粗细
  final int fontWeight;

  /// 字体族
  final String? fontFamily;

  /// 显示区域，0.1-1.0
  final double area;

  /// 轨道行高倍数，用于控制上下弹幕间距。
  final double lineHeight;

  /// 表情图片相对字体大小的比例。
  final double emojiScale;

  /// 滚动弹幕运行时间，秒
  final int duration;

  /// 不透明度，0.1-1.0
  final double opacity;

  /// 隐藏顶部弹幕
  final bool hideTop;

  /// 隐藏底部弹幕
  final bool hideBottom;

  /// 隐藏滚动弹幕
  final bool hideScroll;

  final bool hideSpecial;

  /// 弹幕描边
  final bool showStroke;

  /// 海量弹幕模式 (弹幕轨道占满时进行叠加)
  final bool massiveMode;

  /// 为字幕预留空间
  final bool safeArea;

  DanmakuOption({
    this.fontSize = 16,
    this.fontWeight = 4,
    this.fontFamily,
    this.area = 1.0,
    this.lineHeight = 1.0,
    this.emojiScale = 1.25,
    this.duration = 10,
    this.opacity = 1.0,
    this.hideBottom = false,
    this.hideScroll = false,
    this.hideTop = false,
    this.hideSpecial = false,
    this.showStroke = true,
    this.massiveMode = false,
    this.safeArea = true,
  });

  DanmakuOption copyWith({
    double? fontSize,
    int? fontWeight,
    String? fontFamily,
    double? area,
    double? lineHeight,
    double? emojiScale,
    int? duration,
    double? opacity,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? hideSpecial,
    bool? showStroke,
    bool? massiveMode,
    bool? safeArea,
  }) {
    return DanmakuOption(
      area: area ?? this.area,
      lineHeight: lineHeight ?? this.lineHeight,
      emojiScale: emojiScale ?? this.emojiScale,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      duration: duration ?? this.duration,
      opacity: opacity ?? this.opacity,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
      hideScroll: hideScroll ?? this.hideScroll,
      hideSpecial: hideSpecial ?? this.hideSpecial,
      showStroke: showStroke ?? this.showStroke,
      massiveMode: massiveMode ?? this.massiveMode,
      safeArea: safeArea ?? this.safeArea,
    );
  }
}
