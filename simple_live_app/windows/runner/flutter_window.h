#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <set>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Called by the message loop before TranslateMessage. Returns true when the
  // message was consumed as a desktop shortcut and must not be translated or
  // dispatched (so neither the IME nor Flutter sees it).
  bool PreTranslateShortcutMessage(const MSG& msg);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ConfigureWindowChromeChannel();
  void ApplyFullscreenChrome();
  void RestoreWindowChrome();
  void SetImeForShortcutCapture(bool captureEnabled);
  std::string ShortcutKeyForWindowsKey(WPARAM wparam, LPARAM lparam);
  bool SendShortcutEvent(const std::string& key);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_chrome_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      shortcut_channel_;
  LONG_PTR windowed_style_ = 0;
  LONG_PTR windowed_ex_style_ = 0;
  bool fullscreen_chrome_applied_ = false;
  bool shortcut_capture_enabled_ = false;
  // The Flutter view child window that owns keyboard focus and whose IME
  // association is detached while shortcuts are captured.
  HWND ime_detached_window_ = nullptr;
  // Scan codes (with the extended-key bit) whose key-down was consumed, so the
  // matching key-up is consumed too and Flutter never sees an unpaired event.
  std::set<UINT> swallowed_scan_codes_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
