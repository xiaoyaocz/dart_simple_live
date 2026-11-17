// Real Flutter engine + live local WebView. Run from the matching Release folder.
// argv[1]: fixture's data directory.
#include <windows.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <iostream>
#include "../include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h"

int wmain(int argc, wchar_t** argv) {
  if (argc < 2) return 2;
  // Show failures as exit codes, not dialogs that leave test instances blocked.
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  bool ready = false;
  {
    flutter::DartProject project(argv[1]);
    auto controller = std::make_unique<flutter::FlutterViewController>(400, 240, project);
    if (!controller->engine() || !controller->view()) return 3;
    FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(
      controller->engine()->GetRegistrarForPlugin("FlutterInappwebviewWindowsPluginCApi"));
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      controller->engine()->messenger(), "simple_live/shutdown_fixture",
      &flutter::StandardMethodCodec::GetInstance());
    channel->SetMethodCallHandler([&](const auto& call, auto result) {
      ready = call.method_name() == "ready";
      result->Success();
    });
    const auto deadline = GetTickCount64() + 20000;
    while (!ready && GetTickCount64() < deadline) {
      MSG message;
      while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
      }
      if (!ready) MsgWaitForMultipleObjects(0, nullptr, FALSE, 20, QS_ALLINPUT);
    }
    if (!ready) { std::cerr << "FAIL: local WebView did not become ready\n"; return 4; }
    std::cout << "READY: live local WebView; destroying engine\n" << std::flush;
    channel.reset();
    controller.reset();
    std::cout << "DESTROYED: Flutter engine\n" << std::flush;
  }
  CoUninitialize();
  std::cout << "PASS: live WebView and engine shutdown\n";
  return 0;
}
