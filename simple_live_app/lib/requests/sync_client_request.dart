import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncClientRequest {
  late final Dio _dio;

  SyncClientRequest({Dio? dio}) {
    _dio = dio ?? _createDirectLanDio();
  }

  static Dio _createDirectLanDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
      ),
    );
    // 局域网同步强制直连，避免 Android Wi-Fi 代理劫持内网 IP 请求。
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..findProxy = (_) => 'DIRECT',
    );
    return dio;
  }

  String _baseUrl(SyncClinet client) => "http://${client.address}:${client.port}";

  Future<Map<String, dynamic>> _get(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw '对端返回格式异常';
    } on DioException catch (e) {
      throw _formatDioError(e);
    }
  }

  Future<Map<String, dynamic>> _post(
    String url, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.json,
          contentType: Headers.jsonContentType,
        ),
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw '对端返回格式异常';
    } on DioException catch (e) {
      throw _formatDioError(e);
    }
  }

  String _formatDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) {
      return '对端版本不支持该操作（请更新对端或在对端点击发送）';
    }
    if (status != null) {
      return 'HTTP $status ${e.response?.statusMessage ?? ''}'.trim();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请确认对方应用保持在前台且在同一局域网';
      case DioExceptionType.connectionError:
        return '无法连接对方设备（${e.message ?? '网络不可达'}）';
      default:
        return e.message ?? e.toString();
    }
  }

  Future<SyncClientInfoModel> getClientInfo(SyncClinet client) async {
    var data = await _get("${_baseUrl(client)}/info");
    return SyncClientInfoModel.fromJson(data);
  }

  Future<Map<String, dynamic>> syncFollow(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var data = await _post(
      "${_baseUrl(client)}/sync/follow",
      data: body,
      queryParameters: {'overlay': overlay ? '1' : '0'},
    );
    if (data["status"] == true) {
      return data;
    }
    throw data["message"] ?? '同步关注失败';
  }

  Future<Map<String, dynamic>> syncTag(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var data = await _post(
      "${_baseUrl(client)}/sync/tag",
      data: body,
      queryParameters: {'overlay': overlay ? '1' : '0'},
    );
    if (data["status"] == true) {
      return data;
    }
    throw data["message"] ?? '同步标签失败';
  }

  Future<Map<String, dynamic>> syncHistory(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var data = await _post(
      "${_baseUrl(client)}/sync/history",
      data: body,
      queryParameters: {'overlay': overlay ? '1' : '0'},
    );
    if (data["status"] == true) {
      return data;
    }
    throw data["message"] ?? '同步历史失败';
  }

  Future<Map<String, dynamic>> syncBlockedWord(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var data = await _post(
      "${_baseUrl(client)}/sync/blocked_word",
      data: body,
      queryParameters: {'overlay': overlay ? '1' : '0'},
    );
    if (data["status"] == true) {
      return data;
    }
    throw data["message"] ?? '同步屏蔽词失败';
  }

  Future<Map<String, dynamic>> syncBiliAccount(
      SyncClinet client, String cookie) async {
    var data = await _post(
      "${_baseUrl(client)}/sync/account/bilibili",
      data: {"cookie": cookie},
    );
    if (data["status"] == true) {
      return data;
    }
    throw data["message"] ?? '同步哔哩哔哩账号失败';
  }

  Future<List<dynamic>> fetchFollow(SyncClinet client) async {
    final data = await _get("${_baseUrl(client)}/sync/follow");
    if (data['status'] == true && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw data['message'] ?? '拉取关注列表失败';
  }

  Future<List<dynamic>> fetchTag(SyncClinet client) async {
    final data = await _get("${_baseUrl(client)}/sync/tag");
    if (data['status'] == true && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw data['message'] ?? '拉取标签列表失败';
  }

  Future<List<dynamic>> fetchHistory(SyncClinet client) async {
    final data = await _get("${_baseUrl(client)}/sync/history");
    if (data['status'] == true && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw data['message'] ?? '拉取观看记录失败';
  }

  Future<Map<String, dynamic>> fetchBlockedWord(SyncClinet client) async {
    final data = await _get("${_baseUrl(client)}/sync/blocked_word");
    if (data['status'] == true) {
      return data;
    }
    throw data['message'] ?? '拉取弹幕屏蔽词失败';
  }

  Future<String> fetchBiliAccount(SyncClinet client) async {
    final data = await _get("${_baseUrl(client)}/sync/account/bilibili");
    if (data['status'] == true) {
      return data['cookie']?.toString() ?? '';
    }
    throw data['message'] ?? '拉取哔哩哔哩账号失败';
  }
}
