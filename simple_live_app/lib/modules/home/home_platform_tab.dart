import 'package:flutter/material.dart';

class HomePlatformTab extends StatelessWidget {
  final Widget child;
  final VoidCallback onSelect;
  final VoidCallback onRefresh;
  const HomePlatformTab(
      {super.key,
      required this.child,
      required this.onSelect,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '单击切换平台，双击刷新首页',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelect,
          onDoubleTap: onRefresh,
          child: child,
        ),
      );
}
