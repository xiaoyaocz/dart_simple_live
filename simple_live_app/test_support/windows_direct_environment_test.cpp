#include "../windows/runner/direct_network.h"
#include <iostream>

int main() {
  if (!ConfigureProcessDirectNetwork()) return 1;
  for (const wchar_t* name : {L"HTTP_PROXY", L"HTTPS_PROXY", L"ALL_PROXY",
                              L"SOCKS_PROXY", L"NO_PROXY"}) {
    if (::GetEnvironmentVariableW(name, nullptr, 0) != 0 ||
        _wgetenv(name) != nullptr) return 2;
  }
  std::cout << "PASS native Win32 and CRT proxy environment cleared\n";
  return 0;
}
