import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:lottie/lottie.dart';

class AppErrorWidget extends StatelessWidget {
  final Function()? onRefresh;
  final String errorMsg;
  const AppErrorWidget({this.errorMsg = "", this.onRefresh, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          onRefresh?.call();
        },
        child: Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieBuilder.asset(
                'assets/lotties/error.json',
                width: 260,
                repeat: false,
              ),
              Text(
                "$errorMsg\r\n点击刷新",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
