#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public protocol ResizableTextureProtocol: NSObject, FlutterTexture {
  func resize(_ size: CGSize)
  func render(_ size: CGSize)

  /// 每帧渲染完成后回调，携带本次渲染的 CVPixelBuffer（与纹理共享同一缓冲）。
  /// 用于 iOS 画中画：同一份像素零拷贝地喂给 AVSampleBufferDisplayLayer。
  var onFrameRendered: ((CVPixelBuffer) -> Void)? { get set }
}
