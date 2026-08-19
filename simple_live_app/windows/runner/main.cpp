#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <windows.h>

#include <algorithm>
#include <fstream>
#include <iterator>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

std::wstring GpuPreferenceFilePath() {
  PWSTR roaming_path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, KF_FLAG_DEFAULT,
                                  nullptr, &roaming_path)) ||
      roaming_path == nullptr) {
    return L"";
  }
  std::wstring path(roaming_path);
  CoTaskMemFree(roaming_path);
  return path + L"\\com.xycz\\simple_live_app\\gpu_preference.txt";
}

std::string ReadGpuPreference() {
  const std::wstring path = GpuPreferenceFilePath();
  if (path.empty()) {
    return "auto";
  }
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    return "auto";
  }
  std::string value((std::istreambuf_iterator<char>(file)),
                    std::istreambuf_iterator<char>());
  value.erase(std::remove_if(value.begin(), value.end(),
                             [](unsigned char character) {
                               return character == '\r' || character == '\n' ||
                                      character == ' ' || character == '\t';
                             }),
              value.end());
  if (value == "low_power") {
    return value;
  }
  if (value == "high_performance") {
    return value;
  }
  return "auto";
}

flutter::GpuPreference ReadFlutterGpuPreference() {
  const std::string value = ReadGpuPreference();
  if (value == "low_power") {
    return flutter::GpuPreference::LowPowerPreference;
  }
  if (value == "high_performance") {
    return flutter::GpuPreference::HighPerformancePreference;
  }
  return flutter::GpuPreference::NoPreference;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE primary_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"June6699.SimpleLive.PrimaryInstance");
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
  // Read the last selected preference before the Flutter engine is created.
  project.set_gpu_preference(ReadFlutterGpuPreference());

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  if (secondary_instance) {
    command_line_arguments.push_back("--simple-live-secondary-instance");
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"simple_live_app", origin, size)) {
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
