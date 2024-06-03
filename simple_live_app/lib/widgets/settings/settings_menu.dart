import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';

class SettingsMenu<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Map<T, String> valueMap;
  final T value;

  final Function(T)? onChanged;
  const SettingsMenu({
    required this.title,
    required this.value,
    required this.valueMap,
    this.subtitle,
    this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            valueMap[value]!.tr,
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
      onTap: () => openMenu(context),
    );
  }

  void openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true, //useSafeArea似乎无效
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: valueMap.keys
                .map(
                  (e) => RadioListTile(
                    value: e,
                    groupValue: value,
                    title: Text(
                      (valueMap[e]?.tr) ?? "???",
                      style: Get.textTheme.bodyMedium,
                    ),
                    onChanged: (e) {
                      Get.back();
                      onChanged?.call(e as T);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
