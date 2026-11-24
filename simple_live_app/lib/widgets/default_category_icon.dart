import 'package:flutter/material.dart';
import 'package:simple_live_app/app/sites.dart';

/// 分区默认图标组件：在分区未提供图标或图标加载失败时展示清晰的卡片徽标，
/// 可选在右下角叠加小尺寸平台标识以区分所属站点。
class DefaultCategoryIcon extends StatelessWidget {
  final String categoryName;
  final String? siteId;
  final double size;
  final double borderRadius;

  const DefaultCategoryIcon({
    required this.categoryName,
    this.siteId,
    this.size = 40,
    this.borderRadius = 10,
    super.key,
  });

  static IconData resolveIconData(String name) {
    final trimmed = name.trim();
    if (trimmed.contains('棋') ||
        trimmed.contains('麻将') ||
        trimmed.contains('斗地主') ||
        trimmed.contains('策略')) {
      return Icons.extension_rounded;
    }
    if (trimmed.contains('游戏') ||
        trimmed.contains('电竞') ||
        trimmed.contains('手游') ||
        trimmed.contains('王者') ||
        trimmed.contains('英雄') ||
        trimmed.contains('和平') ||
        trimmed.contains('三角洲') ||
        trimmed.contains('无畏') ||
        trimmed.contains('原神') ||
        trimmed.toUpperCase().contains('CS') ||
        trimmed.toUpperCase().contains('DOTA') ||
        trimmed.toUpperCase().contains('LOL')) {
      return Icons.sports_esports_rounded;
    }
    if (trimmed.contains('唱') ||
        trimmed.contains('音乐') ||
        trimmed.contains('电台') ||
        trimmed.contains('歌')) {
      return Icons.music_note_rounded;
    }
    if (trimmed.contains('舞') ||
        trimmed.contains('颜值') ||
        trimmed.contains('才艺')) {
      return Icons.auto_awesome_rounded;
    }
    if (trimmed.contains('聊天') ||
        trimmed.contains('交友') ||
        trimmed.contains('情感') ||
        trimmed.contains('连麦')) {
      return Icons.forum_rounded;
    }
    if (trimmed.contains('美食') || trimmed.contains('吃')) {
      return Icons.restaurant_rounded;
    }
    if (trimmed.contains('户外') ||
        trimmed.contains('旅行') ||
        trimmed.contains('生活')) {
      return Icons.park_rounded;
    }
    if (trimmed.contains('体育') ||
        trimmed.contains('健身') ||
        trimmed.contains('篮球') ||
        trimmed.contains('足球')) {
      return Icons.sports_basketball_rounded;
    }
    if (trimmed.contains('汽车') || trimmed.contains('车')) {
      return Icons.directions_car_rounded;
    }
    if (trimmed.contains('知识') ||
        trimmed.contains('教育') ||
        trimmed.contains('课堂') ||
        trimmed.contains('学习')) {
      return Icons.school_rounded;
    }
    if (trimmed.contains('二次元') ||
        trimmed.contains('动漫') ||
        trimmed.contains('虚拟')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (trimmed.contains('财经') || trimmed.contains('股票')) {
      return Icons.trending_up_rounded;
    }
    if (trimmed.contains('科技') || trimmed.contains('数码')) {
      return Icons.memory_rounded;
    }
    if (trimmed.contains('影视') ||
        trimmed.contains('电影') ||
        trimmed.contains('综艺')) {
      return Icons.movie_rounded;
    }
    if (trimmed.contains('购物') || trimmed.contains('电商')) {
      return Icons.shopping_bag_rounded;
    }
    if (trimmed.contains('宠物')) {
      return Icons.pets_rounded;
    }
    return Icons.category_rounded;
  }

  static const List<({Color light, Color dark})> _accentPalette = [
    (light: Color(0xFF2563EB), dark: Color(0xFF60A5FA)),
    (light: Color(0xFF0D9488), dark: Color(0xFF2DD4BF)),
    (light: Color(0xFF7C3AED), dark: Color(0xFFA78BFA)),
    (light: Color(0xFFD97706), dark: Color(0xFFFBBF24)),
    (light: Color(0xFFDB2777), dark: Color(0xFFF472B6)),
    (light: Color(0xFF0284C7), dark: Color(0xFF38BDF8)),
  ];

  static Color _resolveAccent(String name, bool isDark) {
    var hash = 0;
    for (final code in name.trim().codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    final pair = _accentPalette[hash % _accentPalette.length];
    return isDark ? pair.dark : pair.light;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _resolveAccent(categoryName, isDark);
    final site = siteId != null ? Sites.allSites[siteId] : null;
    final badgeSize = (size * 0.36).clamp(12.0, 16.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF2C323C), Color(0xFF21262E)]
                    : const [Color(0xFFF7F9FC), Color(0xFFE9EFF7)],
              ),
              border: Border.all(
                color: accent.withAlpha(isDark ? 95 : 80),
              ),
            ),
            child: Center(
              child: Icon(
                resolveIconData(categoryName),
                size: (size * 0.54).clamp(18.0, 26.0),
                color: accent,
              ),
            ),
          ),
          if (site != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badgeSize + 2,
                height: badgeSize + 2,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.cardColor,
                  border: Border.all(
                    color: theme.dividerColor.withAlpha(80),
                    width: 0.6,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    site.logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
