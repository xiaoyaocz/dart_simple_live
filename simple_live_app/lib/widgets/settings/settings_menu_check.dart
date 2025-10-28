import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';

class _MenuCheckController<T> extends GetxController {
  final RxList<T> selectedItems;

  _MenuCheckController(List<T> initial)
      : selectedItems = RxList<T>.from(initial);

  void toggle(T item) {
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
    } else {
      selectedItems.add(item);
    }
  }
}

class SettingsMenuCheck<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<T> items;
  final List<T> initialSelection;
  final Future<List<T>> Function()? itemsProvider;
  final List<T> Function(List<T> providedItems)? initialSelectionProvider;

  final String Function(T item) itemToString;
  final Function(List<T> selectedItems)? onConfirm;
  final String? confirmText;
  final String? modalTitle;

  const SettingsMenuCheck({
    required this.title,
    required this.itemToString,
    this.items = const [],
    this.initialSelection = const [],
    this.itemsProvider,
    this.initialSelectionProvider,
    this.subtitle,
    this.onConfirm,
    this.confirmText,
    this.modalTitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 这里需要状态管理，暂时不实现
    final displayItemsCount = items.length;
    final displaySelectedCount = initialSelection.length;

    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyle.radius8,
      ),
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 8),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Get.textTheme.bodySmall!.copyWith(color: Colors.grey),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$displaySelectedCount/$displayItemsCount',
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.grey),
          ),
          AppStyle.hGap4,
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
        ],
      ),
      onTap: _handleTap,
    );
  }

  Future<void> _handleTap() async {
    List<T> menuItems;
    List<T> menuInitialSelection;
    if (itemsProvider != null) {
      SmartDialog.showLoading(msg: "");
      try {
        menuItems = await itemsProvider!();
        if (initialSelectionProvider != null) {
          menuInitialSelection = initialSelectionProvider!(menuItems);
        } else {
          menuInitialSelection = menuItems.toList();
        }
      } finally {
        SmartDialog.dismiss();
      }
    } else {
      menuItems = items;
      menuInitialSelection = initialSelection;
    }

    if (menuItems.isEmpty) {
      return;
    }

    _openMenu(Get.context!, menuItems, menuInitialSelection);
  }

  void _openMenu(
      BuildContext context, List<T> items, List<T> initialSelection) {
    final controller = _MenuCheckController<T>(initialSelection);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(
                  left: 12,
                ),
                title: Text(
                  modalTitle?.tr ?? title.tr,
                ),
                trailing: IconButton(
                  onPressed: () {
                    Get.back();
                    onConfirm?.call(controller.selectedItems.toList());
                  },
                  icon: const Icon(Remix.delete_bin_line),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      return Obx(() => CheckboxListTile(
                            value: controller.selectedItems.contains(item),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              itemToString(item),
                              style: Get.textTheme.bodyMedium,
                            ),
                            onChanged: (bool? selected) {
                              controller.toggle(item);
                            },
                          ));
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
