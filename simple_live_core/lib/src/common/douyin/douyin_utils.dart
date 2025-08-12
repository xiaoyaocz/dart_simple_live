import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/common/js_engine.dart';

class DouyinUtils {
// 根据传入长度产生随机字符串
  static String getMSToken({int randomLength = 107}) {
    var baseStr =
        'ABCDEFGHIGKLMNOPQRSTUVWXYZabcdefghigklmnopqrstuvwxyz0123456789=';
    var sb = StringBuffer();
    for (var i = 0; i < randomLength; i++) {
      var index = Random().nextInt(baseStr.length);
      sb.write(baseStr[index]);
    }
    return sb.toString();
  }

  static Future<String> getAbogus(
      {required String reqUrl, required String userAgent}) async {
    try {
      JsEngine.init();
      await JsEngine.loadJSFile(
          "packages/simple_live_core/assets/js/a_bogus.js");
      String abogus =
          JsEngine.evaluate("generate_a_bogus('$reqUrl','$userAgent')")
              .stringResult;
      return abogus;
    } catch (e) {
      CoreLog.error(e);
    } finally {
      JsEngine.dispose();
    }
    return "";
  }

  Future<Map<String, String>> get_ttwid_webid({required String req_url}) async {
    // 先请求以获取 ttwid 等 Cookie，再解析页面的 RENDER_DATA 获取 user_unique_id
    final headers = <String, String>{
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0",
      "Accept":
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
      "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    };

    String? ttwid;
    String? webid;

    try {
      // 先用 HEAD 获取 Set-Cookie（包含 ttwid）
      final headResp = await HttpClient.instance.head(
        req_url,
        header: headers,
      );
      final setCookies = headResp.headers["set-cookie"];
      if (setCookies != null) {
        for (final cookieLine in setCookies) {
          final cookie = cookieLine.split(";").first;
          if (cookie.startsWith("ttwid=")) {
            ttwid = cookie.substring("ttwid=".length);
            break;
          }
        }
      }

      // 再用 GET 拉取页面 HTML，解析 RENDER_DATA
      final html = await HttpClient.instance.getText(
        req_url,
        header: headers,
      );

      // 提取 RENDER_DATA 脚本块
      final renderMatches = RegExp(
        r'<script id=\"RENDER_DATA\" type=\"application\/json\">(.*?)<\/script>',
        dotAll: true,
      ).allMatches(html);
      if (renderMatches.isNotEmpty) {
        var renderDataText = renderMatches.first.group(1) ?? "";
        // URL 解码
        try {
          renderDataText = Uri.decodeComponent(renderDataText);
        } catch (_) {}
        try {
          final data = jsonDecode(renderDataText) as Map<String, dynamic>;
          // 路径 app.odin.user_unique_id
          final app = data['app'] as Map<String, dynamic>?;
          final odin = app?['odin'] as Map<String, dynamic>?;
          final uid = odin?['user_unique_id'];
          if (uid != null) {
            webid = uid.toString();
          }
        } catch (e) {
          CoreLog.error('解析 RENDER_DATA 失败: $e');
        }
      }
    } catch (e) {
      CoreLog.error('get_ttwid_webid 错误: $e');
    }

    return {
      'ttwid': ttwid ?? '',
      'webid': webid ?? '',
    };
  }
}
