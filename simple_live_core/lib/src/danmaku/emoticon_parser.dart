import 'dart:convert';
import 'package:protobuf/protobuf.dart';
import '../model/live_emoticon.dart';
import '../model/live_message.dart';
import 'proto/douyin.pb.dart' as dy;

abstract final class EmoticonParser {
  /// EmojiChatMessage uses a separate event, not ChatMessage.content. Read only
  /// its body fields; never mistake avatar/background decorations for emojis.
  static LiveMessage? douyinEmoji(List<int> bytes) {
    try {
      if (bytes.length > 1024 * 1024) return null;
      final reader = CodedBufferReader(bytes);
      dy.User? user;
      dy.Text? rich;
      var content = '';
      while (!reader.isAtEnd()) {
        final tag = reader.readTag();
        if (tag == 0) break;
        final field = tag >> 3;
        if ((tag & 7) == 2 && field == 2) {
          user = dy.User.fromBuffer(reader.readBytes());
        } else if ((tag & 7) == 2 && field == 4) {
          rich = dy.Text.fromBuffer(reader.readBytes());
        } else if ((tag & 7) == 2 && field == 5) {
          content = reader.readString();
        } else {
          reader.skipField(tag);
        }
      }
      final body = dy.ChatMessage()..content = content;
      if (rich != null) body.rtfContent = rich;
      final parts = douyin(body);
      final fallback = content.isEmpty
          ? parts.map((e) => e.text).join()
          : content;
      if (fallback.isEmpty) return null;
      return LiveMessage(
        type: LiveMessageType.chat,
        userName: user?.nickName ?? '',
        userId: user == null ? null : (user.idStr.isNotEmpty ? user.idStr : user.id.toString()),
        message: fallback,
        parts: parts,
        color: LiveMessageColor.white,
      );
    } catch (_) {
      return null; // Unsupported/malformed optional event cannot kill the batch.
    }
  }

  static double _number(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 1;

  static LiveEmoticon? image(
    String text,
    dynamic data, {
    Map<String, String> headers = const {},
  }) {
    if (data is! Map) return null;
    final url = LiveEmoticon.normalizeUrl(data['url']);
    if (url == null) return null;
    return LiveEmoticon(
      text: text,
      url: url,
      width: _number(data['width']),
      height: _number(data['height']),
      headers: headers,
    );
  }

  static List<LiveMessagePart> bilibili(dynamic info, String text) {
    final images = <LiveEmoticon>[];
    if (info is List && info.isNotEmpty && info.first is List) {
      final meta = info.first as List;
      // Whole-message paid/large emoticons live at info[0][13] on the
      // current wire format; accept [12] for older protocol variants.
      for (final i in [13, 12]) {
        if (meta.length <= i) continue;
        final entry = meta[i];
        if (entry is Map && entry['url'] != null) {
          final e = image(text, entry);
          if (e != null) return [LiveMessagePart.image(e)];
        }
      }
      for (final value in meta) {
        if (value is! Map) continue;
        dynamic extra = value['extra'];
        if (extra is String) {
          try {
            extra = jsonDecode(extra);
          } catch (_) {
            continue;
          }
        }
        if (extra is! Map || extra['emots'] is! Map) continue;
        for (final entry in (extra['emots'] as Map).entries) {
          final e = image('${entry.key}', entry.value);
          if (e != null) images.add(e);
        }
      }
    }
    return EmoticonCatalog(images).split(text);
  }

  static List<LiveMessagePart> douyin(dy.ChatMessage message) {
    if (!message.hasRtfContent())
      return [LiveMessagePart.text(message.content)];
    final parts = <LiveMessagePart>[];
    for (final piece in message.rtfContent.piecesList) {
      if (piece.stringValue.isNotEmpty)
        parts.add(LiveMessagePart.text(piece.stringValue));
      if (piece.hasImageValue()) {
        final image = piece.imageValue.image;
        final url = image.urlListList
            .map(LiveEmoticon.normalizeUrl)
            .whereType<String>()
            .firstOrNull;
        final label = image.content.alternativeText.isNotEmpty
            ? image.content.alternativeText
            : image.content.name;
        if (url != null) {
          parts.add(
            LiveMessagePart.image(
              LiveEmoticon(
                text: label.isEmpty ? '[表情]' : label,
                url: url,
                width: image.width.toDouble(),
                height: image.height.toDouble(),
              ),
            ),
          );
        } else if (label.isNotEmpty) {
          parts.add(LiveMessagePart.text(label));
        }
      }
    }
    // RTF may contain template fragments rather than the body. Never replace
    // the actual chat with badges, nicknames or an incomplete template.
    if (parts.isEmpty ||
        (message.content.isNotEmpty &&
            parts.map((e) => e.text).join() != message.content)) {
      final images = parts.map((p) => p.emoticon).whereType<LiveEmoticon>();
      return EmoticonCatalog(images).split(message.content);
    }
    return List.unmodifiable(parts);
  }
}
