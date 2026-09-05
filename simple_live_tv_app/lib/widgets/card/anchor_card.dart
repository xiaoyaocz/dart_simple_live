import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

enum AnchorCardDisplayStyle {
  defaultList,
  compact,
  card,
}

class AnchorCard extends StatelessWidget {
  final String siteId;
  final String face;
  final String name;
  final String roomId;
  final String roomTitle;
  final String roomCover;
  final int liveStatus;
  final bool autofocus;
  final bool playing;
  final bool showLiveCover;
  final Function()? onTap;
  final AppFocusNode? focusNode;
  final AnchorCardDisplayStyle displayStyle;

  const AnchorCard({
    required this.face,
    required this.siteId,
    required this.name,
    required this.liveStatus,
    required this.roomId,
    this.roomTitle = "",
    this.roomCover = "",
    this.autofocus = false,
    this.playing = false,
    this.showLiveCover = false,
    this.focusNode,
    this.onTap,
    this.displayStyle = AnchorCardDisplayStyle.defaultList,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final site = Sites.allSites[siteId]!;
    final focusNode = this.focusNode ?? AppFocusNode();
    return Obx(
      () => HighlightWidget(
        onTap: onTap ??
            () {
              AppNavigator.toLiveRoomDetail(site: site, roomId: roomId);
            },
        focusNode: focusNode,
        autofocus: autofocus,
        borderRadius: AppStyle.radius16,
        color: Colors.white10,
        child: _buildCard(context, site, focusNode.isFoucsed.value),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Site site, bool focused) {
    switch (displayStyle) {
      case AnchorCardDisplayStyle.compact:
        return _buildListCard(context, site, focused, compact: true);
      case AnchorCardDisplayStyle.card:
        return showLiveCover
            ? _buildPreviewCard(context, site, focused)
            : _buildAvatarCard(context, site, focused);
      case AnchorCardDisplayStyle.defaultList:
        return _buildListCard(context, site, focused, compact: false);
    }
  }

  Widget _buildListCard(
    BuildContext context,
    Site site,
    bool focused, {
    required bool compact,
  }) {
    if (!showLiveCover) {
      return _buildAvatarListCard(context, site, focused, compact: compact);
    }
    final coverWidth = compact ? 190.w : 250.w;
    final avatarSize = compact ? 50.w : 58.w;
    final titleStyle = TextStyle(
      fontSize: compact ? 24.w : 28.w,
      fontWeight: FontWeight.w600,
      overflow: TextOverflow.ellipsis,
      color: focused ? Colors.black : Colors.white,
    );
    final subStyle = TextStyle(
      fontSize: compact ? 20.w : 22.w,
      color: focused ? Colors.black87 : Colors.white70,
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: EdgeInsets.all(compact ? 12.w : 16.w),
      decoration: BoxDecoration(
        borderRadius: AppStyle.radius16,
        border: Border.all(
          color: playing ? Colors.lightGreenAccent : Colors.white24,
          width: playing ? 2.w : 1.w,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: coverWidth,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildCover(site, focused),
            ),
          ),
          AppStyle.hGap16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NetImage(
                      face,
                      width: avatarSize,
                      height: avatarSize,
                      borderRadius: avatarSize / 2,
                      cacheWidth: 100,
                    ),
                    AppStyle.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, style: titleStyle),
                          SizedBox(height: 4.w),
                          Text(
                            _displayTitle,
                            maxLines: compact ? 1 : 2,
                            style: subStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 8.w,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Image.asset(site.logo, width: compact ? 22.w : 26.w),
                    Text(site.name, style: subStyle),
                    _buildBadge(
                      text: _statusText,
                      active: liveStatus == 2,
                      focused: focused,
                    ),
                    if (playing)
                      _buildBadge(
                        text: "正在观看",
                        active: true,
                        focused: focused,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarListCard(
    BuildContext context,
    Site site,
    bool focused, {
    required bool compact,
  }) {
    final avatarSize = compact ? 58.w : 72.w;
    final titleStyle = TextStyle(
      fontSize: compact ? 24.w : 28.w,
      fontWeight: FontWeight.w600,
      overflow: TextOverflow.ellipsis,
      color: focused ? Colors.black : Colors.white,
    );
    final subStyle = TextStyle(
      fontSize: compact ? 20.w : 22.w,
      color: focused ? Colors.black87 : Colors.white70,
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14.w : 18.w,
        vertical: compact ? 10.w : 14.w,
      ),
      decoration: BoxDecoration(
        borderRadius: AppStyle.radius16,
        border: Border.all(
          color: playing ? Colors.lightGreenAccent : Colors.white24,
          width: playing ? 2.w : 1.w,
        ),
      ),
      child: Row(
        children: [
          NetImage(
            face,
            width: avatarSize,
            height: avatarSize,
            borderRadius: avatarSize / 2,
            cacheWidth: 120,
          ),
          AppStyle.hGap16,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, style: titleStyle),
                SizedBox(height: compact ? 8.w : 10.w),
                Row(
                  children: [
                    Image.asset(site.logo, width: compact ? 22.w : 26.w),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(site.name, maxLines: 1, style: subStyle),
                    ),
                    SizedBox(width: 12.w),
                    _buildBadge(
                      text: _statusText,
                      active: liveStatus == 2,
                      focused: focused,
                    ),
                    if (playing) ...[
                      SizedBox(width: 10.w),
                      _buildBadge(
                        text: "正在观看",
                        active: true,
                        focused: focused,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, Site site, bool focused) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppStyle.radius16,
        border: Border.all(
          color: playing ? Colors.lightGreenAccent : Colors.white24,
          width: playing ? 2.w : 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildCover(site, focused),
          ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetImage(
                  face,
                  width: 42.w,
                  height: 42.w,
                  borderRadius: 21.w,
                  cacheWidth: 80,
                ),
                AppStyle.hGap12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 24.w,
                          fontWeight: FontWeight.w600,
                          color: focused ? Colors.black : Colors.white,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 4.w),
                      Text(
                        _displayTitle,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 20.w,
                          color: focused ? Colors.black87 : Colors.white70,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 8.w),
                      Row(
                        children: [
                          Image.asset(site.logo, width: 20.w),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              site.name,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 18.w,
                                color:
                                    focused ? Colors.black87 : Colors.white70,
                              ),
                            ),
                          ),
                          _buildBadge(
                            text: _statusText,
                            active: liveStatus == 2,
                            focused: focused,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(BuildContext context, Site site, bool focused) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: AppStyle.radius16,
        border: Border.all(
          color: playing ? Colors.lightGreenAccent : Colors.white24,
          width: playing ? 2.w : 1.w,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NetImage(
            face,
            width: 92.w,
            height: 92.w,
            borderRadius: 46.w,
            cacheWidth: 180,
          ),
          SizedBox(height: 18.w),
          Text(
            name,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28.w,
              fontWeight: FontWeight.w600,
              color: focused ? Colors.black : Colors.white,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 14.w),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10.w,
            runSpacing: 8.w,
            children: [
              Image.asset(site.logo, width: 24.w),
              Text(
                site.name,
                style: TextStyle(
                  fontSize: 21.w,
                  color: focused ? Colors.black87 : Colors.white70,
                ),
              ),
              _buildBadge(
                text: _statusText,
                active: liveStatus == 2,
                focused: focused,
              ),
              if (playing)
                _buildBadge(
                  text: "正在观看",
                  active: true,
                  focused: focused,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(Site site, bool focused) {
    final titleColor = focused ? Colors.black : Colors.white;
    if (liveStatus != 2) {
      return ClipRRect(
        borderRadius: AppStyle.radius16,
        child: Container(
          color: focused ? Colors.black.withAlpha(12) : Colors.white10,
          alignment: Alignment.center,
          child: Text(
            "未直播",
            style: TextStyle(
              fontSize: 24.w,
              fontWeight: FontWeight.w600,
              color: focused ? Colors.black54 : Colors.white60,
            ),
          ),
        ),
      );
    }
    final coverImage = _coverImage;
    return ClipRRect(
      borderRadius: AppStyle.radius16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          coverImage.isEmpty
              ? Center(
                  child: Text(
                    "直播封面补齐中",
                    style: TextStyle(
                      fontSize: 20.w,
                      color: focused ? Colors.black54 : Colors.white54,
                    ),
                  ),
                )
              : NetImage(
                  coverImage,
                  borderRadius: 16.w,
                  cacheWidth: 480,
                ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(20),
                  Colors.black.withAlpha(150),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10.w,
            left: 10.w,
            child: _buildBadge(
              text: _statusText,
              active: liveStatus == 2,
              focused: false,
            ),
          ),
          if (playing)
            Positioned(
              top: 10.w,
              right: 10.w,
              child: _buildBadge(
                text: "正在观看",
                active: true,
                focused: false,
              ),
            ),
          Positioned(
            left: 12.w,
            right: 12.w,
            bottom: 10.w,
            child: Text(
              _displayTitle,
              maxLines: 2,
              style: TextStyle(
                fontSize: 20.w,
                fontWeight: FontWeight.w600,
                color: titleColor,
                overflow: TextOverflow.ellipsis,
                shadows: focused
                    ? null
                    : const [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black87,
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required bool active,
    required bool focused,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.w),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withAlpha(focused ? 220 : 190)
            : Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18.w,
          color: active
              ? Colors.white
              : (focused ? Colors.black87 : Colors.white70),
        ),
      ),
    );
  }

  String get _statusText {
    if (liveStatus == 2) {
      return "直播中";
    }
    if (liveStatus == 0) {
      return "未确认";
    }
    return "未开播";
  }

  String get _displayTitle {
    final title = roomTitle.trim();
    if (liveStatus == 2) {
      if (title.isNotEmpty) {
        return title;
      }
      return showLiveCover ? "直播封面与标题补齐中" : name;
    }
    return name;
  }

  String get _coverImage {
    if (liveStatus != 2) {
      return "";
    }
    return roomCover.trim();
  }
}
