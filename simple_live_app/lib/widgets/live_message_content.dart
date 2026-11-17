import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'danmaku/models/danmaku_content_item.dart';

/// Equal providers share Flutter's decoded image/animation stream and the
/// existing app disk cache. Decode to at most 96px high, not full-size stickers.
ImageProvider emoticonImageProvider(LiveEmoticon image) =>
    ResizeImage.resizeIfNeeded(
        null,
        96,
        ExtendedNetworkImageProvider(image.url,
            cache: true,
            cacheMaxAge: const Duration(days: 7),
            timeLimit: const Duration(seconds: 4),
            retries: 0,
            printError: false,
            headers: image.headers));

List<DanmakuSpan> emoticonDanmakuSpans(List<LiveMessagePart> parts) => [
      for (final part in parts)
        if (part.emoticon case final LiveEmoticon image)
          DanmakuSpan.image(part.text, emoticonImageProvider(image),
              aspectRatio: image.aspectRatio)
        else
          DanmakuSpan.text(part.text),
    ];

class LiveMessageContent extends StatelessWidget {
  final bool isSelf;
  final String userName;
  final List<LiveMessagePart> parts;
  final double fontSize;
  final Color color;
  final ImageProvider Function(LiveEmoticon) imageProvider;
  const LiveMessageContent(
      {super.key,
      required this.userName,
      required this.parts,
      required this.fontSize,
      required this.color,
      this.imageProvider = emoticonImageProvider,
      this.isSelf = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selfAccent =
        dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    return Text.rich(TextSpan(
      text: isSelf ? null : '$userName：',
      style: TextStyle(color: Colors.grey, fontSize: fontSize),
      children: [
        if (isSelf) ...[
          WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('我',
                      style: TextStyle(
                          fontSize: fontSize * .70,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)))),
          TextSpan(
              text: '$userName：',
              style:
                  TextStyle(color: selfAccent, fontWeight: FontWeight.w600)),
        ],
          for (final part in parts)
            if (part.emoticon case final LiveEmoticon image)
              WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Semantics(
                    label: part.text,
                    image: true,
                    child: Image(
                        image: imageProvider(image),
                        height: fontSize * 1.3,
                        width: fontSize * 1.3 * image.aspectRatio,
                        fit: BoxFit.contain,
                        // Keep the original label while loading and after decode/network
                        // errors; failed pictures must not erase the chat body.
                        frameBuilder: (context, child, frame, sync) =>
                            frame == null ? _fallback(part.text) : child,
                        errorBuilder: (context, error, stack) =>
                            _fallback(part.text)),
                  ))
            else
              TextSpan(text: part.text, style: TextStyle(color: color,
                  fontWeight: isSelf ? FontWeight.normal : null)),
        ],
      ));
  }

  Widget _fallback(String text) =>
      Text(text, style: TextStyle(color: color, fontSize: fontSize));
}

/// A static highlight: no timers, fades, scroll requests or duplicated messages.
class SelfChatHighlight extends StatelessWidget {
  const SelfChatHighlight({super.key, required this.child});
  final Widget child;

  static bool matches(
    String userName, {
    String ownNickname = const String.fromEnvironment('SELF_CHAT_NICKNAME'),
    Iterable<String> extraNicknames = const [],
  }) {
    if (userName.isEmpty) return false;
    if (ownNickname.isNotEmpty && userName == ownNickname) return true;
    return extraNicknames.any((name) => name.isNotEmpty && name == userName);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        key: const ValueKey('self-chat-highlight'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF1B2E45), Color(0xFF252440)]
                : const [Color(0xFFEAF2FF), Color(0xFFF3ECFF)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 1.0,
            color: dark ? const Color(0x5560A5FA) : const Color(0x4D3B82F6),
          ),
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x22000000) : const Color(0x143B82F6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}
