import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'cookie_manager.dart';
import 'in_app_browser/in_app_browser.dart';
import 'in_app_webview/in_app_webview.dart';
import 'in_app_webview/in_app_webview_controller.dart';
import 'in_app_webview/headless_in_app_webview.dart';
import 'webview_environment/webview_environment.dart';
import 'web_storage/web_storage.dart';

/// Implementation of [InAppWebViewPlatform] using the WebKit API.
class WindowsInAppWebViewPlatform extends InAppWebViewPlatform {
  /// Registers this class as the default instance of [InAppWebViewPlatform].
  static void registerWith() {
    InAppWebViewPlatform.instance = WindowsInAppWebViewPlatform();
  }

  /// Creates a new [WindowsCookieManager].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [CookieManager] in `flutter_inappwebview` instead.
  @override
  WindowsCookieManager createPlatformCookieManager(
    PlatformCookieManagerCreationParams params,
  ) {
    return WindowsCookieManager(params);
  }

  /// Creates a new [WindowsInAppWebViewController].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebViewController] in `flutter_inappwebview` instead.
  @override
  WindowsInAppWebViewController createPlatformInAppWebViewController(
    PlatformInAppWebViewControllerCreationParams params,
  ) {
    return WindowsInAppWebViewController(params);
  }

  /// Creates a new empty [WindowsInAppWebViewController] to access static methods.
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebViewController] in `flutter_inappwebview` instead.
  @override
  WindowsInAppWebViewController createPlatformInAppWebViewControllerStatic() {
    return WindowsInAppWebViewController.static();
  }

  /// Creates a new [WindowsInAppWebViewWidget].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebView] in `flutter_inappwebview` instead.
  @override
  WindowsInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return WindowsInAppWebViewWidget(params);
  }

  /// Creates a new [WindowsInAppBrowser].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [InAppBrowser] in `flutter_inappwebview` instead.
  @override
  WindowsInAppBrowser createPlatformInAppBrowser(
    PlatformInAppBrowserCreationParams params,
  ) {
    return WindowsInAppBrowser(params);
  }

  /// Creates a new empty [WindowsInAppBrowser] to access static methods.
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [InAppBrowser] in `flutter_inappwebview` instead.
  @override
  WindowsInAppBrowser createPlatformInAppBrowserStatic() {
    return WindowsInAppBrowser.static();
  }

  /// Creates a new [WindowsHeadlessInAppWebView].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [HeadlessInAppWebView] in `flutter_inappwebview` instead.
  @override
  WindowsHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    return WindowsHeadlessInAppWebView(params);
  }

  /// Creates a new [WindowsWebViewEnvironment].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [WebViewEnvironment] in `flutter_inappwebview` instead.
  @override
  WindowsWebViewEnvironment createPlatformWebViewEnvironment(
    PlatformWebViewEnvironmentCreationParams params,
  ) {
    return WindowsWebViewEnvironment(params);
  }

  /// Creates a new empty [WindowsWebViewEnvironment] to access static methods.
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [WebViewEnvironment] in `flutter_inappwebview` instead.
  @override
  WindowsWebViewEnvironment createPlatformWebViewEnvironmentStatic() {
    return WindowsWebViewEnvironment.static();
  }

  /// Creates a new [WindowsWebStorage].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [WebStorage] in `flutter_inappwebview` instead.
  @override
  WindowsWebStorage createPlatformWebStorage(
    PlatformWebStorageCreationParams params,
  ) {
    return WindowsWebStorage(params);
  }

  /// Creates a new [WindowsLocalStorage].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [LocalStorage] in `flutter_inappwebview` instead.
  @override
  WindowsLocalStorage createPlatformLocalStorage(
    PlatformLocalStorageCreationParams params,
  ) {
    return WindowsLocalStorage(params);
  }

  /// Creates a new [WindowsSessionStorage].
  ///
  /// This function should only be called by the app-facing package.
  /// Look at using [SessionStorage] in `flutter_inappwebview` instead.
  @override
  WindowsSessionStorage createPlatformSessionStorage(
    PlatformSessionStorageCreationParams params,
  ) {
    return WindowsSessionStorage(params);
  }
}
