#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <chrono>
#include <thread>

#include "direct_network.h"
#include "flutter_window.h"
#include "native_crash_recorder.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!ConfigureProcessDirectNetwork()) return EXIT_FAILURE;
  HANDLE single_instance =
      ::CreateMutexW(nullptr, FALSE, L"Local\\SimpleLiveDesktopSingleInstance");
  if (single_instance && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window = nullptr;
    for (int attempt = 0; attempt < 50 && !existing_window; ++attempt) {
      existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Simple Live");
      if (!existing_window) {
        existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW",
                                        L"simple_live_app");
      }
      if (!existing_window) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
      }
    }
    if (existing_window) {
      ::ShowWindow(existing_window, SW_RESTORE);
      ::SetForegroundWindow(existing_window);
    }
    ::CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Diagnostic failure must not prevent playback or change exception handling.
  StartNativeCrashRecorder();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"simple_live_app", origin, size)) {
    if (single_instance) ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  window.SetQuitOnClose(false);
  window.Destroy();
  ::CoUninitialize();
  if (single_instance) ::CloseHandle(single_instance);
  return EXIT_SUCCESS;
}
