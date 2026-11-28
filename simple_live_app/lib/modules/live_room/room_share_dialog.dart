import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RoomShareDialog extends StatefulWidget {
  const RoomShareDialog({
    super.key,
    required this.title,
    required this.url,
    required this.shareText,
    required this.onSystemShare,
  });

  final String title;
  final String url;
  final String shareText;
  final Future<void> Function() onSystemShare;

  @override
  State<RoomShareDialog> createState() => _RoomShareDialogState();
}

class _RoomShareDialogState extends State<RoomShareDialog> {
  String? _copyStatus;
  bool _copying = false;
  bool _openingSystemShare = false;

  Future<void> _copy(String text, String success) async {
    setState(() => _copying = true);
    String status;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      status = success;
    } on PlatformException {
      status = '复制失败，可手动选中链接';
    }
    if (!mounted) return;
    setState(() {
      _copying = false;
      _copyStatus = status;
    });
  }

  Future<void> _openSystemShare() async {
    setState(() => _openingSystemShare = true);
    try {
      await widget.onSystemShare();
    } finally {
      if (mounted) setState(() => _openingSystemShare = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('分享直播间'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SelectableText(widget.url),
            const SizedBox(height: 16),
            Center(
              child: Semantics(
                label: '直播间二维码',
                child: SizedBox.square(
                  dimension: 168,
                  child: QrImageView(
                    data: widget.url,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (_, __) => const Text('链接无法生成二维码'),
                  ),
                ),
              ),
            ),
            if (_copyStatus != null)
              Semantics(liveRegion: true, child: Text(_copyStatus!)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _copying ? null : () => _copy(widget.url, '已复制链接'),
          child: const Text('复制链接'),
        ),
        TextButton(
          onPressed:
              _copying ? null : () => _copy(widget.shareText, '已复制标题和链接'),
          child: const Text('复制标题和链接'),
        ),
        TextButton(
          onPressed: _openingSystemShare ? null : _openSystemShare,
          child: const Text('Windows 系统分享'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
