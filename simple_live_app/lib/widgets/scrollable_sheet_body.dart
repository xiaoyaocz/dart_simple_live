import 'package:flutter/material.dart';

/// Lets a short sheet fit its contents and a tall sheet scroll within the
/// current route constraints, including after a desktop window is resized.
class ScrollableSheetBody extends StatefulWidget {
  const ScrollableSheetBody({
    required this.child,
    this.showScrollbar = false,
    super.key,
  });

  final Widget child;
  final bool showScrollbar;

  @override
  State<ScrollableSheetBody> createState() => _ScrollableSheetBodyState();
}

class _ScrollableSheetBodyState extends State<ScrollableSheetBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ScrollConfiguration(
        // This widget supplies the desktop scrollbar with its own controller.
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: widget.showScrollbar,
          interactive: true,
          child: SingleChildScrollView(
            controller: _controller,
            primary: false,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
