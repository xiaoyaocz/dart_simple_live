import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simple_live_app/services/web_danmaku_sender.dart';

class _OriginalPage implements InAppWebViewController {
  int checks = 0;
  int sends = 0;
  int resumes = 0;
  final operations = <String>[];
  final handlers = <String, JavaScriptHandlerCallback>{};
  @override
  Future<void> resume() async { resumes++; throw StateError('Hidden original page must not be made visible'); }
  @override
  Future<dynamic> evaluateJavascript({required String source, ContentWorld? contentWorld}) async => throw StateError('Original page was initialized at document start');
  @override
  void addJavaScriptHandler({required String handlerName, required JavaScriptHandlerCallback callback}) { handlers[handlerName] = callback; }
  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler({required String handlerName}) => handlers.remove(handlerName);
  @override
  Future<dynamic> callDevToolsProtocolMethod({required String methodName, Map<String, dynamic>? parameters}) async { operations.add(methodName); return {}; }
  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({required String functionBody, Map<String, dynamic> arguments = const {}, ContentWorld? contentWorld}) async {
    if (arguments['prepareOnly'] == true) {
      checks++;
      return CallAsyncJavaScriptResult(value: {'status': checks == 1 ? 'login' : 'ready', 'message':'fixture'});
    }
    sends++;
    final callback = handlers[arguments['nativeInputHandler']];
    if (callback == null) throw StateError('native input handler missing');
    final edit = await callback([{'action':'edit'}]);
    final submit = arguments['site'] != 'douyin' || await callback([{'action':'submit', 'enter':true}]) == true;
    if (edit != true || submit != true) throw StateError('native input was not accepted');
    return CallAsyncJavaScriptResult(value:{'status':'sent','message':'fixture'});
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all platforms reuse original page, await account hydration and submit through native input', () async {
    for (final site in ['huya','douyu','bilibili','douyin']) {
      final page = _OriginalPage();
      var current = true;
      final sender = WebDanmakuSender(siteId: site, roomUri: Uri.https('example.test','/1'),
        existingView: page, isExistingViewCurrent: () => current,
        environmentFactory: () => throw StateError('must not create a second browser'));
      expect((await sender.send('original page')).sent, isTrue);
      expect(page.checks, 2);
      expect(page.sends, 1);
      expect(page.operations, contains('Input.insertText'));
      expect(page.resumes, 0);
      expect(page.operations.where((e) => e == 'Input.dispatchMouseEvent'), isEmpty);
      expect(page.handlers, isEmpty);
      current = false;
      expect((await sender.send('wrong room')).sent, isFalse);
      expect(page.sends, 1);
      await sender.dispose(); // Must NOT dispose the borrowed original page.
    }
  });
  test('a failed prewarm is released before the next explicit send', () async {
    var attempts = 0;
    final sender = WebDanmakuSender(
        siteId: 'huya',
        roomUri: Uri.https('www.huya.com', '/1'),
        environmentFactory: () async {
          attempts++;
          throw StateError('offline');
        });
    sender.prepare();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 1);
    await sender.send('test');
    expect(attempts, 2);
    await sender.dispose();
  });
  test('initialization failure is retryable and no message is submitted',
      () async {
    var attempts = 0;
    final sender = WebDanmakuSender(
        siteId: 'huya',
        roomUri: Uri.https('www.huya.com', '/123'),
        environmentFactory: () async {
          attempts++;
          throw StateError('fixture startup failure');
        });
    expect((await sender.send('first')).status, 'initialization_error');
    expect((await sender.send('second')).status, 'initialization_error');
    expect(attempts, 2);
    await sender.dispose();
    expect((await sender.send('closed')).status, 'closed');
    expect(attempts, 2);
  });
  test('unknown responses are never accepted as sent', () {
    for (final value in [
      null,
      true,
      {},
      {'status': 'unknown', 'message': '未确认'}
    ]) {
      expect(DanmakuSendResult.fromValue(value).sent, isFalse);
    }
  });
}
