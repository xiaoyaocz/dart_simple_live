import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 拓展FoucsNode
class AppFocusNode extends FocusNode {
  var isFoucsed = false.obs;
  AppFocusNode() {
    isFoucsed.value = hasFocus;
    addListener(updateFoucs);
  }

  updateFoucs() {
    isFoucsed.value = hasFocus;
  }

  @override
  void dispose() {
    removeListener(updateFoucs);
    super.dispose();
  }
}
