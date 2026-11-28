import 'dart:async';
import 'package:flutter/gestures.dart';

/// 鼠标侧键点击手势识别器
/// - https://github.com/flutter/flutter/issues/115641
/// - https://github.com/witnet/my-wit-wallet/pull/261
class FourthButtonTapGestureRecognizer extends BaseTapGestureRecognizer {
  FourthButtonTapGestureRecognizer({this.button = kBackMouseButton});
  final int button;
  GestureTapCallback? onTap;
  GestureTapCallback? onDoubleTap;
  Timer? _singleTapTimer;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    // 只识别鼠标返回侧键，不能抢占视频双击、按钮或手机触摸。
    return event.kind == PointerDeviceKind.mouse &&
        event.buttons == button &&
        super.isPointerAllowed(event);
  }

  @override
  void handleTapDown({required PointerDownEvent down}) {}

  @override
  void handleTapCancel(
      {required PointerDownEvent down,
      PointerCancelEvent? cancel,
      required String reason}) {}

  @override
  void handleTapUp(
      {required PointerDownEvent down, required PointerUpEvent up}) {
    // TapDown 会在长按超时后先于手势仲裁触发，嵌套页面和全局可能同时后退。
    // TapUp 只发给获胜者，取消或拖动也不会误触发返回。
    if (onDoubleTap == null) {
      if (onTap != null) invokeCallback<void>('onTap', onTap!);
    } else if (_singleTapTimer?.isActive == true) {
      _singleTapTimer!.cancel();
      _singleTapTimer = null;
      invokeCallback<void>('onDoubleTap', onDoubleTap!);
    } else {
      // 等待第二次点击，双击时不先执行一次网页后退。
      _singleTapTimer = Timer(kDoubleTapTimeout, () {
        _singleTapTimer = null;
        if (onTap != null) invokeCallback<void>('onTap', onTap!);
      });
    }
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }
}

class ForwardButtonTapGestureRecognizer
    extends FourthButtonTapGestureRecognizer {
  ForwardButtonTapGestureRecognizer() : super(button: kForwardMouseButton);
}
