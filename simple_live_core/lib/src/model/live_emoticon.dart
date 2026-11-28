/// A platform image, not a Unicode substitute. [text] is also the fallback label.
class LiveEmoticon {
  final String text;
  final String url;
  final double width;
  final double height;
  final Map<String, String> headers;
  const LiveEmoticon({
    required this.text,
    required this.url,
    this.width = 1,
    this.height = 1,
    this.headers = const {},
  });

  double get aspectRatio =>
      width.isFinite && height.isFinite && width > 0 && height > 0
      ? (width / height).clamp(0.25, 6).toDouble()
      : 1;

  static String? normalizeUrl(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final s = value.startsWith('//') ? 'https:$value' : value;
    final uri = Uri.tryParse(s);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty)
      return null;
    return uri.toString();
  }
}

class LiveMessagePart {
  final String text;
  final LiveEmoticon? emoticon;
  const LiveMessagePart.text(this.text) : emoticon = null;
  LiveMessagePart.image(LiveEmoticon image)
    : text = image.text,
      emoticon = image;
}

/// Literal trie: O(message length * longest token), no regex injection or
/// scanning the whole platform library for every incoming chat message.
class EmoticonCatalog {
  // Platforms emit both [打call] and [打Call]; only fold ASCII letters,
  // never transliterate Chinese labels or touch the original fallback text.
  static int _key(int unit) => unit >= 65 && unit <= 90 ? unit + 32 : unit;
  final _root = _EmoticonNode();
  int _length = 0;
  int get length => _length;
  EmoticonCatalog([Iterable<LiveEmoticon> images = const []]) {
    addAll(images);
  }

  void addAll(Iterable<LiveEmoticon> images) {
    for (final image in images) {
      if (image.text.isEmpty ||
          image.text.length > 200 ||
          LiveEmoticon.normalizeUrl(image.url) == null)
        continue;
      var node = _root;
      for (final unit in image.text.codeUnits) {
        node = node.children.putIfAbsent(_key(unit), _EmoticonNode.new);
      }
      if (node.image == null) _length++;
      node.image = image;
    }
  }

  List<LiveMessagePart> split(String text) {
    final parts = <LiveMessagePart>[];
    var plainStart = 0;
    var i = 0;
    while (i < text.length) {
      var node = _root;
      LiveEmoticon? match;
      var end = i;
      for (var j = i; j < text.length; j++) {
        final next = node.children[_key(text.codeUnitAt(j))];
        if (next == null) break;
        node = next;
        if (node.image != null) {
          match = node.image;
          end = j + 1;
        }
      }
      if (match == null) {
        i++;
        continue;
      }
      if (plainStart < i)
        parts.add(LiveMessagePart.text(text.substring(plainStart, i)));
      parts.add(
        LiveMessagePart.image(
          LiveEmoticon(
            text: text.substring(i, end),
            url: match.url,
            width: match.width,
            height: match.height,
            headers: match.headers,
          ),
        ),
      );
      i = end;
      plainStart = end;
    }
    if (plainStart < text.length || parts.isEmpty) {
      parts.add(LiveMessagePart.text(text.substring(plainStart)));
    }
    return List.unmodifiable(parts);
  }

  List<LiveMessagePart> enrich(List<LiveMessagePart> parts) =>
      List.unmodifiable([
        for (final part in parts)
          if (part.emoticon != null) part else ...split(part.text),
      ]);
}

class _EmoticonNode {
  final children = <int, _EmoticonNode>{};
  LiveEmoticon? image;
}
