import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SyncProgressDialog {
  static const _tag = "sync_progress_dialog";
  static final ValueNotifier<SyncProgress> _progress =
      ValueNotifier<SyncProgress>(
    const SyncProgress(stage: "同步中"),
  );

  static void show(SyncProgress progress) {
    _progress.value = progress;
    SmartDialog.show(
      tag: _tag,
      keepSingle: true,
      clickMaskDismiss: false,
      backType: SmartBackType.block,
      builder: (_) => ValueListenableBuilder<SyncProgress>(
        valueListenable: _progress,
        builder: (_, value, __) => _SyncProgressDialogBody(progress: value),
      ),
    );
  }

  static void update(SyncProgress progress) {
    _progress.value = progress;
  }

  static void dismiss() {
    SmartDialog.dismiss(tag: _tag);
  }
}

class _SyncProgressDialogBody extends StatelessWidget {
  final SyncProgress progress;

  const _SyncProgressDialogBody({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressText = progress.total > 0
        ? "${progress.current}/${progress.total}"
        : "--/--";
    return Container(
      width: 320,
      padding: AppStyle.edgeInsetsA24,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppStyle.radius8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.stage,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                progressText,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          AppStyle.vGap12,
          LinearProgressIndicator(
            value: progress.isIndeterminate ? null : progress.percent,
          ),
          AppStyle.vGap12,
          Text(
            progress.displayMessage,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
