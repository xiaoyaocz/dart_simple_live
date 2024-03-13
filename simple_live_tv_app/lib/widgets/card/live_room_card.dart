import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';
import 'package:marquee/marquee.dart';

class LiveRoomCard extends StatelessWidget {
  final String cover;
  final String title;
  final String anchor;
  final String roomId;
  final int online;
  final bool autofocus;
  final AppFocusNode focusNode;
  final Function()? onTap;
  const LiveRoomCard({
    required this.cover,
    required this.title,
    required this.anchor,
    required this.roomId,
    required this.focusNode,
    required this.online,
    this.autofocus = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightWidget(
      focusNode: focusNode,
      color: Colors.white10,
      onTap: onTap,
      borderRadius: AppStyle.radius16,
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.w),
                topRight: Radius.circular(16.w),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: NetImage(
                      cover,
                      cacheWidth: 400,
                    ),
                  ),
                  Positioned(
                    right: 8.w,
                    top: 8.w,
                    child: Container(
                      padding:
                          AppStyle.edgeInsetsH8.copyWith(top: 4.w, bottom: 4.w),
                      decoration: BoxDecoration(
                        color: focusNode.isFoucsed.value
                            ? Colors.white
                            : Colors.black54,
                        borderRadius: AppStyle.radius8,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: "",
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: AppStyle.edgeInsetsR8,
                                child: Icon(
                                  Icons.whatshot,
                                  color: focusNode.isFoucsed.value
                                      ? Colors.orange
                                      : Colors.white,
                                  size: 20.w,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: Utils.onlineToString(online),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 20.w,
                          color: focusNode.isFoucsed.value
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // child: Container(
              //   height: 200.w,
              // ),
            ),
            AppStyle.vGap8,
            Padding(
              padding: AppStyle.edgeInsetsH20,
              child: SizedBox(
                height: 56.w,
                child: focusNode.isFoucsed.value
                    ? Marquee(
                        text: title,
                        style: AppStyle.textStyleBlack,
                        startAfter: const Duration(seconds: 1),
                        velocity: 20,
                        blankSpace: 200.w,
                        //decelerationDuration: const Duration(seconds: 2),
                        scrollAxis: Axis.horizontal,
                      )
                    : Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: AppStyle.textStyleWhite,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppStyle.hGap20,
                Icon(
                  Icons.account_circle,
                  color: focusNode.isFoucsed.value
                      ? Colors.black54
                      : Colors.white54,
                  size: 32.w,
                ),
                AppStyle.hGap12,
                Expanded(
                  child: Text(
                    anchor,
                    style: focusNode.isFoucsed.value
                        ? AppStyle.subTextStyleBlack
                        : AppStyle.subTextStyleWhite,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            AppStyle.vGap12,
          ],
        ),
      ),
    );
  }
}
