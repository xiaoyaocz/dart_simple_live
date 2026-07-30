import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var shortcutChannel: FlutterMethodChannel?
  private var shortcutCaptureEnabled = false
  private var shortcutMonitor: Any?

  override func awakeFromNib() {
    let project = FlutterDartProject()
    project.dartEntrypointArguments = Array(
      ProcessInfo.processInfo.arguments.dropFirst())
    let flutterViewController = FlutterViewController(project: project)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureDesktopShortcuts(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  deinit {
    if let shortcutMonitor = shortcutMonitor {
      NSEvent.removeMonitor(shortcutMonitor)
    }
  }

  private func configureDesktopShortcuts(binaryMessenger: FlutterBinaryMessenger) {
    shortcutChannel = FlutterMethodChannel(
      name: "simple_live/desktop_shortcuts",
      binaryMessenger: binaryMessenger)
    shortcutChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "setShortcutCaptureEnabled" {
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          self.shortcutCaptureEnabled = enabled
        }
        result(nil)
        return
      }
      result(FlutterMethodNotImplemented)
    }

    shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
      [weak self] event in
      guard let self = self else {
        return event
      }
      guard let key = self.shortcutKey(for: event) else {
        return event
      }
      self.sendShortcutEvent(key)
      return self.shortcutCaptureEnabled ? nil : event
    }

    shortcutChannel?.invokeMethod("shortcutCaptureStateRequested", arguments: nil)
  }

  private func shortcutKey(for event: NSEvent) -> String? {
    switch event.keyCode {
    case 3:
      return "keyF"
    case 2:
      return "keyD"
    case 46:
      return "keyM"
    case 15:
      return "keyR"
    case 8:
      return "keyC"
    case 12:
      return "keyQ"
    case 14:
      return "keyE"
    case 17:
      return "keyT"
    case 5:
      return "keyG"
    case 11:
      return "keyB"
    case 45:
      return "keyN"
    case 126:
      return "arrowUp"
    case 125:
      return "arrowDown"
    default:
      return nil
    }
  }

  private func sendShortcutEvent(_ key: String) {
    shortcutChannel?.invokeMethod("shortcutKeyDown", arguments: ["key": key])
  }
}
