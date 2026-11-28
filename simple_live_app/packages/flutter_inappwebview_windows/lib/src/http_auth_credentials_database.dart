import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// Object specifying creation parameters for creating a [WindowsHttpAuthCredentialDatabase].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformHttpAuthCredentialDatabaseCreationParams] for
/// more information.
@immutable
class WindowsHttpAuthCredentialDatabaseCreationParams
    extends PlatformHttpAuthCredentialDatabaseCreationParams {
  /// Creates a new [WindowsHttpAuthCredentialDatabaseCreationParams] instance.
  const WindowsHttpAuthCredentialDatabaseCreationParams(
    // This parameter prevents breaking changes later.
    // ignore: avoid_unused_constructor_parameters
    PlatformHttpAuthCredentialDatabaseCreationParams params,
  ) : super();

  /// Creates a [WindowsHttpAuthCredentialDatabaseCreationParams] instance based on [PlatformHttpAuthCredentialDatabaseCreationParams].
  factory WindowsHttpAuthCredentialDatabaseCreationParams.fromPlatformHttpAuthCredentialDatabaseCreationParams(
      PlatformHttpAuthCredentialDatabaseCreationParams params) {
    return WindowsHttpAuthCredentialDatabaseCreationParams(params);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformHttpAuthCredentialDatabase}
class WindowsHttpAuthCredentialDatabase
    extends PlatformHttpAuthCredentialDatabase with ChannelController {
  /// Creates a new [WindowsHttpAuthCredentialDatabase].
  WindowsHttpAuthCredentialDatabase(
      PlatformHttpAuthCredentialDatabaseCreationParams params)
      : super.implementation(
          params is WindowsHttpAuthCredentialDatabaseCreationParams
              ? params
              : WindowsHttpAuthCredentialDatabaseCreationParams
                  .fromPlatformHttpAuthCredentialDatabaseCreationParams(params),
        ) {
    channel = const MethodChannel(
        'com.pichillilorenzo/flutter_inappwebview_credential_database');
    handler = handleMethod;
    initMethodCallHandler();
  }

  static WindowsHttpAuthCredentialDatabase? _instance;

  ///Gets the database shared instance.
  static WindowsHttpAuthCredentialDatabase instance() {
    return (_instance != null) ? _instance! : _init();
  }

  static WindowsHttpAuthCredentialDatabase _init() {
    _instance = WindowsHttpAuthCredentialDatabase(
        WindowsHttpAuthCredentialDatabaseCreationParams(
            const PlatformHttpAuthCredentialDatabaseCreationParams()));
    return _instance!;
  }

  Future<dynamic> _handleMethod(MethodCall call) async {}

  @override
  Future<List<URLProtectionSpaceHttpAuthCredentials>>
      getAllAuthCredentials() async {
    Map<String, dynamic> args = <String, dynamic>{};
    List<dynamic> allCredentials =
        await channel?.invokeMethod<List>('getAllAuthCredentials', args) ?? [];

    List<URLProtectionSpaceHttpAuthCredentials> result = [];

    for (Map<dynamic, dynamic> map in allCredentials) {
      var element = URLProtectionSpaceHttpAuthCredentials.fromMap(
          map.cast<String, dynamic>());
      if (element != null) {
        result.add(element);
      }
    }
    return result;
  }

  @override
  Future<List<URLCredential>> getHttpAuthCredentials(
      {required URLProtectionSpace protectionSpace}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent("host", () => protectionSpace.host);
    args.putIfAbsent("protocol", () => protectionSpace.protocol);
    args.putIfAbsent("realm", () => protectionSpace.realm);
    args.putIfAbsent("port", () => protectionSpace.port);
    List<dynamic> credentialList =
        await channel?.invokeMethod<List>('getHttpAuthCredentials', args) ?? [];
    List<URLCredential> credentials = [];
    for (Map<dynamic, dynamic> map in credentialList) {
      var credential = URLCredential.fromMap(map.cast<String, dynamic>());
      if (credential != null) {
        credentials.add(credential);
      }
    }
    return credentials;
  }

  @override
  Future<void> setHttpAuthCredential(
      {required URLProtectionSpace protectionSpace,
      required URLCredential credential}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent("host", () => protectionSpace.host);
    args.putIfAbsent("protocol", () => protectionSpace.protocol);
    args.putIfAbsent("realm", () => protectionSpace.realm);
    args.putIfAbsent("port", () => protectionSpace.port);
    args.putIfAbsent("username", () => credential.username);
    args.putIfAbsent("password", () => credential.password);
    await channel?.invokeMethod('setHttpAuthCredential', args);
  }

  @override
  Future<void> removeHttpAuthCredential(
      {required URLProtectionSpace protectionSpace,
      required URLCredential credential}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent("host", () => protectionSpace.host);
    args.putIfAbsent("protocol", () => protectionSpace.protocol);
    args.putIfAbsent("realm", () => protectionSpace.realm);
    args.putIfAbsent("port", () => protectionSpace.port);
    args.putIfAbsent("username", () => credential.username);
    args.putIfAbsent("password", () => credential.password);
    await channel?.invokeMethod('removeHttpAuthCredential', args);
  }

  @override
  Future<void> removeHttpAuthCredentials(
      {required URLProtectionSpace protectionSpace}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent("host", () => protectionSpace.host);
    args.putIfAbsent("protocol", () => protectionSpace.protocol);
    args.putIfAbsent("realm", () => protectionSpace.realm);
    args.putIfAbsent("port", () => protectionSpace.port);
    await channel?.invokeMethod('removeHttpAuthCredentials', args);
  }

  @override
  Future<void> clearAllAuthCredentials() async {
    Map<String, dynamic> args = <String, dynamic>{};
    await channel?.invokeMethod('clearAllAuthCredentials', args);
  }

  @override
  void dispose() {
    // empty
  }
}

extension InternalHttpAuthCredentialDatabase
    on WindowsHttpAuthCredentialDatabase {
  get handleMethod => _handleMethod;
}
