import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';

class DesktopRefreshButton extends StatelessWidget {
  final bool refreshing;
  final Function()? onPressed;
  const DesktopRefreshButton(
      {required this.refreshing, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppStyle.radius48,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(50),
            blurRadius: 4,
          ),
        ],
      ),
      width: 40,
      height: 40,
      child: refreshing
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh),
            ),
    );
  }
}
