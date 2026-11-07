import Foundation

/// mpv 渲染上下文 update callback 的宿主协议
protocol MPVUpdateCallbackTarget: NSObjectProtocol {
  func updateCallback()
}

/// mpv 渲染上下文的 update callback 以裸指针回调宿主纹理。
/// 运行时切换渲染上下文（画中画软/硬切换）会在帧热流中释放纹理，
/// 已派发到主队列的回调块可能晚于纹理释放执行，裸指针直接强转
/// 会形成野指针崩溃。代理对象由纹理持有、dispose 后延迟释放，
/// 对纹理的引用为弱引用，纹理释放后回调自然变空操作。
final class MPVUpdateCallbackProxy: NSObject {
  weak var target: MPVUpdateCallbackTarget?

  func fire() {
    target?.updateCallback()
  }
}
