import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:lottie/lottie.dart';

class AppLoaddingWidget extends StatelessWidget {
  const AppLoaddingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppStyle.edgeInsetsA12,
        child: LottieBuilder.asset(
          'assets/lotties/loadding.json',
          width: 200,
        ),
      ),
    );
  }
}
