import 'package:flutter_js/flutter_js.dart';
import 'package:flutter/services.dart';

class JsEngine {
  static JavascriptRuntime? _jsRuntime;

  static JavascriptRuntime get jsRuntime => _jsRuntime!;

  static void init() {
    _jsRuntime ??= getJavascriptRuntime();
    jsRuntime.enableHandlePromises();
  }

  static Future<JsEvalResult> evaluateAsync(String code) {
    return jsRuntime.evaluateAsync(code);
  }

  static Future<void> loadJSFile(String path) async {
    final jsCode = await rootBundle.loadString(path);
    jsRuntime.evaluate(jsCode);
  }

  static void dispose() {
    _jsRuntime?.dispose();
  }
}
