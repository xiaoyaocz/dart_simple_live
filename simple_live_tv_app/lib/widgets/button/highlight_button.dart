import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';

class HighlightButton extends StatelessWidget {
  final String text;
  final IconData? iconData;
  final Widget? icon;
  final AppFocusNode focusNode;
  final Function()? onTap;
  final bool autofocus;
  final bool selected;
  const HighlightButton({
    this.iconData,
    required this.text,
    this.icon,
    this.onTap,
    required this.focusNode,
    this.autofocus = false,
    this.selected = false,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => HighlightWidget(
        focusNode: focusNode,
        borderRadius: AppStyle.radius32,
        color: Colors.white10,
        onTap: onTap,
        autofocus: autofocus,
        selected: selected,
        child: Container(
          height: 64.w,
          //width: 64.w,
          padding: AppStyle.edgeInsetsH24,
          decoration: BoxDecoration(
            borderRadius: AppStyle.radius32,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildIcon(),
              Text(
                text,
                style: TextStyle(
                  fontSize: 28.w,
                  color: (focusNode.isFoucsed.value || selected)
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildIcon() {
    if (icon != null || iconData != null) {
      return Padding(
        padding: AppStyle.edgeInsetsR12,
        child: icon ??
            Icon(
              iconData,
              size: 40.w,
              color: (focusNode.isFoucsed.value || selected)
                  ? Colors.black
                  : Colors.white,
            ),
      );
    }
    return const SizedBox();
  }
}
