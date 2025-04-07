import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';

class SettingsNumber extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String unit;
  final int value;
  final int step;
  final int min;
  final int max;
  final String? displayValue;
  final Function(int)? onChanged;
  const SettingsNumber(
      {required this.title,
      required this.value,
      required this.max,
      this.subtitle,
      this.onChanged,
      this.step = 1,
      this.min = 0,
      this.unit = '',
      this.displayValue,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(
        title,
        style: Get.textTheme.bodyLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyle.radius8,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Get.textTheme.bodySmall!.copyWith(color: Colors.grey),
            ),
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 12),
      trailing: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(25),
          borderRadius: AppStyle.radius24,
        ),
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: AppStyle.edgeInsetsA4,
              constraints: const BoxConstraints(
                minHeight: 32,
              ),
              onPressed: () {
                int newValue = value - step;
                if (newValue < min) {
                  newValue = min;
                }
                onChanged?.call(newValue);
              },
              icon: Icon(
                Icons.remove,
                color: Get.textTheme.bodyMedium!.color!.withAlpha(150),
              ),
            ),
            Text(
              displayValue ?? "$value$unit",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.grey),
            ),
            IconButton(
              padding: AppStyle.edgeInsetsA4,
              constraints: const BoxConstraints(
                minHeight: 32,
              ),
              onPressed: () {
                int newValue = value + step;
                if (newValue > max) {
                  newValue = max;
                }
                onChanged?.call(newValue);
              },
              icon: Icon(
                Icons.add,
                color: Get.textTheme.bodyMedium!.color!.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
      onTap: () => openSilder(context),
    );
  }

  void openSilder(BuildContext context) {
    var newValue = value.obs;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true, //useSafeArea似乎无效
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsH16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Get.textTheme.titleMedium,
                  ),
                  Obx(
                    () => Text(
                      "${newValue.value}$unit",
                      style: Get.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Obx(
              () => Slider(
                value: newValue.value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                onChanged: (e) {
                  newValue.value = e.toInt();
                },
              ),
            ),
            Padding(
              padding: AppStyle.edgeInsetsH16,
              child: TextButton(
                onPressed: () {
                  onChanged?.call(newValue.value);
                  Get.back();
                },
                child: const Text("确定"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
