import 'package:flutter/material.dart';

class NoneBorderCircularTextField extends StatelessWidget {
  final TextEditingController editingController;
  final String? hintText;
  final String? helperText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final bool obscureText;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final Widget? trailing;
  final TextInputType? inputType;
  final int? maxLines;
  final bool autoFocus;
  final FocusNode? focusNode;
  final bool? enable;
  final bool readOnly;

  final bool needPadding;

  const NoneBorderCircularTextField({
    Key? key,
    required this.editingController,
    this.hintText,
    this.helperText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
    this.maxLines = 1,
    this.onEditingComplete,
    this.trailing,
    this.autoFocus = false,
    this.focusNode,
    this.inputType,
    this.onChanged,
    this.onTap,
    this.enable,
    this.readOnly = false,
    this.needPadding = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextField common = TextField(
      enabled: enable,
      readOnly: readOnly,
      decoration: InputDecoration(
        prefixIcon: prefixIcon,
        hintText: hintText,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        suffix: trailing,
        helperText: helperText,
        helperMaxLines: 3,
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        labelText: labelText,
        errorText: errorText,
        errorMaxLines: 3,
      ),
      textAlign: textAlign,
      autofocus: autoFocus,
      keyboardType: inputType,
      maxLines: maxLines,
      controller: editingController,
      obscureText: obscureText,
      onEditingComplete: onEditingComplete,
      onChanged: onChanged,
      onTap: onTap,
      focusNode: focusNode,
    );
    if (needPadding) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 10,
          bottom: 10,
        ),
        child: common,
      );
    } else {
      return common;
    }
  }
}
