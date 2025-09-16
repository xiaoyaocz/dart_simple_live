import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:crypto/crypto.dart';

class DouyinSign {
  static const String defaultUserAgent = DouyinSite.kDefaultUserAgent;
  static Future<String> getAbogusUrl(String url, String userAgent) async {
    JavascriptRuntime flutterJs = getJavascriptRuntime();
    final msToken = generateMsToken(107);
    var params = ('$url&msToken=$msToken').split('?')[1];
    var query = params.contains("?") ? params.split("?")[1] : params;
    var jsCode = await rootBundle.loadString('assets/scripts/a_bogus.js');
    await flutterJs.evaluateAsync(jsCode);
    // 执行getABogus函数
    var aBogus =
        (await flutterJs.evaluateAsync("getABogus('$query', '$userAgent')"))
            .stringResult;
    flutterJs.dispose();
    var newUrl =
        '$url&msToken=${Uri.encodeComponent(msToken)}&a_bogus=${Uri.encodeComponent(aBogus)}';
    return newUrl;
  }

  static Future<String> getSignature(String roomId, String uniqueId) async {
    JavascriptRuntime flutterJs = getJavascriptRuntime();
    var jsCode = await rootBundle.loadString('assets/scripts/webmssdk.js');
    await flutterJs.evaluateAsync(jsCode);
    var msStub = getMsStub(roomId, uniqueId);
    var signature = (await flutterJs
            .evaluateAsync("getMSSDKSignature('$msStub','$defaultUserAgent')"))
        .stringResult;
    // 如果signature中包含-或=，重新生成
    while (signature.contains('-') || signature.contains('=')) {
      signature = (await flutterJs.evaluateAsync(
              "getMSSDKSignature('$msStub','$defaultUserAgent')"))
          .stringResult;
    }
    flutterJs.dispose();
    return signature;
  }

  static String getMsStub(String roomId, String uniqueId) {
    final params = {
      "live_id": "1",
      "aid": "6383",
      "version_code": 180800,
      "webcast_sdk_version": "1.3.0",
      "room_id": roomId,
      "sub_room_id": "",
      "sub_channel_id": "",
      "did_rule": "3",
      "user_unique_id": uniqueId,
      "device_platform": "web",
      "device_type": "",
      "ac": "",
      "identity": "audience"
    };
    final sigParams =
        params.entries.map((e) => "${e.key}=${e.value}").join(',');
    // 需要导入crypto库: import 'package:crypto/crypto.dart';
    final bytes = sigParams.codeUnits;
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  static String generateMsToken(int length) {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
        length, (_) => characters[random.nextInt(characters.length)]).join('');
  }
}
