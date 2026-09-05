import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/live_room_grid_layout.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class HomeListView extends StatelessWidget {
  final String tag;
  const HomeListView(this.tag, {Key? key}) : super(key: key);
  HomeListController get controller => Get.find<HomeListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = LiveRoomGridLayout.resolve(
            constraints.maxWidth,
            detailsExtent: LiveRoomCard.detailsExtent,
          );
          return PageGridView(
            pageController: controller,
            padding: AppStyle.edgeInsetsA12,
            firstRefresh: true,
            mainAxisSpacing: LiveRoomGridLayout.defaultSpacing,
            crossAxisSpacing: LiveRoomGridLayout.defaultSpacing,
            mainAxisExtent: layout.mainAxisExtent,
            useFixedGrid: true,
            crossAxisCount: layout.crossAxisCount,
            itemBuilder: (_, i) {
              var item = controller.list[i];
              return LiveRoomCard(controller.site, item);
            },
          );
        },
      ),
    );
  }
}
