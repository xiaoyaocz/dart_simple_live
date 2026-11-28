import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// One reference to a shared ImageStream, active only while its message lives.
/// ImageInfo instances belong to this listener and are disposed on replacement.
class InlineImageSlot {
  final Rect rect;
  final ImageProvider _provider;
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  final TextPainter _fallback;
  ImageInfo? _frame;
  bool _disposed = false;
  bool get loaded => _frame != null;

  InlineImageSlot(
      {required this.rect,
      required ImageProvider provider,
      required String text,
      required TextStyle style,
      bool active = true,
      required VoidCallback onChanged})
      : _provider = provider,
        _fallback = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr)
          ..layout() {
    _listener = ImageStreamListener((frame, synchronous) {
      if (_disposed) {
        frame.dispose();
        return;
      }
      final old = _frame;
      _frame = frame;
      old?.dispose();
      onChanged();
    }, onError: (Object error, StackTrace? stack) {
      if (!_disposed) onChanged(); // fallback remains visible
    });
    setActive(active);
  }

  void setActive(bool active) {
    if (_disposed) return;
    if (active) {
      if (_stream != null) return;
      _stream = _provider.resolve(ImageConfiguration.empty);
      _stream!.addListener(_listener);
    } else {
      _stream?.removeListener(_listener);
      _stream = null;
      _frame?.dispose();
      _frame = null;
    }
  }

  void paint(ui.Canvas canvas, Offset offset) {
    final dst = rect.shift(offset);
    final frame = _frame;
    if (frame != null) {
      paintImage(
          canvas: canvas,
          rect: dst,
          image: frame.image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low);
      return;
    }
    final scale = (dst.width / _fallback.width).clamp(0.01, 1.0);
    canvas.save();
    canvas.translate(
        dst.left, dst.top + (dst.height - _fallback.height * scale) / 2);
    canvas.scale(scale);
    _fallback.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stream?.removeListener(_listener);
    _stream = null;
    _frame?.dispose();
    _frame = null;
    _fallback.dispose();
  }
}
