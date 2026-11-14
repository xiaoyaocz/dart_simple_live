import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';
// media_kit 未公开导出 NativeLibrary（DLL 路径由 ensureInitialized 解析并缓存），
// 退出流程需要同一份路径，复制解析逻辑会随 media_kit 版本漂移。
// ignore: implementation_imports
import 'package:media_kit/src/player/native/core/native_library.dart';

/// 在 Windows 进程退出前，显式让 mpv 核心停止所有内部线程。
///
/// media_kit 默认在 Player.dispose 后延迟 5 秒才调用 mpv_terminate_destroy。
/// 关闭应用时进程在 5 秒内退出，mpv 内部线程仍在运行，DLL 卸载时会触发
/// fast-fail（"快速异常检测失败"）。这里在渲染上下文已释放后，主动发送
/// quit 并等待 MPV_EVENT_SHUTDOWN，确保核心线程在 DLL 卸载前结束。
class MpvExitHelper {
  static Future<void> shutdown(int handleAddress) async {
    final mpv = MPV(DynamicLibrary.open(NativeLibrary.path));
    final handle = Pointer<mpv_handle>.fromAddress(handleAddress);

    final quit = 'quit'.toNativeUtf8();
    try {
      mpv.mpv_command_string(handle, quit.cast());
    } finally {
      calloc.free(quit);
    }

    // 等待核心 shutdown（内部线程结束），带超时兜底避免无限等待。
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final event = mpv.mpv_wait_event(handle, 0.2);
      if (event.address == 0) {
        break;
      }
      if (event.ref.event_id == mpv_event_id.MPV_EVENT_SHUTDOWN) {
        break;
      }
    }
  }
}
