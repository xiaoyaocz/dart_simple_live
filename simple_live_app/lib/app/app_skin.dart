import 'package:flutter/material.dart';

/// 一套皮肤：由主色 + 可选次要色/第三色构成，生成整套明暗 ThemeData 与背景渐变。
class AppSkin {
  final String id;
  final String name;
  final String description;
  final int seed;
  final int? secondary;
  final int? tertiary;
  final List<Color>? lightGradient;
  final List<Color>? darkGradient;

  const AppSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    this.secondary,
    this.tertiary,
    this.lightGradient,
    this.darkGradient,
  });

  Color get preview => Color(seed);

  /// 背景渐变：优先使用显式配置，否则根据配色自动生成。
  LinearGradient gradient(Brightness brightness) {
    final explicit =
        brightness == Brightness.dark ? darkGradient : lightGradient;
    if (explicit != null && explicit.length >= 2) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: explicit,
      );
    }

    final dark = brightness == Brightness.dark;
    final seedColor = Color(seed);
    final secondaryColor = Color(secondary ?? seed);
    final tertiaryColor = Color(tertiary ?? secondaryColor);
    final base = dark ? const Color(0xFF101216) : Colors.white;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(seedColor.withOpacity(dark ? 0.32 : 0.12), base),
        Color.alphaBlend(
            secondaryColor.withOpacity(dark ? 0.26 : 0.08), base),
        Color.alphaBlend(
            tertiaryColor.withOpacity(dark ? 0.30 : 0.10), base),
      ],
    );
  }

  ColorScheme _scheme(Brightness brightness) {
    var scheme = ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    if (secondary != null) {
      scheme = scheme.copyWith(secondary: Color(secondary!));
    }
    if (tertiary != null) {
      scheme = scheme.copyWith(tertiary: Color(tertiary!));
    }

    final dark = brightness == Brightness.dark;
    final seedColor = Color(seed);
    final base = dark ? const Color(0xFF101216) : Colors.white;
    Color surfaceAt(double opacity) =>
        Color.alphaBlend(seedColor.withOpacity(opacity), base);

    return scheme.copyWith(
      surface: surfaceAt(dark ? 0.16 : 0.06),
      onSurface: dark ? const Color(0xFFE7E9ED) : const Color(0xFF1B1C20),
      surfaceContainerLowest: surfaceAt(dark ? 0.10 : 0.03),
      surfaceContainerLow: surfaceAt(dark ? 0.16 : 0.06),
      surfaceContainer: surfaceAt(dark ? 0.22 : 0.10),
      surfaceContainerHigh: surfaceAt(dark ? 0.28 : 0.14),
      surfaceContainerHighest: surfaceAt(dark ? 0.34 : 0.18),
      surfaceDim: surfaceAt(dark ? 0.08 : 0.04),
      surfaceBright: surfaceAt(dark ? 0.30 : 0.12),
    );
  }

  ThemeData buildTheme(Brightness brightness, ThemeData base) {
    final scheme = _scheme(brightness);
    final dark = brightness == Brightness.dark;
    final seedColor = Color(seed);

    // 有渐变背景时，让 Scaffold 背景透明以透出渐变。
    final surface = scheme.surface;
    final card = scheme.surfaceContainerLow;
    final onSurface = scheme.onSurface;

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      cardColor: card,
      dialogBackgroundColor: surface,
      dividerColor: Color.alphaBlend(
        seedColor.withOpacity(dark ? 0.30 : 0.14),
        dark ? Colors.white24 : Colors.black12,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}

class AppSkins {
  static const List<AppSkin> all = [
    AppSkin(
      id: "classic",
      name: "经典蓝",
      description: "清爽默认蓝",
      seed: 0xff3498db,
    ),
    AppSkin(
      id: "hyrule",
      name: "海拉鲁狂野",
      description: "旷野之息 · 森林与黄金",
      seed: 0xff2F6D4F,
      secondary: 0xffC8A24B,
      tertiary: 0xff4A82C4,
      lightGradient: [
        Color(0xFFDCE9DD),
        Color(0xFFF2E5C6),
        Color(0xFFD9E6F4),
      ],
      darkGradient: [
        Color(0xFF111B16),
        Color(0xFF1D2A1C),
        Color(0xFF2A2113),
      ],
    ),
    AppSkin(
      id: "sakura",
      name: "樱花粉",
      description: "柔和少女粉",
      seed: 0xffF06292,
      secondary: 0xffBA68C8,
    ),
    AppSkin(
      id: "jade",
      name: "翡翠绿",
      description: "清新翡翠",
      seed: 0xff26A69A,
    ),
    AppSkin(
      id: "amber",
      name: "琥珀橙",
      description: "温暖琥珀",
      seed: 0xffFF9800,
      secondary: 0xffFFB74D,
    ),
    AppSkin(
      id: "violet",
      name: "星黛紫",
      description: "梦幻星空紫",
      seed: 0xff9575CD,
      secondary: 0xff7E57C2,
    ),
    AppSkin(
      id: "cyber",
      name: "赛博青",
      description: "科技赛博青",
      seed: 0xff26C6DA,
      secondary: 0xff29B6F6,
    ),
  ];

  static AppSkin byId(String id) {
    return all.firstWhere(
      (e) => e.id == id,
      orElse: () => all.first,
    );
  }
}