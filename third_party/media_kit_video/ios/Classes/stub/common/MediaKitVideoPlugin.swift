#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public class MediaKitVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with _: FlutterPluginRegistrar) {}
}
