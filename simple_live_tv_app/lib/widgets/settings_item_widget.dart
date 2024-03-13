import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';

class SettingsItemWidget extends StatelessWidget {
  final AppFocusNode foucsNode;
  final Map<dynamic, String> items;
  final dynamic value;
  final String title;
  final bool autofocus;
  final Function(dynamic) onChanged;
  const SettingsItemWidget({
    required this.foucsNode,
    required this.items,
    required this.value,
    required this.title,
    required this.onChanged,
    this.autofocus = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightWidget(
      focusNode: foucsNode,
      autofocus: autofocus,
      borderRadius: AppStyle.radius16,
      onLeftKey: () {
        if (items.isEmpty) return KeyEventResult.handled;
        if (items.keys.first == value) {
          onChanged(items.keys.last);
        } else {
          onChanged(
              items.keys.elementAt(items.keys.toList().indexOf(value) - 1));
        }
        return KeyEventResult.handled;
      },
      onRightKey: () {
        if (items.isEmpty) return KeyEventResult.handled;
        if (items.keys.last == value) {
          onChanged(items.keys.first);
        } else {
          onChanged(
              items.keys.elementAt(items.keys.toList().indexOf(value) + 1));
        }
        return KeyEventResult.handled;
      },
      onTap: () {
        showSettingsDialog();
      },
      child: Obx(
        () => Padding(
          padding: AppStyle.edgeInsetsA24,
          child: Row(
            children: [
              Text(
                title,
                style: foucsNode.isFoucsed.value
                    ? AppStyle.textStyleBlack
                    : AppStyle.textStyleWhite,
              ),
              const Spacer(),
              if (foucsNode.isFoucsed.value && items.isNotEmpty)
                Icon(
                  Icons.chevron_left,
                  size: 40.w,
                  color:
                      foucsNode.isFoucsed.value ? Colors.black : Colors.white,
                ),
              AppStyle.hGap12,
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: 120.w),
                child: Text(
                  items[value] ?? '',
                  style: foucsNode.isFoucsed.value
                      ? AppStyle.textStyleBlack
                      : AppStyle.textStyleWhite,
                  textAlign: foucsNode.isFoucsed.value
                      ? TextAlign.center
                      : TextAlign.right,
                ),
              ),
              AppStyle.hGap12,
              if (foucsNode.isFoucsed.value && items.isNotEmpty)
                Icon(
                  Icons.chevron_right,
                  size: 40.w,
                  color:
                      foucsNode.isFoucsed.value ? Colors.black : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void showSettingsDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: AppStyle.titleStyleWhite),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.keys.map((e) {
            return ListTile(
              title: Text(items[e] ?? '', style: AppStyle.textStyleWhite),
              contentPadding: AppStyle.edgeInsetsH20,
              autofocus: e == value,
              shape: RoundedRectangleBorder(
                borderRadius: AppStyle.radius16,
              ),
              focusColor: Colors.white54,
              onTap: () {
                onChanged(e);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
