// ignore_for_file: prefer_inlined_adds

import 'package:get/get.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_tv_app/modules/indexed/indexed_page.dart';

import 'route_path.dart';

class AppPages {
  AppPages._();
  static final routes = [
    // 首页
    GetPage(
      name: RoutePath.kIndexed,
      page: () => const IndexedPage(),
      bindings: [
        BindingsBuilder.put(() => IndexedController()),
        BindingsBuilder.put(() => HomeController()),
      ],
    ),
  ];
}
