import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:lottie/lottie.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class AppEmptyWidget extends StatelessWidget {
  final Function()? onRefresh;
  final String? text;
  const AppEmptyWidget({
    this.onRefresh,
    this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          onRefresh?.call();
        },
        child: Padding(
          padding: AppStyle.edgeInsetsA48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieBuilder.asset(
                'assets/lotties/empty.json',
                width: 160.w,
                height: 160.w,
                repeat: false,
              ),
              AppStyle.vGap24,
              Text(
                text ?? "这里什么都没有",
                textAlign: TextAlign.center,
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap24,
              if (onRefresh != null)
                HighlightButton(
                  text: "刷新",
                  iconData: Icons.refresh,
                  onTap: onRefresh,
                  focusNode: AppFocusNode(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
