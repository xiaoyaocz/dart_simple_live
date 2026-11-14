import 'dart:io';

class PlatformUtils {
  PlatformUtils._();

  static bool get isMobileApp => Platform.isAndroid || Platform.isIOS;

  static bool get supportsInlineMultiRoom => !isMobileApp;
}
