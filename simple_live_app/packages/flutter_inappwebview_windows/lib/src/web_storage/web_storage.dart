import 'dart:convert';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import '../in_app_webview/in_app_webview_controller.dart';

/// Object specifying creation parameters for creating a [WindowsWebStorage].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformWebStorageCreationParams] for
/// more information.
class WindowsWebStorageCreationParams extends PlatformWebStorageCreationParams {
  /// Creates a new [WindowsWebStorageCreationParams] instance.
  WindowsWebStorageCreationParams(
      {required super.localStorage, required super.sessionStorage});

  /// Creates a [WindowsWebStorageCreationParams] instance based on [PlatformWebStorageCreationParams].
  factory WindowsWebStorageCreationParams.fromPlatformWebStorageCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformWebStorageCreationParams params) {
    return WindowsWebStorageCreationParams(
        localStorage: params.localStorage,
        sessionStorage: params.sessionStorage);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformWebStorage}
class WindowsWebStorage extends PlatformWebStorage {
  /// Constructs a [WindowsWebStorage].
  WindowsWebStorage(PlatformWebStorageCreationParams params)
      : super.implementation(
          params is WindowsWebStorageCreationParams
              ? params
              : WindowsWebStorageCreationParams
                  .fromPlatformWebStorageCreationParams(params),
        );

  @override
  PlatformLocalStorage get localStorage => params.localStorage;

  @override
  PlatformSessionStorage get sessionStorage => params.sessionStorage;

  @override
  void dispose() {
    localStorage.dispose();
    sessionStorage.dispose();
  }
}

/// Object specifying creation parameters for creating a [WindowsStorage].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformStorageCreationParams] for
/// more information.
class WindowsStorageCreationParams extends PlatformStorageCreationParams {
  /// Creates a new [WindowsStorageCreationParams] instance.
  WindowsStorageCreationParams(
      {required super.controller, required super.webStorageType});

  /// Creates a [WindowsStorageCreationParams] instance based on [PlatformStorageCreationParams].
  factory WindowsStorageCreationParams.fromPlatformStorageCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformStorageCreationParams params) {
    return WindowsStorageCreationParams(
        controller: params.controller, webStorageType: params.webStorageType);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformStorage}
abstract mixin class WindowsStorage implements PlatformStorage {
  @override
  WindowsInAppWebViewController? controller;

  @override
  Future<int?> length() async {
    var result = await controller?.evaluateJavascript(source: """
    window.$webStorageType.length;
    """);
    return result != null ? int.parse(json.decode(result)) : null;
  }

  @override
  Future<void> setItem({required String key, required dynamic value}) async {
    var encodedValue = json.encode(value);
    await controller?.evaluateJavascript(source: """
    window.$webStorageType.setItem("$key", ${value is String ? encodedValue : "JSON.stringify($encodedValue)"});
    """);
  }

  @override
  Future<dynamic> getItem({required String key}) async {
    var itemValue = await controller?.evaluateJavascript(source: """
    window.$webStorageType.getItem("$key");
    """);

    if (itemValue == null) {
      return null;
    }

    try {
      return json.decode(itemValue);
    } catch (e) {}

    return itemValue;
  }

  @override
  Future<void> removeItem({required String key}) async {
    await controller?.evaluateJavascript(source: """
    window.$webStorageType.removeItem("$key");
    """);
  }

  @override
  Future<List<WebStorageItem>> getItems() async {
    var webStorageItems = <WebStorageItem>[];

    List<Map<dynamic, dynamic>>? items =
        (await controller?.evaluateJavascript(source: """
(function() {
  var webStorageItems = [];
  for(var i = 0; i < window.$webStorageType.length; i++){
    var key = window.$webStorageType.key(i);
    webStorageItems.push(
      {
        key: key,
        value: window.$webStorageType.getItem(key)
      }
    );
  }
  return webStorageItems;
})();
    """))?.cast<Map<dynamic, dynamic>>();

    if (items == null) {
      return webStorageItems;
    }

    for (var item in items) {
      webStorageItems
          .add(WebStorageItem(key: item["key"], value: item["value"]));
    }

    return webStorageItems;
  }

  @override
  Future<void> clear() async {
    await controller?.evaluateJavascript(source: """
    window.$webStorageType.clear();
    """);
  }

  @override
  Future<String> key({required int index}) async {
    var result = await controller?.evaluateJavascript(source: """
    window.$webStorageType.key($index);
    """);
    return result != null ? json.decode(result) : null;
  }

  @override
  void dispose() {
    controller = null;
  }
}

/// Object specifying creation parameters for creating a [WindowsLocalStorage].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformLocalStorageCreationParams] for
/// more information.
class WindowsLocalStorageCreationParams
    extends PlatformLocalStorageCreationParams {
  /// Creates a new [WindowsLocalStorageCreationParams] instance.
  WindowsLocalStorageCreationParams(super.params);

  /// Creates a [WindowsLocalStorageCreationParams] instance based on [PlatformLocalStorageCreationParams].
  factory WindowsLocalStorageCreationParams.fromPlatformLocalStorageCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformLocalStorageCreationParams params) {
    return WindowsLocalStorageCreationParams(params);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformLocalStorage}
class WindowsLocalStorage extends PlatformLocalStorage with WindowsStorage {
  /// Constructs a [WindowsLocalStorage].
  WindowsLocalStorage(PlatformLocalStorageCreationParams params)
      : super.implementation(
          params is WindowsLocalStorageCreationParams
              ? params
              : WindowsLocalStorageCreationParams
                  .fromPlatformLocalStorageCreationParams(params),
        );

  /// Default storage
  factory WindowsLocalStorage.defaultStorage(
      {required PlatformInAppWebViewController? controller}) {
    return WindowsLocalStorage(WindowsLocalStorageCreationParams(
        PlatformLocalStorageCreationParams(PlatformStorageCreationParams(
            controller: controller,
            webStorageType: WebStorageType.LOCAL_STORAGE))));
  }

  @override
  WindowsInAppWebViewController? get controller =>
      params.controller as WindowsInAppWebViewController?;
}

/// Object specifying creation parameters for creating a [WindowsSessionStorage].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformSessionStorageCreationParams] for
/// more information.
class WindowsSessionStorageCreationParams
    extends PlatformSessionStorageCreationParams {
  /// Creates a new [WindowsSessionStorageCreationParams] instance.
  WindowsSessionStorageCreationParams(super.params);

  /// Creates a [WindowsSessionStorageCreationParams] instance based on [PlatformSessionStorageCreationParams].
  factory WindowsSessionStorageCreationParams.fromPlatformSessionStorageCreationParams(
      // Recommended placeholder to prevent being broken by platform interface.
      // ignore: avoid_unused_constructor_parameters
      PlatformSessionStorageCreationParams params) {
    return WindowsSessionStorageCreationParams(params);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformSessionStorage}
class WindowsSessionStorage extends PlatformSessionStorage with WindowsStorage {
  /// Constructs a [WindowsSessionStorage].
  WindowsSessionStorage(PlatformSessionStorageCreationParams params)
      : super.implementation(
          params is WindowsSessionStorageCreationParams
              ? params
              : WindowsSessionStorageCreationParams
                  .fromPlatformSessionStorageCreationParams(params),
        );

  /// Default storage
  factory WindowsSessionStorage.defaultStorage(
      {required PlatformInAppWebViewController? controller}) {
    return WindowsSessionStorage(WindowsSessionStorageCreationParams(
        PlatformSessionStorageCreationParams(PlatformStorageCreationParams(
            controller: controller,
            webStorageType: WebStorageType.SESSION_STORAGE))));
  }

  @override
  WindowsInAppWebViewController? get controller =>
      params.controller as WindowsInAppWebViewController?;
}
