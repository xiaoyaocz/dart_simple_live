import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/live_room_card.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SearchListView extends StatelessWidget {
  final String tag;
  const SearchListView(this.tag, {Key? key}) : super(key: key);
  SearchListController get controller =>
      Get.find<SearchListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    var roomRowCount = MediaQuery.of(context).size.width ~/ 200;
    if (roomRowCount < 2) roomRowCount = 2;

    var userRowCount = MediaQuery.of(context).size.width ~/ 500;
    if (userRowCount < 1) userRowCount = 1;
    return KeepAliveWrapper(
      child: Obx(
        () => controller.searchMode.value == 0
            ? PageGridView(
                pageController: controller,
                padding: AppStyle.edgeInsetsA12,
                firstRefresh: false,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                crossAxisCount: roomRowCount,
                showPageLoadding: true,
                itemBuilder: (_, i) {
                  var item = controller.list[i] as LiveRoomItem;
                  return LiveRoomCard(controller.site, item);
                },
              )
            : PageGridView(
                crossAxisSpacing: 12,
                crossAxisCount: userRowCount,
                pageController: controller,
                firstRefresh: true,
                itemBuilder: (_, i) {
                  var item = controller.list[i] as LiveAnchorItem;

                  return ListTile(
                    leading: NetImage(
                      item.avatar,
                      width: 48,
                      height: 48,
                      borderRadius: 24,
                    ),
                    title: Text(item.userName),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: item.liveStatus ? Colors.green : Colors.grey,
                            borderRadius: AppStyle.radius12,
                          ),
                        ),
                        AppStyle.hGap4,
                        Text(
                          item.liveStatus ? "直播中" : "未开播",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: item.liveStatus ? null : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      AppNavigator.toLiveRoomDetail(
                          site: controller.site, roomId: item.roomId);
                    },
                  );
                },
              ),
      ),
    );
  }
}
