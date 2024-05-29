import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class AppColors {
  static ColorScheme lightColorScheme = ColorScheme.fromSwatch(
    primarySwatch: Colors.pink,
    brightness: Brightness.dark,
    //primaryColorDark: const Color(0xfff06595),
    accentColor: const Color(0xfff06595),
  );
}

class AppStyle {
  static ThemeData lightTheme = ThemeData(
    colorScheme: AppColors.lightColorScheme,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
    ),
    scaffoldBackgroundColor: const Color(0xfffafafa),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.all(AppColors.lightColorScheme.primary),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(AppColors.lightColorScheme.primary),
    ),
    fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
  );

  static SizedBox get vGap4 => SizedBox(
        height: 4.w,
      );
  static SizedBox get vGap8 => SizedBox(
        height: 8.w,
      );
  static SizedBox get vGap12 => SizedBox(
        height: 12.w,
      );
  static SizedBox get vGap16 => SizedBox(
        height: 16.w,
      );
  static SizedBox get vGap24 => SizedBox(
        height: 24.w,
      );
  static SizedBox get vGap32 => SizedBox(
        height: 32.w,
      );
  static SizedBox get vGap40 => SizedBox(
        height: 40.w,
      );
  static SizedBox get vGap48 => SizedBox(
        height: 48.w,
      );
  static SizedBox get hGap4 => SizedBox(
        width: 4.w,
      );
  static SizedBox get hGap8 => SizedBox(
        width: 8.w,
      );
  static SizedBox get hGap12 => SizedBox(
        width: 12.w,
      );
  static SizedBox get hGap16 => SizedBox(
        width: 16.w,
      );
  static SizedBox get hGap20 => SizedBox(
        width: 20.w,
      );
  static SizedBox get hGap24 => SizedBox(
        width: 24.w,
      );
  static SizedBox get hGap32 => SizedBox(
        width: 32.w,
      );
  static SizedBox get hGap40 => SizedBox(
        width: 40.w,
      );
  static SizedBox get hGap48 => SizedBox(
        width: 48.w,
      );

  static EdgeInsets get edgeInsetsH4 => EdgeInsets.symmetric(horizontal: 4.w);
  static EdgeInsets get edgeInsetsH8 => EdgeInsets.symmetric(horizontal: 8.w);
  static EdgeInsets get edgeInsetsH12 => EdgeInsets.symmetric(horizontal: 12.w);
  static EdgeInsets get edgeInsetsH16 => EdgeInsets.symmetric(horizontal: 16.w);
  static EdgeInsets get edgeInsetsH20 => EdgeInsets.symmetric(horizontal: 20.w);
  static EdgeInsets get edgeInsetsH24 => EdgeInsets.symmetric(horizontal: 24.w);
  static EdgeInsets get edgeInsetsH32 => EdgeInsets.symmetric(horizontal: 32.w);
  static EdgeInsets get edgeInsetsH40 => EdgeInsets.symmetric(horizontal: 40.w);
  static EdgeInsets get edgeInsetsH48 => EdgeInsets.symmetric(horizontal: 48.w);

  static EdgeInsets get edgeInsetsV4 => EdgeInsets.symmetric(vertical: 4.w);
  static EdgeInsets get edgeInsetsV8 => EdgeInsets.symmetric(vertical: 8.w);
  static EdgeInsets get edgeInsetsV12 => EdgeInsets.symmetric(vertical: 12.w);
  static EdgeInsets get edgeInsetsV24 => EdgeInsets.symmetric(vertical: 24.w);
  static EdgeInsets get edgeInsetsV32 => EdgeInsets.symmetric(vertical: 32.w);
  static EdgeInsets get edgeInsetsV40 => EdgeInsets.symmetric(vertical: 40.w);
  static EdgeInsets get edgeInsetsV48 => EdgeInsets.symmetric(vertical: 48.w);

  static EdgeInsets get edgeInsetsA4 => EdgeInsets.all(4.w);
  static EdgeInsets get edgeInsetsA8 => EdgeInsets.all(8.w);
  static EdgeInsets get edgeInsetsA12 => EdgeInsets.all(12.w);
  static EdgeInsets get edgeInsetsA16 => EdgeInsets.all(16.w);
  static EdgeInsets get edgeInsetsA20 => EdgeInsets.all(20.w);
  static EdgeInsets get edgeInsetsA24 => EdgeInsets.all(24.w);
  static EdgeInsets get edgeInsetsA32 => EdgeInsets.all(32.w);
  static EdgeInsets get edgeInsetsA40 => EdgeInsets.all(40.w);
  static EdgeInsets get edgeInsetsA48 => EdgeInsets.all(48.w);

  static EdgeInsets get edgeInsetsR4 => EdgeInsets.only(right: 4.w);
  static EdgeInsets get edgeInsetsR8 => EdgeInsets.only(right: 8.w);
  static EdgeInsets get edgeInsetsR12 => EdgeInsets.only(right: 12.w);
  static EdgeInsets get edgeInsetsR16 => EdgeInsets.only(right: 16.w);
  static EdgeInsets get edgeInsetsR20 => EdgeInsets.only(right: 20.w);
  static EdgeInsets get edgeInsetsR24 => EdgeInsets.only(right: 24.w);

  static EdgeInsets get edgeInsetsL4 => EdgeInsets.only(left: 4.w);
  static EdgeInsets get edgeInsetsL8 => EdgeInsets.only(left: 8.w);
  static EdgeInsets get edgeInsetsL12 => EdgeInsets.only(left: 12.w);
  static EdgeInsets get edgeInsetsL16 => EdgeInsets.only(left: 16.w);
  static EdgeInsets get edgeInsetsL20 => EdgeInsets.only(left: 20.w);
  static EdgeInsets get edgeInsetsL24 => EdgeInsets.only(left: 24.w);

  static EdgeInsets get edgeInsetsT4 => EdgeInsets.only(top: 4.w);
  static EdgeInsets get edgeInsetsT8 => EdgeInsets.only(top: 8.w);
  static EdgeInsets get edgeInsetsT12 => EdgeInsets.only(top: 12.w);
  static EdgeInsets get edgeInsetsT24 => EdgeInsets.only(top: 24.w);

  static EdgeInsets get edgeInsetsB4 => EdgeInsets.only(bottom: 4.w);
  static EdgeInsets get edgeInsetsB8 => EdgeInsets.only(bottom: 8.w);
  static EdgeInsets get edgeInsetsB12 => EdgeInsets.only(bottom: 12.w);
  static EdgeInsets get edgeInsetsB24 => EdgeInsets.only(bottom: 24.w);

  static BorderRadius get radius4 => BorderRadius.circular(4.w);
  static BorderRadius get radius8 => BorderRadius.circular(8.w);
  static BorderRadius get radius12 => BorderRadius.circular(12.w);
  static BorderRadius get radius16 => BorderRadius.circular(16.w);
  static BorderRadius get radius24 => BorderRadius.circular(24.w);
  static BorderRadius get radius32 => BorderRadius.circular(32.w);
  static BorderRadius get radius48 => BorderRadius.circular(48.w);

  static const colorBlack33 = Color(0xff333333);

  /// 顶部状态栏的高度
  static double get statusBarHeight => MediaQuery.of(Get.context!).padding.top;

  /// 底部导航条的高度
  static double get bottomBarHeight =>
      MediaQuery.of(Get.context!).padding.bottom;

  static TextStyle get titleStyleWhite => TextStyle(
        color: Colors.white,
        fontSize: 40.w,
      );
  static TextStyle get titleStyleBlack => TextStyle(
        color: colorBlack33,
        fontSize: 40.w,
      );
  static TextStyle get textStyleWhite => TextStyle(
        color: Colors.white,
        fontSize: 32.w,
      );
  static TextStyle get textStyleBlack => TextStyle(
        color: colorBlack33,
        fontSize: 32.w,
      );
  static TextStyle get subTextStyleWhite => TextStyle(
        color: Colors.white54,
        fontSize: 24.w,
        height: 1.0,
      );
  static TextStyle get subTextStyleBlack => TextStyle(
        color: Colors.black54,
        fontSize: 24.w,
        height: 1.0,
      );

  static List<BoxShadow> get highlightShadow => [
        BoxShadow(
          blurRadius: 6.w,
          spreadRadius: 2.w,
          color: Colors.pink.shade400,
          //color: Color.fromARGB(255, 255, 120, 167),
        )
      ];
}
