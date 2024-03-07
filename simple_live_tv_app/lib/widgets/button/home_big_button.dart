import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';

class HomeBigButton extends StatelessWidget {
  final String text;
  final IconData iconData;
  final AppFocusNode focusNode;
  final Function()? onTap;
  final bool autofocus;
  const HomeBigButton({
    required this.iconData,
    required this.text,
    this.onTap,
    required this.focusNode,
    this.autofocus = false,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => HighlightWidget(
        onTap: onTap,
        autofocus: autofocus,
        focusNode: focusNode,
        borderRadius: AppStyle.radius16,
        color: Colors.white10,
        child: Container(
          padding: AppStyle.edgeInsetsA32.copyWith(left: 48.w, right: 48.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppStyle.edgeInsetsA12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  size: 64.w,
                  color:
                      focusNode.isFoucsed.value ? Colors.black : Colors.white,
                ),
              ),
              AppStyle.vGap24,
              Text(
                text,
                style: TextStyle(
                  fontSize: 36.w,
                  color:
                      focusNode.isFoucsed.value ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
