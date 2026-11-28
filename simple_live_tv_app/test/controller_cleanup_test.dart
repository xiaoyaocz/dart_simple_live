import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';

void main() {
  testWidgets('home clock timer stops when its owner closes', (tester) async {
    final controller = HomeController();
    controller.initTimer();
    controller.onClose();
    await tester.pump(const Duration(seconds: 1));
  });
  test('page controller releases its scroll notifier on close', () {
    final controller = BasePageController();
    controller.onClose();
    expect(() => controller.scrollController.addListener(() {}),
        throwsFlutterError);
  });
}
