import 'package:flutter/services.dart';

enum WindowsShareStatus {
  opened,
  unsupported,
  error,
}

class WindowsShareResult {
  final WindowsShareStatus status;
  final String code;
  final String hresult;
  final bool dataRequested;
  final bool elevated;
  final bool cdpDisabled;
  final String message;

  const WindowsShareResult({
    required this.status,
    this.code = '',
    this.hresult = '',
    this.dataRequested = false,
    this.elevated = false,
    this.cdpDisabled = false,
    this.message = '',
  });

  factory WindowsShareResult.fromPlatformMap(Map<Object?, Object?> map) {
    final rawStatus = map['status']?.toString() ?? 'error';
    final status = switch (rawStatus) {
      'opened' => WindowsShareStatus.opened,
      'unsupported' => WindowsShareStatus.unsupported,
      _ => WindowsShareStatus.error,
    };
    return WindowsShareResult(
      status: status,
      code: map['code']?.toString() ?? '',
      hresult: map['hresult']?.toString() ?? '',
      dataRequested: map['dataRequested'] == true,
      elevated: map['elevated'] == true,
      cdpDisabled: map['cdpDisabled'] == true,
      message: map['message']?.toString() ?? '',
    );
  }
}

class WindowsShareService {
  static const MethodChannel channel =
      MethodChannel('simple_live/windows_share');

  static Future<WindowsShareResult> shareRoom({
    required String title,
    required String description,
    required Uri url,
    required String text,
  }) async {
    final response = await channel.invokeMethod<Object?>(
      'shareRoom',
      <String, String>{
        'title': title,
        'description': description,
        'url': url.toString(),
        'text': text,
      },
    );
    if (response is Map) {
      return WindowsShareResult.fromPlatformMap(response);
    }
    return const WindowsShareResult(
      status: WindowsShareStatus.error,
      code: 'invalid_response',
      message: 'Unexpected response from Windows share bridge.',
    );
  }
}
