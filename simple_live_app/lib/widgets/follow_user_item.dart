import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/room_entry_warmup.dart';
import 'dart:ui' as ui;

class FollowUserItemCompactStyle {
  final double avatarSize;
  final double titleFontSize;
  final double metaFontSize;
  final double siteLogoSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showStatusText;

  const FollowUserItemCompactStyle({
    required this.avatarSize,
    required this.titleFontSize,
    required this.metaFontSize,
    required this.siteLogoSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.borderRadius = 10,
    this.showStatusText = true,
  });
}

class FollowUserItem extends StatelessWidget {
  final FollowUser item;
  final Function()? onRemove;
  final Function()? onTap;
  final Function()? onLongPress;
  final bool playing;
  final FollowUserItemCompactStyle? compactStyle;
  const FollowUserItem({
    required this.item,
    this.onRemove,
    this.onTap,
    this.onLongPress,
    this.playing = false,
    this.compactStyle,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var site = Sites.allSites[item.siteId]!;
    if (compactStyle != null) {
      return _buildCompactCard(context, site, compactStyle!);
    }
    final tile = ListTile(
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 4),
      leading: NetImage(
        item.face,
        width: 48,
        height: 48,
        borderRadius: 24,
      ),
      title: Text.rich(
        TextSpan(
          text: item.userName,
          children: [
            WidgetSpan(
              alignment: ui.PlaceholderAlignment.middle,
              child: Obx(
                () => Offstage(
                  offstage: item.liveStatus.value == 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppStyle.hGap12,
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.liveStatus.value == 2
                              ? Colors.green
                              : Colors.grey,
                          borderRadius: AppStyle.radius12,
                        ),
                      ),
                      AppStyle.hGap4,
                      Text(
                        getStatus(item.liveStatus.value),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color:
                              item.liveStatus.value == 2 ? null : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      subtitle: Wrap(
        runSpacing: 1.0,
        children: [
          Image.asset(
            site.logo,
            width: 20,
          ),
          AppStyle.hGap4,
          Text(
            site.name,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (playing)
            Padding(
              padding: AppStyle.edgeInsetsL8,
              child: Text(
                "正在观看",
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (item.liveStatus.value == 2 && item.liveStartTime != null)
            Padding(
              padding: AppStyle.edgeInsetsL8,
              child: Text(
                '开播了${formatLiveDuration(item.liveStartTime)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
      trailing: playing
          ? const SizedBox(
              width: 64,
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                ),
              ),
            )
          : (onRemove == null
              ? null
              : _buildRemoveButton(context)),
      onTap: onTap,
      onLongPress: onLongPress,
    );
    return playing || onTap == null ? tile : RoomEntryWarmup(
      source: site.liveSite, roomId: item.roomId, child: tile);
  }

  Widget _buildCompactCard(
    BuildContext context,
    Site site,
    FollowUserItemCompactStyle style,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(style.borderRadius);

    final card = Material(
      color: playing
          ? colorScheme.primary.withAlpha(24)
          : colorScheme.surfaceContainerHighest.withAlpha(70),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: playing
              ? colorScheme.primary.withAlpha(90)
              : theme.dividerColor.withAlpha(28),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: Padding(
          padding: style.padding,
          child: Row(
            children: [
              NetImage(
                item.face,
                width: style.avatarSize,
                height: style.avatarSize,
                borderRadius: style.avatarSize / 2,
              ),
              SizedBox(width: style.avatarSize >= 36 ? 10 : 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() {
                      final status = item.liveStatus.value;
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: style.titleFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (status != 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: status == 2 ? Colors.green : Colors.grey,
                                borderRadius: AppStyle.radius12,
                              ),
                            ),
                            if (style.showStatusText) ...[
                              const SizedBox(width: 4),
                              Text(
                                getStatus(status),
                                style: TextStyle(
                                  fontSize: style.metaFontSize,
                                  color: status == 2 ? null : Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 2),
                    Obx(() {
                      final status = item.liveStatus.value;
                      final liveDurationText =
                          status == 2 && item.liveStartTime != null
                              ? formatLiveDuration(item.liveStartTime)
                              : '';
                      return Row(
                        children: [
                          Image.asset(
                            site.logo,
                            width: style.siteLogoSize,
                            height: style.siteLogoSize,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: site.name,
                                style: TextStyle(
                                  fontSize: style.metaFontSize,
                                  color: Colors.grey,
                                ),
                                children: [
                                  if (playing)
                                    TextSpan(
                                      text: ' · 正在观看',
                                      style: TextStyle(
                                        fontSize: style.metaFontSize,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (liveDurationText.isNotEmpty)
                                    TextSpan(
                                      text: ' 开播了$liveDurationText',
                                      style: TextStyle(
                                        fontSize: style.metaFontSize,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              if (playing) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return playing || onTap == null
        ? card
        : RoomEntryWarmup(source: site.liveSite, roomId: item.roomId, child: card);
  }

  Widget _buildRemoveButton(BuildContext context) {
    final desktop = const {
      TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux,
    }.contains(Theme.of(context).platform);
    final button = IconButton(
      tooltip: desktop ? '双击鼠标右键取消关注' : '双击取消关注',
      // Absorb primary taps so the surrounding ListTile does not open the room.
      onPressed: () {},
      icon: const Icon(Remix.dislike_line),
    );
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
          () => DoubleTapGestureRecognizer(
            supportedDevices: desktop ? const {PointerDeviceKind.mouse} : null,
            allowedButtonsFilter: (buttons) =>
                buttons == (desktop ? kSecondaryMouseButton : kPrimaryButton),
          ),
          (recognizer) => recognizer.onDoubleTap = onRemove,
        ),
      },
      child: button,
    );
  }

  String getStatus(int status) {
    if (status == 0) {
      return "读取中";
    } else if (status == 1) {
      return "未开播";
    } else {
      return "直播中";
    }
  }

  String formatLiveDuration(String? startTimeStampString) {
    if (startTimeStampString == null ||
        startTimeStampString.isEmpty ||
        startTimeStampString == "0") {
      return "";
    }
    try {
      int startTimeStamp = int.parse(startTimeStampString);
      int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int durationInSeconds = currentTimeStamp - startTimeStamp;

      int hours = durationInSeconds ~/ 3600;
      int minutes = (durationInSeconds % 3600) ~/ 60;

      String hourText = hours > 0 ? '$hours小时' : '';
      String minuteText = minutes > 0 ? '$minutes分钟' : '';

      if (hours == 0 && minutes == 0) {
        return "不足1分钟";
      }

      return '$hourText$minuteText';
    } catch (e) {
      Log.logPrint('格式化开播时长出错: $e');
      return "--小时--分钟";
    }
  }
}
