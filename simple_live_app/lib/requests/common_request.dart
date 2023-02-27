import 'package:dio/dio.dart';
import 'package:simple_live_app/models/version_model.dart';

/// 通用的请求
class CommonRequest {
  /// 检查更新
  Future<VersionModel> checkUpdate() async {
    var result = await Dio().get(
      "https://cdn.jsdelivr.net/gh/xiaoyaocz/dart_simple_live@master/assets/app_version.json",
      queryParameters: {
        "ts": DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(
        responseType: ResponseType.json,
      ),
    );
    return VersionModel.fromJson(result.data);
  }
}
