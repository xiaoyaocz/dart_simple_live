import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:lottie/lottie.dart';

class AppErrorWidget extends StatelessWidget {
  final Function()? onRefresh;
  final String errorMsg;
  const AppErrorWidget({this.errorMsg = "", this.onRefresh, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppStyle.edgeInsetsA12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LottieBuilder.asset(
              'assets/lotties/error.json',
              width: 200.w,
              repeat: false,
            ),
            AppStyle.vGap24,
            Text(
              errorMsg.isEmpty ? "出错了，请稍后重试" : errorMsg,
              textAlign: TextAlign.center,
              style: AppStyle.textStyleWhite,
            ),
          ],
        ),
      ),
    );
  }
}
