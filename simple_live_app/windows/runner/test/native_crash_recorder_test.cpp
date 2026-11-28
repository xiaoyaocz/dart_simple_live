#include <windows.h>
#include <dbghelp.h>
#include <cstdio>
#include <string>
#include "../native_crash_recorder.h"

// Catch the real SEH exception: the recorder must never consume it.
__declspec(noinline) bool RaiseFault(DWORD code) {
  __try {
    if (code == EXCEPTION_ACCESS_VIOLATION) {
      *reinterpret_cast<volatile int*>(static_cast<ULONG_PTR>(1)) = 1;
    } else {
      RaiseException(code, 0, 0, nullptr);
    }
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return GetExceptionCode() == code;
  }
  return false;
}

int wmain(int argc, wchar_t** argv) {
  if (argc != 3) return 2;
  const std::wstring folder = argv[1], mode = argv[2];
  const bool enabled = StartNativeCrashRecorder(folder.c_str());
  if (mode == L"invalid") return !enabled && RaiseFault(EXCEPTION_ACCESS_VIOLATION) ? 0 : 3;
  if (!enabled) return 4;
  if (!RaiseFault(0xe1234567)) return 5;
  if (mode != L"normal") {
    if (!RaiseFault(EXCEPTION_ACCESS_VIOLATION) ||
        !RaiseFault(EXCEPTION_ACCESS_VIOLATION)) return 6;
  }
  WIN32_FIND_DATAW data{};
  HANDLE find = FindFirstFileW((folder + L"/*.dmp").c_str(), &data);
  int count = 0;
  std::wstring dump;
  if (find != INVALID_HANDLE_VALUE) {
    do { ++count; dump = folder + L"/" + data.cFileName; }
    while (FindNextFileW(find, &data));
    FindClose(find);
  }
  if (mode == L"normal") return count == 0 ? 0 : 7;
  if (mode == L"full") return count == 5 ? 0 : 8;
  if (count != 1) return 9;
  HANDLE file = CreateFileW(dump.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
  HANDLE mapping = CreateFileMappingW(file, nullptr, PAGE_READONLY, 0, 0, nullptr);
  auto base = MapViewOfFile(mapping, FILE_MAP_READ, 0, 0, 0);
  PMINIDUMP_DIRECTORY directory = nullptr;
  void* stream = nullptr;
  ULONG size = 0;
  bool valid = base && static_cast<MINIDUMP_HEADER*>(base)->Signature == MINIDUMP_SIGNATURE &&
      MiniDumpReadDumpStream(base, ExceptionStream, &directory, &stream, &size);
  if (valid) {
    auto exception = static_cast<MINIDUMP_EXCEPTION_STREAM*>(stream);
    valid = exception->ThreadId == GetCurrentThreadId() &&
        exception->ExceptionRecord.ExceptionCode == EXCEPTION_ACCESS_VIOLATION &&
        exception->ExceptionRecord.ExceptionInformation[1] == 1;
  }
  if (base) UnmapViewOfFile(base);
  if (mapping) CloseHandle(mapping);
  if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
  std::puts(valid ? "PASS: fault thread/context retained; SEH continues; repeated AV limited" : "FAIL: dump context");
  return valid ? 0 : 10;
}
