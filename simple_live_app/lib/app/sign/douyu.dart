import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

class DouyuSign {
  static Future<String> getSign(String html, String rid) async {
    JavascriptRuntime flutterJs = getJavascriptRuntime();
    // 注入 CryptoJS
    var cryptoJs =
        await rootBundle.loadString('assets/scripts/crypto-js.min.js');
    await flutterJs.evaluateAsync(cryptoJs);

    var did = "10000000000000000000000000001501";
    var time = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    await flutterJs.evaluateAsync(html);
    var data =
        (await flutterJs.evaluateAsync("ub98484234('$rid','$did','$time')"))
            .stringResult;
    flutterJs.dispose();
    return data;
  }
}
