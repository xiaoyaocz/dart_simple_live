#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <dwmapi.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>
#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kExitMessage = WM_APP + 2;
constexpr UINT kAppearanceMessage = WM_APP + 3;
constexpr UINT kUpdateExitMessage = WM_APP + 4;
constexpr UINT_PTR kExitTimer = 1;
constexpr UINT kShowCommand = 40001;
constexpr UINT kExitCommand = 40002;
MONITORINFOEXW DisplayForWindow(HWND window) {
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
      reinterpret_cast<MONITORINFO*>(&info));
  return info;
}
}

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
  refresh_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "simple_live/display_refresh",
      &flutter::StandardMethodCodec::GetInstance());
  refresh_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "capabilities") {
          result->Success(DisplayCapabilities());
          return;
        }
        // Read-only bridge: changing modes here blanks the physical monitor.
        result->NotImplemented();
      });
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "simple_live/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "hideToTray") {
          HideToTray();
          result->Success();
        } else if (call.method_name() == "exitApp") {
          PostMessageW(GetHandle(), kExitMessage, 0, 0);
          result->Success();
        } else if (call.method_name() == "appearanceCapabilities") {
          // RtlGetVersion is not affected by the application's compatibility manifest.
          OSVERSIONINFOW version{};
          version.dwOSVersionInfoSize = sizeof(version);
          using GetVersion = LONG(WINAPI*)(OSVERSIONINFOW*);
          auto get_version = reinterpret_cast<GetVersion>(
              GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
          if (get_version) get_version(&version);
          DWORD transparency = 1, bytes = sizeof(transparency);
          RegGetValueW(HKEY_CURRENT_USER,
              L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
              L"EnableTransparency", RRF_RT_REG_DWORD, nullptr, &transparency, &bytes);
          HIGHCONTRASTW contrast{};
          contrast.cbSize = sizeof(contrast);
          SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
          BOOL composition = FALSE;
          DwmIsCompositionEnabled(&composition);
          result->Success(flutter::EncodableMap{
              {flutter::EncodableValue("build"), flutter::EncodableValue(
                  static_cast<int32_t>(version.dwBuildNumber))},
              {flutter::EncodableValue("transparency"), flutter::EncodableValue(
                  transparency != 0 && composition && !(contrast.dwFlags & HCF_HIGHCONTRASTON))}});
        } else if (call.method_name() == "appearanceStyle") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("arguments", "Expected appearance options");
            return;
          }
          auto flag = [&](const char* key) {
            auto value = args->find(flutter::EncodableValue(key));
            return value != args->end() && std::get_if<bool>(&value->second) &&
                   std::get<bool>(value->second);
          };
          // These DWM attributes safely return unsupported on older Windows.
          const BOOL dark = flag("dark");
          DwmSetWindowAttribute(GetHandle(), 20, &dark, sizeof(dark));
          const int round = 2;
          DwmSetWindowAttribute(GetHandle(), 33, &round, sizeof(round));
          if (flag("solid")) {
            // flutter_acrylic 1.1.4 does not clear SYSTEMBACKDROP_TYPE on solid.
            const int none = 1;
            const BOOL off = FALSE;
            const COLORREF default_color = 0xFFFFFFFF;
            DwmSetWindowAttribute(GetHandle(), 38, &none, sizeof(none));
            DwmSetWindowAttribute(GetHandle(), 1029, &off, sizeof(off));
            DwmSetWindowAttribute(GetHandle(), 35, &default_color, sizeof(default_color));
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  windows_share_bridge_ = std::make_unique<WindowsShareBridge>();
  windows_share_bridge_->Attach(flutter_controller_->engine()->messenger(),
                                GetHandle());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  EnsureTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  refresh_channel_.reset();
  appearance_pending_ = false;
  RemoveTrayIcon();
  if (windows_share_bridge_) {
    windows_share_bridge_->Detach();
    windows_share_bridge_.reset();
  }
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

flutter::EncodableMap FlutterWindow::DisplayCapabilities() {
  const auto monitor = DisplayForWindow(GetHandle());
  DEVMODEW current{};
  current.dmSize = sizeof(current);
  const double hz = EnumDisplaySettingsW(monitor.szDevice, ENUM_CURRENT_SETTINGS, &current)
      ? current.dmDisplayFrequency : 0;
  return {{flutter::EncodableValue("current"), flutter::EncodableValue(hz)}};
}

void FlutterWindow::EnsureTrayIcon() {
  if (tray_icon_visible_) return;
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = GetHandle();
  icon.uID = 1;
  icon.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  icon.uCallbackMessage = kTrayMessage;
  icon.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(icon.szTip, L"Simple Live");
  if (Shell_NotifyIconW(NIM_ADD, &icon)) {
    tray_icon_visible_ = true;
    tray_window_ = GetHandle();
  }
}

void FlutterWindow::HideToTray() {
  EnsureTrayIcon();
  if (tray_icon_visible_) ShowWindow(GetHandle(), SW_HIDE);
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_visible_) return;
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = tray_window_;
  icon.uID = 1;
  Shell_NotifyIconW(NIM_DELETE, &icon);
  tray_icon_visible_ = false;
  tray_window_ = nullptr;
}

void FlutterWindow::RestoreFromTray() {
  ShowWindow(GetHandle(), SW_RESTORE);
  SetForegroundWindow(GetHandle());
}

void FlutterWindow::InvalidateAppearance() {
  // Merge the activate/restore/display messages from one transition. Do not
  // force on WM_THEMECHANGED: setting our own DWM attributes can send it again.
  if (!window_channel_ || appearance_pending_) return;
  appearance_pending_ = PostMessageW(GetHandle(), kAppearanceMessage, 0, 0) != FALSE;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (refresh_channel_ && (message == WM_MOVE || message == WM_DISPLAYCHANGE)) {
    const auto monitor = DisplayForWindow(hwnd);
    const bool moved = refresh_device_ != monitor.szDevice;
    if (message == WM_DISPLAYCHANGE || moved) {
      refresh_device_ = monitor.szDevice;
      refresh_channel_->InvokeMethod("displayChanged", nullptr);
    }
  }
  if (message == kAppearanceMessage) {
    appearance_pending_ = false;
    if (window_channel_) {
      window_channel_->InvokeMethod("onAppearanceInvalidated", nullptr);
    }
    return 0;
  }
  if (message == WM_DWMCOMPOSITIONCHANGED || message == WM_DISPLAYCHANGE ||
      (message == WM_ACTIVATE && LOWORD(wparam) != WA_INACTIVE) ||
      (message == WM_SHOWWINDOW && wparam) ||
      (message == WM_POWERBROADCAST &&
       (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND))) {
    InvalidateAppearance();
  }
  if (message == WM_SIZE) {
    if (wparam != appearance_size_state_ && wparam != SIZE_MINIMIZED) {
      InvalidateAppearance();
    }
    appearance_size_state_ = wparam;
  }
  if (message == WM_STYLECHANGED && wparam == static_cast<WPARAM>(GWL_STYLE)) {
    const auto* style = reinterpret_cast<const STYLESTRUCT*>(lparam);
    if ((style->styleOld ^ style->styleNew) & (WS_POPUP | WS_CAPTION | WS_THICKFRAME)) {
      InvalidateAppearance();
    }
  }
  if ((message == WM_SETTINGCHANGE || message == WM_THEMECHANGED) && window_channel_) {
    window_channel_->InvokeMethod("onAppearanceChanged", nullptr);
  }
  if (message == WM_NCCALCSIZE && wparam && ::IsZoomed(hwnd)) {
    const LONG_PTR style = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    auto* size = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    // 最大化进入全屏时，插件去掉缩放边框，但未去掉标题栏客户区。
    if ((style & (WS_THICKFRAME | WS_MAXIMIZEBOX)) == 0 &&
        ::GetMonitorInfo(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                         &monitor) &&
        ::EqualRect(&size->rgrc[0], &monitor.rcMonitor)) {
      return 0;
    }
  }
  if (message == WM_CLOSE) {
    if (window_channel_) {
      window_channel_->InvokeMethod("onCloseRequest", nullptr);
    }
    return 0;
  }
  if (message == kTrayMessage) {
    if (lparam == WM_LBUTTONDBLCLK) {
      RestoreFromTray();
    } else if (lparam == WM_RBUTTONUP) {
      HMENU menu = CreatePopupMenu();
      AppendMenuW(menu, MF_STRING, kShowCommand, L"打开 Simple Live");
      AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      AppendMenuW(menu, MF_STRING, kExitCommand, L"退出 Simple Live");
      POINT cursor;
      GetCursorPos(&cursor);
      SetForegroundWindow(hwnd);
      UINT command = TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_RETURNCMD |
                                           TPM_NONOTIFY, cursor.x, cursor.y,
                                    0, hwnd, nullptr);
      DestroyMenu(menu);
      if (command == kShowCommand) {
        RestoreFromTray();
      } else if (command == kExitCommand) {
        PostMessageW(hwnd, kExitMessage, 0, 0);
      }
    }
    return 0;
  }
  if (message == kExitMessage || message == kUpdateExitMessage) {
    RemoveTrayIcon();
    SetTimer(hwnd, kExitTimer, 100, nullptr);
    return 0;
  }
  if (message == WM_TIMER && wparam == kExitTimer) {
    KillTimer(hwnd, kExitTimer);
    PostQuitMessage(0);
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
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
