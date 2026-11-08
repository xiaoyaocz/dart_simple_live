#if canImport(Flutter)
  import AVFoundation
  import AVKit
  import Flutter
  import UIKit

  /// 通过独立的 method/event channel 暴露 iOS 画中画能力：
  /// - `com.alexmercerind/media_kit_video/pip`
  /// - `com.alexmercerind/media_kit_video/pip/events`
  ///
  /// 由 `MediaKitVideoPlugin.register(with:)` 创建，直接持有
  /// `VideoOutputManager` 引用，无需访问单例。
  final class MediaKitPictureInPicturePlugin: NSObject, FlutterStreamHandler {
    static let METHOD_CHANNEL = "com.alexmercerind/media_kit_video/pip"
    static let EVENT_CHANNEL = "com.alexmercerind/media_kit_video/pip/events"

    private let outputManager: VideoOutputManager
    // 用 AnyObject 装箱持有 iOS 15+ 类型，避免在更低部署目标下的类型可用性问题
    private var controllerBox: AnyObject?
    /// 已停止、等待延迟释放的控制器。iOS 26/27 的 AVKit 在
    /// stopPictureInPicture 之后仍会异步访问 sample buffer 图层的内部
    /// 对象（社区报告的系统级缺陷），立即释放控制器会命中该窗口；
    /// 退役控制器保留 3 秒再释放。
    private var retiredControllers: [AnyObject] = []
    private var eventSink: FlutterEventSink?
    private var audioSessionConfigured: Bool = false

    init(
      registrar: FlutterPluginRegistrar,
      outputManager: VideoOutputManager
    ) {
      self.outputManager = outputManager
      super.init()

      let messenger = registrar.messenger()
      let methodChannel = FlutterMethodChannel(
        name: Self.METHOD_CHANNEL,
        binaryMessenger: messenger
      )
      let eventChannel = FlutterEventChannel(
        name: Self.EVENT_CHANNEL,
        binaryMessenger: messenger
      )
      methodChannel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
      eventChannel.setStreamHandler(self)
    }

    // MARK: - Method channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "isSupported":
        if #available(iOS 15.0, *) {
          result(AVPictureInPictureController.isPictureInPictureSupported())
        } else {
          result(false)
        }
      case "isActive":
        if #available(iOS 15.0, *),
          let controller = controllerBox as? MediaKitPictureInPictureController
        {
          result(controller.isActive)
        } else {
          result(false)
        }
      case "start":
        handleStart(call.arguments, result: result)
      case "enter":
        if #available(iOS 15.0, *),
          let controller = controllerBox as? MediaKitPictureInPictureController
        {
          controller.enter()
        }
        result(nil)
      case "stop":
        if #available(iOS 15.0, *),
          let controller = controllerBox as? MediaKitPictureInPictureController
        {
          controller.stop()
          retire(controller)
        }
        controllerBox = nil
        result(nil)
      case "setAutoEnter":
        guard let args = call.arguments as? [String: Any],
          let enabled = args["autoEnter"] as? Bool
        else {
          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
          return
        }
        if #available(iOS 15.0, *),
          let controller = controllerBox as? MediaKitPictureInPictureController
        {
          controller.setAutoEnter(enabled)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    /// 停止并延迟释放控制器，避开 AVKit 内部异步访问的释放窗口
    private func retire(_ controller: AnyObject) {
      guard #available(iOS 15.0, *) else { return }
      retiredControllers.append(controller)
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
        guard let self = self else { return }
        self.retiredControllers.removeAll { $0 === controller }
      }
    }

    private func handleStart(_ arguments: Any?, result: @escaping FlutterResult) {
      guard #available(iOS 15.0, *) else {
        result(
          FlutterError(
            code: "UNSUPPORTED",
            message: "Picture-in-Picture requires iOS 15+",
            details: nil
          )
        )
        return
      }
      guard let args = arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "arguments required", details: nil))
        return
      }
      guard let handle = Self.readHandle(args["handle"]) else {
        result(FlutterError(code: "INVALID_ARGS", message: "handle required", details: nil))
        return
      }
      let autoEnter = args["autoEnter"] as? Bool ?? false
      let startImmediately = args["startImmediately"] as? Bool ?? false

      guard let hostView = Self.resolveHostView() else {
        result(
          FlutterError(
            code: "NO_WINDOW",
            message: "No host window available",
            details: nil
          )
        )
        return
      }

      configureAudioSessionIfNeeded()

      if let old = controllerBox as? MediaKitPictureInPictureController {
        old.stop()
        retire(old)
      }
      let pipController = MediaKitPictureInPictureController(
        hostView: hostView,
        outputManager: outputManager
      ) { [weak self] event in
        // FlutterEventSink 必须在主线程调用：stats 事件从入队串行队列
        // 发出，其余事件虽已在主线程，统一再派发一次保证线程正确
        DispatchQueue.main.async {
          self?.eventSink?(event)
        }
      }
      self.controllerBox = pipController

      let started = pipController.start(
        handle: handle,
        autoEnter: autoEnter,
        startImmediately: startImmediately
      )
      if started {
        result(nil)
      } else {
        self.controllerBox = nil
        result(
          FlutterError(
            code: "START_FAILED",
            message: "Unable to attach Picture-in-Picture pipeline",
            details: nil
          )
        )
      }
    }

    // MARK: - Audio session

    /// mpv（avfaudio）通常已在播放时配置好会话；此处兜底确保 playback
    /// 类别激活，否则 PiP 激活期间可能没有音频会话可用。
    private func configureAudioSessionIfNeeded() {
      guard !audioSessionConfigured else { return }
      let session = AVAudioSession.sharedInstance()
      do {
        try session.setCategory(
          .playback,
          mode: .moviePlayback,
          options: [.allowAirPlay, .allowBluetoothA2DP]
        )
        try session.setActive(true)
        audioSessionConfigured = true
      } catch {
        NSLog("MediaKitPictureInPicturePlugin: AVAudioSession setup failed: \(error)")
      }
    }

    // MARK: - Helpers

    private static func readHandle(_ raw: Any?) -> Int64? {
      if let number = raw as? NSNumber { return number.int64Value }
      if let string = raw as? String { return Int64(string) }
      return nil
    }

    private static func resolveHostView() -> UIView? {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene,
          scene.activationState == .foregroundActive
            || scene.activationState == .foregroundInactive
        else { continue }
        let keyed =
          windowScene.windows.first(where: { $0.isKeyWindow })
          ?? windowScene.windows.first
        if let window = keyed {
          return window.rootViewController?.view ?? window
        }
      }
      return nil
    }

    // MARK: - FlutterStreamHandler

    func onListen(
      withArguments arguments: Any?,
      eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
      eventSink = events
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      eventSink = nil
      return nil
    }
  }
#endif
