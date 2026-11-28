import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simple_live_app/services/room_emoticons.dart';
import 'package:simple_live_app/widgets/live_message_content.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// Uses original platform pictures and text tokens, not Unicode substitutes.
class DanmakuEmoticonPanel extends StatefulWidget {
  const DanmakuEmoticonPanel(
      {super.key,
      required this.catalog,
      required this.onSelected,
      this.imageProvider = emoticonImageProvider});
  final RoomEmoticons? catalog;
  final ValueChanged<String> onSelected;
  final ImageProvider Function(LiveEmoticon) imageProvider;
  @override
  State<DanmakuEmoticonPanel> createState() => _DanmakuEmoticonPanelState();
}

class _DanmakuEmoticonPanelState extends State<DanmakuEmoticonPanel> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await widget.catalog?.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    if (catalog == null) {
      return const Center(
          child: Text('表情暂未就绪', style: TextStyle(color: Colors.white70)));
    }
    return ListenableBuilder(
        listenable: catalog,
        builder: (context, _) {
          final entries = catalog.available;
          // Bilibili word emotes are landscape stickers, not square icons.
          final wide = catalog.platform == 'bilibili' ||
              entries.any((image) => image.aspectRatio >= 1.8);
          if (entries.isEmpty) {
            return Center(
                child: catalog.loading
                    ? const CircularProgressIndicator()
                    : const Text('暂未获取到平台表情',
                        style: TextStyle(color: Colors.white70)));
          }
          return LayoutBuilder(
              builder: (context, constraints) => Scrollbar(
                    controller: scroll,
                    thumbVisibility: true,
                    child: GridView.builder(
                      key: const ValueKey('danmaku-emoticon-grid'),
                      controller: scroll,
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              (constraints.maxWidth / (wide ? 112 : 56))
                                  .floor()
                                  .clamp(wide ? 2 : 4, wide ? 4 : 8),
                          mainAxisExtent: wide ? 64 : 48),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final image = entries[index];
                        return Tooltip(
                            message: image.text,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => widget.onSelected(image.text),
                              child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image(
                                      image: widget.imageProvider(image),
                                      fit: BoxFit.contain,
                                      semanticLabel: image.text,
                                      errorBuilder: (_, __, ___) => Text(
                                          image.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70)))),
                            ));
                      },
                    ),
                  ));
        });
  }
}

class EmoticonMenuEntry extends PopupMenuEntry<String> {
  const EmoticonMenuEntry(
      {super.key, required this.height, required this.child});
  @override
  final double height;
  final Widget child;
  @override
  bool represents(String? value) => false;
  @override
  State<EmoticonMenuEntry> createState() => _EmoticonMenuEntryState();
}

class _EmoticonMenuEntryState extends State<EmoticonMenuEntry> {
  @override
  Widget build(BuildContext context) => widget.child;
}
