import Cocoa
import Darwin
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let bundleIdentifier = Bundle.main.bundleIdentifier {
      let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
      let existingApp = NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .first { $0.processIdentifier != currentProcessIdentifier }

      if existingApp != nil {
        setenv("SIMPLE_LIVE_SECONDARY_INSTANCE", "1", 1)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
