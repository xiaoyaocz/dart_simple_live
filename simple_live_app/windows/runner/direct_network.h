#ifndef RUNNER_DIRECT_NETWORK_H_
#define RUNNER_DIRECT_NETWORK_H_

#include <windows.h>
#include <cstdlib>

// Only this process and subsequently created children are affected. Never
// write the registry, WinINet settings or user/machine environment variables.
inline bool ConfigureProcessDirectNetwork() {
  const wchar_t* variables[] = {
      L"HTTP_PROXY", L"HTTPS_PROXY", L"ALL_PROXY", L"FTP_PROXY",
      L"SOCKS_PROXY", L"SOCKS5_PROXY", L"NO_PROXY",
      L"http_proxy", L"https_proxy", L"all_proxy", L"ftp_proxy",
      L"socks_proxy", L"socks5_proxy", L"no_proxy"};
  bool success = true;
  for (const auto* name : variables) {
    // Native dependencies may use CRT getenv, while children inherit Win32's
    // environment block. Clear both before Flutter/plugins/libmpv start.
    if (_wputenv_s(name, L"") != 0) success = false;
    if (!::SetEnvironmentVariableW(name, nullptr) &&
        ::GetLastError() != ERROR_ENVVAR_NOT_FOUND) success = false;
  }
  return success;
}

#endif  // RUNNER_DIRECT_NETWORK_H_
