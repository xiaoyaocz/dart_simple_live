import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter/services.dart';
import 'package:simple_live_core/simple_live_core.dart';

class JsEngine {
  static FlutterQjs? _engine;

  static void init({int stackSize = 1024 * 1024}) {
    if (_engine == null) {
      _engine = FlutterQjs(stackSize: stackSize);
      _engine!.dispatch();
    }
  }

  static FlutterQjs get engine {
    if (_engine == null) {
      init();
    }
    return _engine!;
  }

  static dynamic evaluate(String code) {
    try {
      return engine.evaluate(code);
    } on JSError catch (e) {
      CoreLog.error("JsEngine evaluate error: $e");
      return null;
    }
  }

  static Future<void> loadJSFile(String path) async {
    try {
      final jsCode = await rootBundle.loadString(path);
      engine.evaluate(jsCode);
    } catch (e) {
      CoreLog.error("JsEngine loadJSFile error: $e");
    }
  }

  static void dispose() {
    try {
      _engine?.port.close();
      _engine?.close();
    } catch (e) {
      CoreLog.error("JsEngine dispose error: $e");
    } finally {
      _engine = null;
    }
  }
}
