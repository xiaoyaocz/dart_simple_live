#include "flutter_window.h"

#include <optional>
#include <string>
#include <utility>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  shortcut_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "simple_live/desktop_shortcuts",
          &flutter::StandardMethodCodec::GetInstance());
  shortcut_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setShortcutCaptureEnabled") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            const auto enabled = arguments->find(
                flutter::EncodableValue("enabled"));
            if (enabled != arguments->end()) {
              if (const auto* value =
                      std::get_if<bool>(&enabled->second)) {
                shortcut_capture_enabled_ = *value;
              }
            }
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  ConfigureWindowChromeChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ConfigureWindowChromeChannel() {
  window_chrome_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "simple_live/windows_chrome",
          &flutter::StandardMethodCodec::GetInstance());
  window_chrome_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "apply") {
          ApplyFullscreenChrome();
          result->Success();
          return;
        }
        if (call.method_name() == "restore") {
          RestoreWindowChrome();
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::ApplyFullscreenChrome() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (!fullscreen_chrome_applied_) {
    windowed_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
    windowed_ex_style_ = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  }
  const auto style = windowed_style_ &
      ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZE | WS_MAXIMIZE | WS_SYSMENU);
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE,
                   windowed_ex_style_ & ~WS_EX_DLGMODALFRAME);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
  fullscreen_chrome_applied_ = true;
}

void FlutterWindow::RestoreWindowChrome() {
  HWND hwnd = GetHandle();
  if (!hwnd || !fullscreen_chrome_applied_) return;
  SetWindowLongPtr(hwnd, GWL_STYLE, windowed_style_);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, windowed_ex_style_);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
  fullscreen_chrome_applied_ = false;
}

void FlutterWindow::OnDestroy() {
  shortcut_channel_.reset();
  window_chrome_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
      if (HandleShortcutKeyDown(wparam, lparam)) {
        return 0;
      }
      break;
    default:
      break;
  }

  // Give Flutter, including plugins and IMEs, an opportunity to handle window
  // messages after desktop shortcut keys have been detected by physical key.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::HandleShortcutKeyDown(WPARAM wparam, LPARAM lparam) {
  const std::string key = ShortcutKeyForWindowsKey(wparam, lparam);
  if (key.empty()) {
    return false;
  }
  SendShortcutEvent(key);
  return shortcut_capture_enabled_;
}

std::string FlutterWindow::ShortcutKeyForWindowsKey(WPARAM wparam,
                                                     LPARAM lparam) {
  const UINT scan_code = (lparam >> 16) & 0xff;
  switch (scan_code) {
    case 0x21:
      return "keyF";
    case 0x20:
      return "keyD";
    case 0x32:
      return "keyM";
    case 0x13:
      return "keyR";
    case 0x2e:
      return "keyC";
    case 0x10:
      return "keyQ";
    case 0x12:
      return "keyE";
    case 0x14:
      return "keyT";
    case 0x22:
      return "keyG";
    case 0x30:
      return "keyB";
    case 0x31:
      return "keyN";
    case 0x48:
      return "arrowUp";
    case 0x50:
      return "arrowDown";
    default:
      break;
  }

  switch (wparam) {
    case 'F':
      return "keyF";
    case 'D':
      return "keyD";
    case 'M':
      return "keyM";
    case 'R':
      return "keyR";
    case 'C':
      return "keyC";
    case 'Q':
      return "keyQ";
    case 'E':
      return "keyE";
    case 'T':
      return "keyT";
    case 'G':
      return "keyG";
    case 'B':
      return "keyB";
    case 'N':
      return "keyN";
    case VK_UP:
      return "arrowUp";
    case VK_DOWN:
      return "arrowDown";
    default:
      return "";
  }
}

bool FlutterWindow::SendShortcutEvent(const std::string& key) {
  if (!shortcut_channel_) {
    return false;
  }
  flutter::EncodableMap arguments = {
      {flutter::EncodableValue("key"), flutter::EncodableValue(key)},
  };
  shortcut_channel_->InvokeMethod(
      "shortcutKeyDown",
      std::make_unique<flutter::EncodableValue>(arguments));
  return false;
}
