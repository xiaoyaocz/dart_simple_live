import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:simple_live_app/services/room_emoticons.dart';
import 'danmaku_emoticon_panel.dart';

/// Inline and floating composers share the room's draft, not their focus nodes.
class DanmakuComposer extends StatefulWidget {
  const DanmakuComposer(
      {super.key,
      required this.draft,
      required this.send,
      this.prepare,
      this.emoticons,
      this.onEmoticonRoute,
      this.autofocus = false,
      this.onSent});
  final TextEditingController draft;
  final Future<bool> Function() send;
  final VoidCallback? prepare;
  final RoomEmoticons? Function()? emoticons;
  final ValueChanged<Route<String>>? onEmoticonRoute;
  final bool autofocus;
  final VoidCallback? onSent;
  @override
  State<DanmakuComposer> createState() => _DanmakuComposerState();
}

class _DanmakuComposerState extends State<DanmakuComposer> {
  bool busy = false;
  final focus = FocusNode();
  Route<String>? _emoticonRoute;
  @override
  void dispose() {
    final menu = _emoticonRoute;
    // dispose runs while the widget tree is locked. Remove a surviving popup
    // after finalization rather than setState on Navigator during teardown.
    if (menu != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (menu.isActive) menu.navigator?.removeRoute(menu);
      });
    }
    focus.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        widget.draft.text.trim().isEmpty ||
        !widget.draft.value.composing.isCollapsed) {
      return;
    }
    final sent = widget.draft.text;
    setState(() => busy = true);
    try {
      final success = await widget.send();
      if (success && widget.draft.text == sent) {
        widget.draft.clear();
        if (mounted) widget.onSent?.call();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void insertEmoji(String emoji) {
    final value = widget.draft.value;
    final start =
        value.selection.isValid ? value.selection.start : value.text.length;
    final end =
        value.selection.isValid ? value.selection.end : value.text.length;
    widget.draft.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    focus.requestFocus();
  }

  Future<void> openEmoticons(BuildContext anchorContext) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final anchor = anchorContext.findRenderObject()! as RenderBox;
    final rect =
        anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    final width = math.min(448.0, overlay.size.width - 16);
    final height = math.min(320.0, overlay.size.height - 32);
    final left = (rect.right - width)
        .clamp(8.0, math.max(8.0, overlay.size.width - width - 8))
        .toDouble();
    final top = (rect.top - height - 8)
        .clamp(8.0, math.max(8.0, overlay.size.height - height - 8))
        .toDouble();
    final selected = await showMenu<String>(
        context: context,
        color: const Color(0xff30313d),
        surfaceTintColor: Colors.transparent,
        menuPadding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: width),
        position: RelativeRect.fromLTRB(
            left, top, overlay.size.width - left - width, 0),
        items: [
          EmoticonMenuEntry(
              height: height,
              child: SizedBox(
                  width: width,
                  height: height,
                  child: Builder(builder: (menuContext) {
                    final menu = ModalRoute.of(menuContext)! as Route<String>;
                    if (!identical(_emoticonRoute, menu)) {
                      _emoticonRoute = menu;
                      widget.onEmoticonRoute?.call(menu);
                    }
                    final navigator = Navigator.of(menuContext);
                    return DanmakuEmoticonPanel(
                        catalog: widget.emoticons?.call(),
                        onSelected: (text) => navigator.pop(text));
                  })))
        ]);
    if (mounted && selected != null) insertEmoji(selected);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
                child: TextField(
              controller: widget.draft, focusNode: focus,
              autofocus: widget.autofocus,
              onTap: widget.prepare,
              textInputAction: TextInputAction.send,
              // EditableText's default completion clears IME composing before
              // onSubmitted. Preserve it so accepting a Chinese candidate cannot send.
              onEditingComplete: () {},
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(
                hintText: '与大家互动一下…',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            )),
            Builder(
                builder: (anchorContext) => IconButton(
                    tooltip: '表情',
                    padding: EdgeInsets.zero,
                    onPressed: busy ? null : () => openEmoticons(anchorContext),
                    icon: const Icon(Icons.sentiment_satisfied_alt, size: 20))),
            IconButton(
              tooltip: '发送弹幕（Enter）',
              onPressed: busy ? null : submit,
              visualDensity: VisualDensity.compact,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_circle_up, size: 24),
            ),
          ]),
        ),
      );
}

Future<void> showDanmakuComposer(
  BuildContext context, {
  required TextEditingController draft,
  required Future<bool> Function() send,
  RoomEmoticons? Function()? emoticons,
  ValueChanged<Route<String>>? onEmoticonRoute,
  void Function(Route<void>)? onRoute,
}) async {
  late final DialogRoute<void> route;
  route = DialogRoute<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(dialogContext).pop(),
        },
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DanmakuComposer(
                draft: draft,
                send: send,
                emoticons: emoticons,
                onEmoticonRoute: onEmoticonRoute,
                autofocus: true,
                onSent: () {
                  if (!route.isActive) return;
                  if (route.isCurrent) {
                    route.navigator?.pop();
                  } else {
                    route.navigator?.removeRoute(route);
                  }
                }),
          ),
        )),
  );
  onRoute?.call(route);
  await Navigator.of(context, rootNavigator: true).push(route);
}
