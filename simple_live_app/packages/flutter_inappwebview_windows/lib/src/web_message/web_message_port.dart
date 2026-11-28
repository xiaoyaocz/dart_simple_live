import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'web_message_channel.dart';

/// Object specifying creation parameters for creating a [WindowsWebMessagePort].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformWebMessagePortCreationParams] for
/// more information.
@immutable
class WindowsWebMessagePortCreationParams
    extends PlatformWebMessagePortCreationParams {
  /// Creates a new [WindowsWebMessagePortCreationParams] instance.
  const WindowsWebMessagePortCreationParams({required super.index});

  /// Creates a [WindowsWebMessagePortCreationParams] instance based on [PlatformWebMessagePortCreationParams].
  factory WindowsWebMessagePortCreationParams.fromPlatformWebMessagePortCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformWebMessagePortCreationParams params) {
    return WindowsWebMessagePortCreationParams(index: params.index);
  }

  @override
  String toString() {
    return 'MacOSWebMessagePortCreationParams{index: $index}';
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformWebMessagePort}
class WindowsWebMessagePort extends PlatformWebMessagePort {
  WebMessageCallback? _onMessage;
  late WindowsWebMessageChannel _webMessageChannel;

  /// Constructs a [WindowsWebMessagePort].
  WindowsWebMessagePort(PlatformWebMessagePortCreationParams params)
      : super.implementation(
          params is WindowsWebMessagePortCreationParams
              ? params
              : WindowsWebMessagePortCreationParams
                  .fromPlatformWebMessagePortCreationParams(params),
        );

  @override
  Future<void> setWebMessageCallback(WebMessageCallback? onMessage) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('index', () => params.index);
    await _webMessageChannel.internalChannel
        ?.invokeMethod('setWebMessageCallback', args);
    this._onMessage = onMessage;
  }

  @override
  Future<void> postMessage(WebMessage message) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('index', () => params.index);
    args.putIfAbsent('message', () => message.toMap());
    await _webMessageChannel.internalChannel?.invokeMethod('postMessage', args);
  }

  @override
  Future<void> close() async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('index', () => params.index);
    await _webMessageChannel.internalChannel?.invokeMethod('close', args);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      "index": params.index,
      "webMessageChannelId": this._webMessageChannel.params.id
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'MacOSWebMessagePort{index: ${params.index}}';
  }
}

extension InternalWebMessagePort on WindowsWebMessagePort {
  WebMessageCallback? get onMessage => _onMessage;
  void set onMessage(WebMessageCallback? value) => _onMessage = value;

  WindowsWebMessageChannel get webMessageChannel => _webMessageChannel;
  void set webMessageChannel(WindowsWebMessageChannel value) =>
      _webMessageChannel = value;
}
