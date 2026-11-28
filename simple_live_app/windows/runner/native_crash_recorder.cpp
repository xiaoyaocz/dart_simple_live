#include "native_crash_recorder.h"

#include <windows.h>
#include <dbghelp.h>
#include <shlobj.h>
#include <cstdio>
#include <string>

#ifndef FLUTTER_VERSION
#define FLUTTER_VERSION "native-test"
#endif

namespace {
// Intentionally process-lifetime storage: shutdown must not free memory or
// handles while an exception on another thread is still using them.
struct Recorder {
  LONG initialized = 0;
  LONG captured = 0;
  HANDLE requested = nullptr;
  HANDLE completed = nullptr;
  DWORD thread_id = 0;
  EXCEPTION_RECORD record{};
  CONTEXT context{};
  wchar_t dump_path[MAX_PATH]{};
  wchar_t metadata_path[MAX_PATH]{};
};
Recorder recorder;

DWORD WINAPI WriteDump(void*) {
  if (WaitForSingleObject(recorder.requested, INFINITE) != WAIT_OBJECT_0) return 0;
  EXCEPTION_POINTERS pointers{&recorder.record, &recorder.context};
  MINIDUMP_EXCEPTION_INFORMATION exception{recorder.thread_id, &pointers, FALSE};
  HANDLE file = CreateFileW(recorder.dump_path, GENERIC_WRITE, 0, nullptr,
                            CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  BOOL saved = FALSE;
  DWORD error = ERROR_SUCCESS;
  if (file != INVALID_HANDLE_VALUE) {
    saved = MiniDumpWriteDump(
        GetCurrentProcess(), GetCurrentProcessId(), file,
        static_cast<MINIDUMP_TYPE>(MiniDumpNormal | MiniDumpWithThreadInfo |
                                   MiniDumpWithUnloadedModules),
        &exception, nullptr, nullptr);
    if (!saved) error = GetLastError();
    CloseHandle(file);
  } else {
    error = GetLastError();
  }
  char metadata[1024]{};
  const int length = sprintf_s(
      metadata,
      "first_chance=1 (may be handled; not proof of a fatal crash)\r\n"
      "version=%s\r\npid=%lu\r\nthread=%lu\r\nexception=0x%08lx\r\n"
      "instruction=%p\r\noperation=%llu\r\naccess_address=0x%llx\r\n"
      "dump_saved=%d\r\nwin32_error=%lu\r\n",
      FLUTTER_VERSION, GetCurrentProcessId(), recorder.thread_id,
      recorder.record.ExceptionCode, recorder.record.ExceptionAddress,
      static_cast<unsigned long long>(recorder.record.ExceptionInformation[0]),
      static_cast<unsigned long long>(recorder.record.ExceptionInformation[1]),
      saved, error);
  file = CreateFileW(recorder.metadata_path, GENERIC_WRITE, 0, nullptr,
                     CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    DWORD written = 0;
    if (length > 0) WriteFile(file, metadata, static_cast<DWORD>(length), &written, nullptr);
    CloseHandle(file);
  }
  SetEvent(recorder.completed);
  return 0;
}

LONG CALLBACK RecordException(EXCEPTION_POINTERS* exception) {
  if (exception->ExceptionRecord->ExceptionCode != EXCEPTION_ACCESS_VIOLATION ||
      InterlockedCompareExchange(&recorder.captured, 1, 0) != 0) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  recorder.thread_id = GetCurrentThreadId();
  recorder.record = *exception->ExceptionRecord;
  recorder.record.ExceptionRecord = nullptr;
  recorder.context = *exception->ContextRecord;
  // No allocations, symbol loading or file I/O on the faulting thread. Capture
  // only once; immutable storage remains valid even if the worker times out.
  SetEvent(recorder.requested);
  WaitForSingleObject(recorder.completed, 3000);
  return EXCEPTION_CONTINUE_SEARCH;
}
}  // namespace

bool StartNativeCrashRecorder(const wchar_t* directory) {
  if (InterlockedCompareExchange(&recorder.initialized, 1, 0) != 0) return false;
  std::wstring folder;
  if (directory) {
    folder = directory;
  } else {
    PWSTR local = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local))) return false;
    folder = std::wstring(local) + L"\\com.xycz\\simple_live_app\\native_crashes";
    CoTaskMemFree(local);
  }
  if (folder.size() > MAX_PATH - 80) return false;
  const int created = SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
  if (created != ERROR_SUCCESS && created != ERROR_ALREADY_EXISTS &&
      created != ERROR_FILE_EXISTS) return false;
  const DWORD attributes = GetFileAttributesW(folder.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES || !(attributes & FILE_ATTRIBUTE_DIRECTORY)) return false;

  WIN32_FIND_DATAW entry{};
  HANDLE find = FindFirstFileW((folder + L"\\*.dmp").c_str(), &entry);
  int count = 0;
  if (find != INVALID_HANDLE_VALUE) {
    do { if (!(entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) ++count; }
    while (FindNextFileW(find, &entry));
    FindClose(find);
  } else if (GetLastError() != ERROR_FILE_NOT_FOUND) {
    return false;
  }
  // Do not delete user evidence. At five dumps recording stops until the user
  // moves them elsewhere. Single-instance runner prevents concurrent writers.
  if (count >= 5) return true;
  SYSTEMTIME time{};
  GetSystemTime(&time);
  wchar_t name[80]{};
  swprintf_s(name, L"\\av-%04u%02u%02u-%02u%02u%02u-%03u-%lu",
             time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
             time.wSecond, time.wMilliseconds, GetCurrentProcessId());
  wcscpy_s(recorder.dump_path, (folder + name + L".dmp").c_str());
  wcscpy_s(recorder.metadata_path, (folder + name + L".txt").c_str());
  recorder.requested = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  recorder.completed = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!recorder.requested || !recorder.completed) return false;
  // Pre-load DbgHelp before exceptions (it may otherwise need the loader lock).
  if (!LoadLibraryW(L"dbghelp.dll")) return false;
  HANDLE worker = CreateThread(nullptr, 0, WriteDump, nullptr, 0, nullptr);
  if (!worker) return false;
  CloseHandle(worker);
  return AddVectoredExceptionHandler(1, RecordException) != nullptr;
}
