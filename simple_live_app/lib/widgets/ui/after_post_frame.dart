import 'package:flutter/widgets.dart';

mixin AfterFirstFrameMixin<T extends StatefulWidget> on State<T> {
  bool _afterFirstFrame = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _afterFirstFrame = true;
    });
  }

  void afterFirstFrame(void Function() callback) {
    if (_afterFirstFrame) {
      callback();
    }
  }
}
