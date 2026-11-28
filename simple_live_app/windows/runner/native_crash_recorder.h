#ifndef RUNNER_NATIVE_CRASH_RECORDER_H_
#define RUNNER_NATIVE_CRASH_RECORDER_H_

// Installs a process-lifetime, local-only first-chance AV recorder. Never
// changes exception handling. An optional existing directory is used by tests.
bool StartNativeCrashRecorder(const wchar_t* directory = nullptr);

#endif  // RUNNER_NATIVE_CRASH_RECORDER_H_
