#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"
#include "windows_share_bridge.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void EnsureTrayIcon();
  void HideToTray();
  void RestoreFromTray();
  void RemoveTrayIcon();
  void InvalidateAppearance();
  flutter::EncodableMap DisplayCapabilities();
  std::wstring refresh_device_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> refresh_channel_;
  bool appearance_pending_ = false;
  WPARAM appearance_size_state_ = SIZE_RESTORED;
  bool tray_icon_visible_ = false;
  HWND tray_window_ = nullptr;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> window_channel_;
  std::unique_ptr<WindowsShareBridge> windows_share_bridge_;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
