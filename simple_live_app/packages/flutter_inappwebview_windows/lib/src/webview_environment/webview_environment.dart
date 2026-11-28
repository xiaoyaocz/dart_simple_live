import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// Object specifying creation parameters for creating a [WindowsWebViewEnvironment].
///
/// Platform specific implementations can add additional fields by extending
/// this class.
@immutable
class WindowsWebViewEnvironmentCreationParams
    extends PlatformWebViewEnvironmentCreationParams {
  /// Creates a new [WindowsInAppWebViewControllerCreationParams] instance.
  const WindowsWebViewEnvironmentCreationParams({super.settings});

  /// Creates a [WindowsInAppWebViewControllerCreationParams] instance based on [PlatformInAppWebViewControllerCreationParams].
  factory WindowsWebViewEnvironmentCreationParams.fromPlatformWebViewEnvironmentCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformWebViewEnvironmentCreationParams params) {
    return WindowsWebViewEnvironmentCreationParams(settings: params.settings);
  }
}

///Controls a WebView Environment used by WebView instances.
///
///**Officially Supported Platforms/Implementations**:
///- Windows
class WindowsWebViewEnvironment extends PlatformWebViewEnvironment
    with ChannelController {
  static final MethodChannel _staticChannel =
      MethodChannel('com.pichillilorenzo/flutter_webview_environment');

  @override
  final String id = IdGenerator.generate();

  WindowsWebViewEnvironment(PlatformWebViewEnvironmentCreationParams params)
      : super.implementation(params is WindowsWebViewEnvironmentCreationParams
            ? params
            : WindowsWebViewEnvironmentCreationParams
                .fromPlatformWebViewEnvironmentCreationParams(params));

  static final WindowsWebViewEnvironment _staticValue =
      WindowsWebViewEnvironment(WindowsWebViewEnvironmentCreationParams());

  factory WindowsWebViewEnvironment.static() {
    return _staticValue;
  }

  _debugLog(String method, dynamic args) {
    debugLog(
        className: this.runtimeType.toString(),
        id: id,
        debugLoggingSettings: PlatformWebViewEnvironment.debugLoggingSettings,
        method: method,
        args: args);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (PlatformWebViewEnvironment.debugLoggingSettings.enabled) {
      _debugLog(call.method, call.arguments);
    }

    switch (call.method) {
      default:
        throw UnimplementedError("Unimplemented ${call.method} method");
    }
  }

  @override
  Future<WindowsWebViewEnvironment> create(
      {WebViewEnvironmentSettings? settings}) async {
    final env = WindowsWebViewEnvironment(
        WindowsWebViewEnvironmentCreationParams(settings: settings));

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('id', () => env.id);
    args.putIfAbsent('settings', () => env.settings?.toMap());
    await _staticChannel.invokeMethod('create', args);

    env.channel = MethodChannel(
        'com.pichillilorenzo/flutter_webview_environment_${env.id}');
    env.handler = env.handleMethod;
    env.initMethodCallHandler();
    return env;
  }

  @override
  Future<String?> getAvailableVersion({String? browserExecutableFolder}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('browserExecutableFolder', () => browserExecutableFolder);
    return await _staticChannel.invokeMethod<String>(
        'getAvailableVersion', args);
  }

  @override
  Future<int?> compareBrowserVersions(
      {required String version1, required String version2}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('version1', () => version1);
    args.putIfAbsent('version2', () => version2);
    return await _staticChannel.invokeMethod<int>(
        'compareBrowserVersions', args);
  }

  @override
  Future<void> dispose() async {
    Map<String, dynamic> args = <String, dynamic>{};
    await channel?.invokeMethod('dispose', args);
    disposeChannel();
  }
}

extension InternalWindowsWebViewEnvironment on WindowsWebViewEnvironment {
  get handleMethod => _handleMethod;
}
