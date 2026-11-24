import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';

/// TV 端文本输入框
///
/// 裸 [TextField] 在 TV 上自动聚焦后，软键盘未必弹出，且遥控器 OK 键
/// 无法再次唤起。本组件用外层 [AppFocusNode] 承接 D-pad 焦点，确认键
/// （select/enter/space）按下时显式把焦点交给内部输入框并唤起输入法，
/// 解决「有光标、无键盘」的问题。
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final AppFocusNode? focusNode;
  final bool autofocus;
  final String? hintText;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;

  const AppTextField({
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.hintText,
    this.style,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.decoration,
    super.key,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final AppFocusNode _outerNode = widget.focusNode ?? AppFocusNode();
  final FocusNode _fieldNode = FocusNode();
  late final bool _ownsOuterNode = widget.focusNode == null;

  @override
  void dispose() {
    _fieldNode.dispose();
    if (_ownsOuterNode) {
      _outerNode.dispose();
    }
    super.dispose();
  }

  /// 确认键：把焦点交给内部输入框并唤起输入法
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.select &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    // 内部输入框已聚焦（键盘流程中），交给 EditableText 正常处理
    if (_fieldNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    _activateKeyboard();
    return KeyEventResult.handled;
  }

  void _activateKeyboard() {
    _fieldNode.requestFocus();
    // 部分 TV 系统对聚焦自带的 show 不响应；在按键上下文内再显式唤起兜底
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fieldNode.hasFocus) {
        return;
      }
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      // 真机（S905X4 等 TV ROM）可能把上面的请求整条取消，原生层再兜底：
      // 窗口 STATE_ALWAYS_VISIBLE + showSoftInput，仍未弹出则强制唤起
      if (Platform.isAndroid) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (_fieldNode.hasFocus) {
            const MethodChannel("simple_live_tv/ime")
                .invokeMethod<void>("showKeyboard");
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _outerNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: widget.controller,
        focusNode: _fieldNode,
        style: widget.style ?? AppStyle.textStyleWhite,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        onSubmitted: widget.onSubmitted,
        decoration:
            widget.decoration ??
            InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: AppStyle.edgeInsetsA12,
              hintText: widget.hintText,
            ),
      ),
    );
  }
}
