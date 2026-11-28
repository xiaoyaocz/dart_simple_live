import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('page controller releases its scroll notifier on close', () {
    final controller = BasePageController();
    controller.onClose();
    expect(() => controller.scrollController.addListener(() {}),
        throwsFlutterError);
  });
}
