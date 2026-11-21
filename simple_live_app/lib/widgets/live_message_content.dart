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
  final TextStyle? labelStyle;
  final ImageProvider Function(LiveEmoticon) imageProvider;
  const LiveMessageContent(
      {super.key,
      required this.userName,
      required this.parts,
      required this.fontSize,
      required this.color,
      this.labelStyle,
      this.imageProvider = emoticonImageProvider,
      this.isSelf = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selfAccent =
        dark ? const Color(0xFFA4D1C7) : const Color(0xFF245650);
    final bodyFontSize = isSelf ? fontSize * 1.2 : fontSize;
    final bodyStyle = TextStyle(
      color: color,
      fontSize: bodyFontSize,
      fontWeight: isSelf ? FontWeight.w600 : null,
    );
    return Text.rich(TextSpan(
      text: isSelf ? null : '$userName：',
      style: (labelStyle ?? const TextStyle(color: Colors.grey))
          .copyWith(fontSize: fontSize),
      children: [
        if (isSelf)
          TextSpan(
              text: '我 · $userName：',
              style:
                  TextStyle(color: selfAccent, fontWeight: FontWeight.w600)),
          for (final part in parts)
            if (part.emoticon case final LiveEmoticon image)
              WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Semantics(
                    label: part.text,
                    image: true,
                    child: Image(
                        image: imageProvider(image),
                        height: bodyFontSize * 1.3,
                        width: bodyFontSize * 1.3 * image.aspectRatio,
                        fit: BoxFit.contain,
                        // Keep the original label while loading and after decode/network
                        // errors; failed pictures must not erase the chat body.
                        frameBuilder: (context, child, frame, sync) =>
                            frame == null
                                ? Text(part.text, style: bodyStyle)
                                : child,
                        errorBuilder: (context, error, stack) =>
                            Text(part.text, style: bodyStyle)),
                  ))
            else
              TextSpan(text: part.text, style: bodyStyle),
        ],
      ));
  }

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
          color: dark ? const Color(0xFF233832) : const Color(0xFFE2EEEC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}
