import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:lottie/lottie.dart';

class AppEmptyWidget extends StatelessWidget {
  final Function()? onRefresh;
  const AppEmptyWidget({this.onRefresh, Key? key}) : super(key: key);

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
                'assets/lotties/empty.json',
                width: 200,
                height: 200,
                repeat: false,
              ),
              const Text(
                "这里什么都没有",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
