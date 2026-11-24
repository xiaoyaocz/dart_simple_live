#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE primary_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"June6699.SimpleLiveTV.PrimaryInstance");
  const bool secondary_instance = primary_instance_mutex != nullptr &&
                                  ::GetLastError() == ERROR_ALREADY_EXISTS;
  bool com_initialized = false;

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  const HRESULT co_initialize_result =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  com_initialized = SUCCEEDED(co_initialize_result) ||
                    co_initialize_result == RPC_E_CHANGED_MODE;

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  if (secondary_instance) {
    constexpr char kSecondaryInstanceArgument[] =
        "--simple-live-secondary-instance";
    bool has_secondary_instance_argument = false;
    for (const auto &argument : command_line_arguments) {
      if (argument == kSecondaryInstanceArgument) {
        has_secondary_instance_argument = true;
        break;
      }
    }
    if (!has_secondary_instance_argument) {
      command_line_arguments.push_back(kSecondaryInstanceArgument);
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"simple_live_tv_app", origin, size)) {
    if (com_initialized) {
      ::CoUninitialize();
    }
    if (primary_instance_mutex != nullptr) {
      if (!secondary_instance) {
        ::ReleaseMutex(primary_instance_mutex);
      }
      ::CloseHandle(primary_instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (com_initialized) {
    ::CoUninitialize();
  }
  if (primary_instance_mutex != nullptr) {
    if (!secondary_instance) {
      ::ReleaseMutex(primary_instance_mutex);
    }
    ::CloseHandle(primary_instance_mutex);
  }
  return EXIT_SUCCESS;
}
