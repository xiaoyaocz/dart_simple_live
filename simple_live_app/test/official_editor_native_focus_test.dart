import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Enter focus requests the actual WebView2 keyboard controller',
      () async {
    final calls = <String>[];
    const channel =
        MethodChannel('com.pichillilorenzo/flutter_inappwebview_editor-focus');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final dynamic controller = WindowsInAppWebViewController(
        const PlatformInAppWebViewControllerCreationParams(id: 'editor-focus'));
    expect(await controller.requestFocus(), isTrue);
    expect(calls, ['requestFocus']);
  });
}
