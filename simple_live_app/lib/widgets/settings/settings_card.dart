import 'dart:io';
import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = (Platform.isWindows || Platform.isAndroid) &&
        theme.scaffoldBackgroundColor == Colors.transparent;
    final radius = material ? BorderRadius.circular(12) : AppStyle.radius8;
    return Material(
      color: material ? theme.colorScheme.surface.withAlpha(205)
          : theme.brightness == Brightness.dark
          ? Colors.grey.withAlpha(50)
          : Colors.white70,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: material ? theme.colorScheme.outlineVariant.withAlpha(100)
              : Colors.grey.withAlpha(25),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
        ),
        child: child,
      ),
    );
  }
}
