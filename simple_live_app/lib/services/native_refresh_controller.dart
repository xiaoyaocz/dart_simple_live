import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Observe the system display; playback must never change physical modes.
class NativeRefreshController with WidgetsBindingObserver {
  static const _channel = MethodChannel('simple_live/display_refresh');
  static NativeRefreshController? _active;
  final sourceFps = 0.0.obs;
  final displayHz = 0.0.obs;
  Timer? _displayChange;
  int _revision = 0;
  bool _closed = false, _started = false, _foreground = true;

  void start() {
    if (_started || _closed) return;
    _started = true;
    _active = this;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'displayChanged' || _closed) return;
      _displayChange?.cancel();
      _displayChange =
          Timer(const Duration(milliseconds: 200), () => refresh());
    });
    unawaited(refresh());
  }

  Future<void> updateSource(double fps) async {
    if (_closed) return;
    // Metadata is independent of display configuration; never query modes here.
    sourceFps.value = fps.isFinite && fps > 0 ? fps : 0;
  }

  Future<void> refresh() async {
    if (_closed || !_foreground) return;
    final revision = ++_revision;
    try {
      final caps = await _channel
          .invokeMapMethod<String, dynamic>('capabilities')
          .timeout(const Duration(seconds: 2));
      if (_closed || !_foreground || revision != _revision) return;
      final current = (caps?['current'] as num?)?.toDouble() ?? 0;
      displayHz.value = current.isFinite && current > 0 ? current : 0;
    } on MissingPluginException {
      // Unsupported platforms retain system-managed playback.
    } on PlatformException {
      // A disconnected display must not interrupt the stream.
    } on TimeoutException {
      // Display reporting must not hold playback startup.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    ++_revision;
    if (_foreground) unawaited(refresh());
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    ++_revision;
    _displayChange?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      if (identical(_active, this)) {
        _active = null;
        _channel.setMethodCallHandler(null);
      }
    }
    // No set/reset lease: room entry and exit never reconfigure the screen.
  }
}
