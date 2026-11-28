import 'dart:async';
import 'package:flutter/material.dart';

/// Fill only the viewport plus a small near-bottom margin, not the whole category.
class AutoLoadViewport extends StatefulWidget {
  const AutoLoadViewport(
      {super.key,
      required this.canLoad,
      required this.loadMore,
      required this.child});
  final bool Function() canLoad;
  final Future<void> Function() loadMore;
  final Widget child;
  @override
  State<AutoLoadViewport> createState() => _AutoLoadViewportState();
}

class _AutoLoadViewportState extends State<AutoLoadViewport> {
  ScrollMetrics? _metrics;
  bool _scheduled = false;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant AutoLoadViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An empty grid and a short first page both have maxScrollExtent == 0.
    // A real network response can change the items without emitting new scroll
    // metrics. Recheck after the data-driven rebuild, not only on metrics events.
    if (_metrics != null) _schedule(_metrics!);
  }

  void _schedule(ScrollMetrics metrics) {
    _metrics = metrics;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _loading || !widget.canLoad()) return;
      final metrics = _metrics;
      if (metrics == null ||
          metrics.viewportDimension <= 0 ||
          metrics.extentAfter > 200) {
        return;
      }
      unawaited(_load());
    });
    // Metrics notifications can arrive after layout. Ensure the scheduled check
    // gets a frame even when there are no animations or user scrolling.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _load() async {
    _loading = true;
    try {
      await widget.loadMore();
    } finally {
      _loading = false;
      if (mounted && _metrics != null) _schedule(_metrics!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _schedule(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) _schedule(notification.metrics);
            return false;
          },
          child: widget.child,
        ),
      );
}
