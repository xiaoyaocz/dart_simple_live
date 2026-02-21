import Foundation
import Flutter

final class AppIntentBridge {
  static let shared = AppIntentBridge()

  private let channelName = "com.xycz.simple-live/app_intents"
  private var channel: FlutterMethodChannel?
  private var isDartReady = false
  private var pendingPayloads: [[String: Any]] = []

  private init() {}

  func configure(with messenger: FlutterBinaryMessenger) {
    DispatchQueue.main.async {
      if self.channel != nil {
        return
      }

      let methodChannel = FlutterMethodChannel(
        name: self.channelName,
        binaryMessenger: messenger
      )
      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "dartReady" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.isDartReady = true
        self?.flushPending()
        result(nil)
      }

      self.channel = methodChannel
    }
  }

  func sendIntent(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      guard self.channel != nil, self.isDartReady else {
        self.pendingPayloads.append(payload)
        return
      }
      self.invoke(payload)
    }
  }

  private func flushPending() {
    guard isDartReady else {
      return
    }
    guard !pendingPayloads.isEmpty else {
      return
    }

    let payloads = pendingPayloads
    pendingPayloads.removeAll()
    for payload in payloads {
      invoke(payload)
    }
  }

  private func invoke(_ payload: [String: Any]) {
    guard let channel else {
      pendingPayloads.append(payload)
      return
    }
    channel.invokeMethod("onIntent", arguments: payload)
  }
}
