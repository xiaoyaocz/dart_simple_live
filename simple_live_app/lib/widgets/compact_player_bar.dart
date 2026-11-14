import 'package:flutter/material.dart';

/// A narrow player toolbar that always reserves a full touch target at the
/// right for fullscreen. Primary actions scroll only in very narrow windows.
class CompactPlayerBar extends StatelessWidget {
  final List<Widget> primaryActions;
  final Widget overflowAction;
  final Widget fullscreenAction;
  final String duration;
  final Key? scrollAreaKey;

  const CompactPlayerBar({
    required this.primaryActions,
    required this.overflowAction,
    required this.fullscreenAction,
    required this.duration,
    this.scrollAreaKey,
    super.key,
  });

  static const actionExtent = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fixedWidth = actionExtent * (primaryActions.length + 2);
      final durationPainter = TextPainter(
        text: TextSpan(
          text: duration,
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final textWidth = durationPainter.width;
      durationPainter.dispose();
      final showDuration = constraints.maxWidth >= fixedWidth + textWidth + 16;
      return SizedBox(
        height: actionExtent,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: scrollAreaKey,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in primaryActions) _slot(action),
                    if (showDuration)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          duration,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _slot(overflowAction),
            _slot(fullscreenAction),
          ],
        ),
      );
    });
  }

  Widget _slot(Widget child) => SizedBox(
        width: actionExtent,
        height: actionExtent,
        child: child,
      );
}
