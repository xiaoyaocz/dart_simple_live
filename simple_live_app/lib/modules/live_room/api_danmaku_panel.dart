import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simple_live_app/services/bilibili_danmaku_sender.dart';
import 'package:simple_live_app/services/danmaku_sender.dart';
import 'package:simple_live_app/services/douyu_native_sender.dart';
import 'package:simple_live_app/services/search_danmaku_credentials.dart';
import 'package:simple_live_app/services/room_emoticons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/services/official_composer_transport.dart';
import 'official_danmaku_panel.dart';
import 'danmaku_composer.dart';

/// API-capable platforms do not load a second full live page to show an input.
class ApiDanmakuPanel extends StatefulWidget {
  const ApiDanmakuPanel(
      {super.key,
      required this.siteId,
      required this.roomId,
      required this.focusRequest,
      required this.resolveLoginView,
      this.isCurrent,
      this.emoticons,
      this.onMessageSent,
      this.roomUri,
      this.searchEnvironment,
      this.confirmationRoomIds = const [],
      this.onSelfNameDetected,
      this.onIdentityDetected,
      this.senderFactory});
  final String siteId, roomId;
  final int focusRequest;
  final SearchLoginView? Function() resolveLoginView;
  final bool Function()? isCurrent;
  final RoomEmoticons? Function()? emoticons;
  final ValueChanged<String>? onMessageSent;
  final Uri? roomUri;
  final Future<WebViewEnvironment?>? searchEnvironment;
  final List<String> confirmationRoomIds;
  final ValueChanged<String>? onSelfNameDetected;
  final void Function(String? userId, String? userName)? onIdentityDetected;
  final DanmakuSender Function(DanmakuCredentials)? senderFactory;
  @override
  State<ApiDanmakuPanel> createState() => _ApiDanmakuPanelState();
}

class _ApiDanmakuPanelState extends State<ApiDanmakuPanel> {
  final draft = TextEditingController();
  late final SearchDanmakuCredentials credentials;
  late final DanmakuSender sender;
  OfficialComposerTransport? _officialTransport;
  String message = '使用搜索网页的登录态发送';
  bool sending = false;
  @override
  void initState() {
    super.initState();
    credentials = SearchDanmakuCredentials(
        siteId: widget.siteId, resolveView: widget.resolveLoginView);
    Future<Map<String, String>> read(Uri uri) async {
      if (!mounted || widget.isCurrent?.call() == false) {
        throw StateError('Room changed');
      }
      final value = await credentials.read(uri);
      if (!mounted || widget.isCurrent?.call() == false) {
        throw StateError('Room changed');
      }
      if (widget.siteId == 'bilibili' &&
          value['DedeUserID']?.isNotEmpty == true) {
        widget.onIdentityDetected?.call(value['DedeUserID'], null);
      }
      return value;
    }

    if (widget.senderFactory == null &&
        const {'huya', 'douyin'}.contains(widget.siteId)) {
      _officialTransport = OfficialComposerTransport();
    }
    sender = widget.senderFactory?.call(read) ??
        _officialTransport ??
        switch (widget.siteId) {
          'bilibili' =>
            BilibiliDanmakuSender(roomId: widget.roomId, credentials: read),
          'douyu' => DouyuNativeSender(
              roomId: widget.roomId,
              credentials: read,
              onIdentity: (id) => widget.onIdentityDetected?.call(id, null)),
          _ => throw ArgumentError.value(
              widget.siteId, 'siteId', 'No API adapter'),
        };
  }

  Future<bool> send() async {
    if (sending || widget.isCurrent?.call() == false) return false;
    final text = draft.text;
    setState(() {
      sending = true;
      message = '正在等待平台确认…';
    });
    try {
      final wireText = widget.emoticons?.call()?.encodeForSend(text) ?? text;
      final result = await sender.send(wireText);
      if (!mounted || widget.isCurrent?.call() == false) return false;
      setState(() => message = result.message);
      if (result.sent && (result.userId != null || result.userName != null))
        widget.onIdentityDetected?.call(result.userId, result.userName);
      if (result.status == 'login') widget.onIdentityDetected?.call(null, null);
      if (result.sent) widget.onMessageSent?.call(text);
      return result.sent;
    } catch (_) {
      if (mounted) setState(() => message = '发送结果未确认，请先查看聊天，避免重复发送');
      return false;
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    unawaited(sender.dispose());
    unawaited(credentials.dispose());
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        if (_officialTransport != null)
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 400,
              child: ExcludeFocus(
                  child: ExcludeSemantics(
                      child: IgnorePointer(
                          child: Opacity(
                              opacity: 0,
                              child: OfficialDanmakuPanel(
                                siteId: widget.siteId,
                                siteName: widget.siteId,
                                roomUri: widget.roomUri ??
                                    Uri.https(
                                        widget.siteId == 'huya'
                                            ? 'www.huya.com'
                                            : 'live.douyin.com',
                                        '/${widget.roomId}'),
                                allowedRoomIds: [widget.roomId],
                                confirmationRoomIds: widget.confirmationRoomIds,
                                searchEnvironment: widget.searchEnvironment,
                                composerTransport: _officialTransport,
                                expanded: false,
                                focusRequest: 0,
                                onExpandedChanged: (_) {},
                                onFocusedChanged: (_) {},
                                onSelfNameDetected: widget.onSelfNameDetected,
                                onIdentityDetected: widget.onIdentityDetected,
                                onConnectionMessage: (value) {
                                  if (mounted && !sending && widget.isCurrent?.call() != false) {
                                    setState(() => message = value);
                                  }
                                },
                              )))))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          DanmakuComposer(
              draft: draft,
              send: send,
              emoticons: widget.emoticons,
              prepare: sender.prepare,
              autofocus: widget.focusRequest > 0,
              focusRequest: widget.focusRequest),
          SizedBox(
              height: 24,
              child: Semantics(
                  liveRegion: true,
                  child: Tooltip(
                      message: message,
                      child: Text(message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant))))),
        ])
      ]);
}
