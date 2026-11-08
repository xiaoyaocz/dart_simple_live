#if canImport(Flutter)
  import AVFoundation
  import AVKit
  import CoreMedia
  import Flutter
  import UIKit

  /// 将 `AVPictureInPictureController` 与 media_kit_video 的 `VideoOutput`
  /// 帧源桥接：每帧渲染出的 CVPixelBuffer 以零拷贝方式送入
  /// `AVSampleBufferDisplayLayer`，由系统 PiP 窗口呈现。
  ///
  /// 这是 Apple 对非 AVPlayer 渲染器的官方画中画路径（iOS 15+）。
  @available(iOS 15.0, *)
  final class MediaKitPictureInPictureController: NSObject {
    typealias EventCallback = ([String: Any]) -> Void

    private let hostView: UIView
    private let outputManager: VideoOutputManager
    private let eventCallback: EventCallback
    private let displayLayer: AVSampleBufferDisplayLayer
    private var pipController: AVPictureInPictureController?
    private let enqueueQueue = DispatchQueue(
      label: "media_kit_video.pip.enqueue",
      qos: .userInteractive
    )

    private var handle: Int64?
    private var isPlayingState: Bool = true
    private var startRequested: Bool = false
    private var firstFrameEnqueued: Bool = false
    private var startAttempts: Int = 0
    private var didRestoreInterface: Bool = false
    private var didReturnToApp: Bool = false
    /// PiP 停止流程进行中（willStop → didStop 之间）。此期间跳过
    /// didBecomeActive 的自动停止，避免与系统已启动的停止流程叠加，
    /// 造成状态机卡死（PiP 窗口残留，App 与小窗双放）
    private var isStopInProgress: Bool = false
    private var enqueuedFrameCount: Int = 0
    private var droppedByBackpressureCount: Int = 0
    /// 仅在 enqueueQueue 上访问：置位后丢弃所有后续入队
    private var isStopped = false

    init(
      hostView: UIView,
      outputManager: VideoOutputManager,
      eventCallback: @escaping EventCallback
    ) {
      self.hostView = hostView
      self.outputManager = outputManager
      self.eventCallback = eventCallback
      self.displayLayer = AVSampleBufferDisplayLayer()
      super.init()

      displayLayer.videoGravity = .resizeAspect
      displayLayer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
      displayLayer.isOpaque = false
      displayLayer.backgroundColor = UIColor.clear.cgColor
      hostView.layer.insertSublayer(displayLayer, at: 0)

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(appDidBecomeActive),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
      teardown()
    }

    /// 回到前台时结束画中画（用户主动返回 App 的场景）。
    /// 标记 didReturnToApp，让 Dart 侧把这次结束与"用户点关闭"区分开。
    @objc private func appDidBecomeActive() {
      guard let controller = pipController,
        controller.isPictureInPictureActive,
        !isStopInProgress
      else { return }
      didReturnToApp = true
      DispatchQueue.main.async {
        controller.stopPictureInPicture()
      }
    }

    var isActive: Bool {
      return pipController?.isPictureInPictureActive ?? false
    }

    /// 建立帧管线并创建 PiP 控制器。成功后可调用 `enter()` 立即进入小窗，
    /// 或依赖 `autoEnter`（退后台自动进入）。
    @discardableResult
    func start(
      handle: Int64,
      autoEnter: Bool,
      startImmediately: Bool
    ) -> Bool {
      NSLog(
        "MediaKitPiP: start handle=%lld autoEnter=%d startImmediately=%d",
        handle,
        autoEnter ? 1 : 0,
        startImmediately ? 1 : 0
      )
      self.handle = handle

      let contentSource = AVPictureInPictureController.ContentSource(
        sampleBufferDisplayLayer: displayLayer,
        playbackDelegate: self
      )
      let controller = AVPictureInPictureController(contentSource: contentSource)
      controller.delegate = self
      controller.canStartPictureInPictureAutomaticallyFromInline = autoEnter
      self.pipController = controller

      outputManager.setOnFrameRendered(handle: handle) { [weak self] pixelBuffer in
        self?.enqueue(pixelBuffer: pixelBuffer)
      }

      self.startRequested = startImmediately
      self.firstFrameEnqueued = false
      self.startAttempts = 0
      if startImmediately {
        // 无帧看门狗：软路径建立失败等场景下帧永远不会到来，
        // 5 秒内没有首帧则上报 failed，让 Dart 侧还原配置并提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
          guard let self = self,
            !self.firstFrameEnqueued,
            self.pipController != nil
          else { return }
          NSLog("MediaKitPiP: no frames within 5s, report failed")
          self.eventCallback(["event": "failed", "reason": "no_frames"])
        }
      }
      return true
    }

    private func attemptStart() {
      guard let controller = pipController else { return }
      if controller.isPictureInPictureActive { return }
      if controller.isPictureInPicturePossible {
        controller.startPictureInPicture()
        return
      }
      startAttempts += 1
      if startAttempts >= 20 {
        eventCallback(["event": "failed", "reason": "pip_not_possible"])
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.attemptStart()
      }
    }

    func enter() {
      startAttempts = 0
      attemptStart()
    }

    func stop() {
      if let controller = pipController, controller.isPictureInPictureActive {
        DispatchQueue.main.async { controller.stopPictureInPicture() }
      }
      teardown()
    }

    func setAutoEnter(_ enabled: Bool) {
      pipController?.canStartPictureInPictureAutomaticallyFromInline = enabled
    }

    private func teardown() {
      if let handle = handle {
        outputManager.setOnFrameRendered(handle: handle, nil)
        self.handle = nil
      }
      pipController = nil
      // 断流与 flush 必须在同一队列上串行：flush 与 enqueue 竞争是
      // 文档化的崩溃条件。AVSampleBufferDisplayLayer 的媒体 API
      // （enqueue/flush）自身线程安全，主线程约束只涉及几何属性
      enqueueQueue.async { [weak self] in
        guard let self = self else { return }
        self.isStopped = true
        self.displayLayer.flushAndRemoveImage()
        DispatchQueue.main.async { [weak self] in
          self?.displayLayer.removeFromSuperlayer()
        }
      }
    }

    private func enqueue(pixelBuffer: CVPixelBuffer) {
      let retained = pixelBuffer
      enqueueQueue.async { [weak self] in
        guard let self = self, !self.isStopped else { return }
        // 后台/前台切换后图层解码器可能失效，需先 flush 才能继续
        // enqueue（Apple: requiresFlushToResumeDecoding）
        if self.displayLayer.status == .failed
          || self.displayLayer.requiresFlushToResumeDecoding {
          NSLog("MediaKitPiP: layer decoder invalid, flush before enqueue")
          self.displayLayer.flush()
        }
        guard self.displayLayer.isReadyForMoreMediaData else {
          self.droppedByBackpressureCount += 1
          if self.droppedByBackpressureCount % 120 == 1 {
            NSLog(
              "MediaKitPiP: frame dropped by backpressure (total=%d)",
              self.droppedByBackpressureCount
            )
          }
          return
        }
        // 关键：拷贝到私有缓冲再入队。渲染池只有 3 块缓冲轮转复用，
        // 若直接引用池内缓冲，退出小窗后图层残留的引用会与 GL 渲染
        // 争抢同一块内存，App 内画面表现为卡在某处反复抽动
        guard let privateBuffer = Self.copyPixelBuffer(retained) else {
          NSLog("MediaKitPiP: copyPixelBuffer failed, fallback to shared")
          guard let sample = self.makeSampleBuffer(from: retained) else {
            return
          }
          self.displayLayer.enqueue(sample)
          return
        }
        guard let sample = self.makeSampleBuffer(from: privateBuffer) else {
          NSLog("MediaKitPiP: makeSampleBuffer failed")
          return
        }
        self.displayLayer.enqueue(sample)
        self.enqueuedFrameCount += 1
        if !self.firstFrameEnqueued {
          self.firstFrameEnqueued = true
          NSLog("MediaKitPiP: first frame enqueued")
          if self.startRequested {
            DispatchQueue.main.async { [weak self] in
              self?.attemptStart()
            }
          }
        } else if self.enqueuedFrameCount % 120 == 0 {
          NSLog(
            "MediaKitPiP: enqueued %d frames",
            self.enqueuedFrameCount
          )
          // 桥接进 Dart 日志（app 日志导出不含 NSLog），便于真机定位
          self.eventCallback([
            "event": "stats",
            "enqueued": self.enqueuedFrameCount,
            "dropped": self.droppedByBackpressureCount,
          ])
        }
      }
    }

    /// 把渲染缓冲拷贝到一块私有 CVPixelBuffer（与源同尺寸同像素格式）
    private static func copyPixelBuffer(_ src: CVPixelBuffer) -> CVPixelBuffer? {
      let width = CVPixelBufferGetWidth(src)
      let height = CVPixelBufferGetHeight(src)
      let format = CVPixelBufferGetPixelFormatType(src)
      var dst: CVPixelBuffer?
      let attrs = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary
      guard
        CVPixelBufferCreate(
          kCFAllocatorDefault, width, height, format, attrs, &dst
        ) == kCVReturnSuccess,
        let out = dst
      else { return nil }

      CVPixelBufferLockBaseAddress(src, .readOnly)
      CVPixelBufferLockBaseAddress(out, [])
      defer {
        CVPixelBufferUnlockBaseAddress(src, .readOnly)
        CVPixelBufferUnlockBaseAddress(out, [])
      }

      guard let srcBase = CVPixelBufferGetBaseAddress(src),
        let dstBase = CVPixelBufferGetBaseAddress(out)
      else { return nil }

      let srcStride = CVPixelBufferGetBytesPerRow(src)
      let dstStride = CVPixelBufferGetBytesPerRow(out)
      if srcStride == dstStride {
        memcpy(dstBase, srcBase, srcStride * height)
      } else {
        // 行跨度不一致（对齐差异）时逐行拷贝
        let rowBytes = min(srcStride, dstStride)
        for row in 0..<height {
          memcpy(
            dstBase.advanced(by: row * dstStride),
            srcBase.advanced(by: row * srcStride),
            rowBytes
          )
        }
      }
      return out
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
      var formatDescription: CMVideoFormatDescription?
      let fdStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDescription
      )
      guard fdStatus == noErr, let description = formatDescription else { return nil }

      let presentationTime = CMClockGetTime(CMClockGetHostTimeClock())
      var timingInfo = CMSampleTimingInfo(
        duration: .invalid,
        presentationTimeStamp: presentationTime,
        decodeTimeStamp: .invalid
      )

      var sampleBuffer: CMSampleBuffer?
      let status = CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: description,
        sampleTiming: &timingInfo,
        sampleBufferOut: &sampleBuffer
      )
      guard status == noErr, let buffer = sampleBuffer else { return nil }

      if let attachments = CMSampleBufferGetSampleAttachmentsArray(
        buffer,
        createIfNecessary: true
      ) as? [NSMutableDictionary],
        let first = attachments.first
      {
        first[kCMSampleAttachmentKey_DisplayImmediately as NSString] = kCFBooleanTrue
      }
      return buffer
    }
  }

  @available(iOS 15.0, *)
  extension MediaKitPictureInPictureController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
      _ controller: AVPictureInPictureController
    ) {
      eventCallback(["event": "willStart"])
    }

    func pictureInPictureControllerDidStartPictureInPicture(
      _ controller: AVPictureInPictureController
    ) {
      eventCallback(["event": "didStart"])
    }

    func pictureInPictureController(
      _ controller: AVPictureInPictureController,
      failedToStartPictureInPictureWithError error: Error
    ) {
      eventCallback(["event": "failed", "reason": error.localizedDescription])
    }

    func pictureInPictureControllerWillStopPictureInPicture(
      _ controller: AVPictureInPictureController
    ) {
      didRestoreInterface = false
      isStopInProgress = true
      eventCallback(["event": "willStop"])
    }

    func pictureInPictureControllerDidStopPictureInPicture(
      _ controller: AVPictureInPictureController
    ) {
      if didRestoreInterface || didReturnToApp {
        eventCallback(["event": "didStop"])
      } else {
        eventCallback(["event": "closed"])
      }
      didRestoreInterface = false
      didReturnToApp = false
      isStopInProgress = false
    }

    func pictureInPictureController(
      _ controller: AVPictureInPictureController,
      restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
        @escaping (Bool) -> Void
    ) {
      didRestoreInterface = true
      eventCallback(["event": "restore"])
      // completionHandler 必须异步调用：同步调用会让 AVKit 的停止
      // 状态机卡在 willStop 与 didStop 之间（实测 PiP 窗口残留、
      // App 与小窗双放持续）。同时兜底校验，若 1.5 秒后小窗仍存活
      // 则再次请求停止。
      DispatchQueue.main.async { completionHandler(true) }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
        guard let self = self,
          let controller = self.pipController,
          controller.isPictureInPictureActive
        else { return }
        NSLog("MediaKitPiP: PiP still active after restore, retry stop")
        controller.stopPictureInPicture()
      }
    }
  }

  @available(iOS 15.0, *)
  extension MediaKitPictureInPictureController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(
      _ pipController: AVPictureInPictureController,
      setPlaying playing: Bool
    ) {
      isPlayingState = playing
      eventCallback(["event": "setPlaying", "playing": playing])
    }

    /// 直播流没有确定的可播区间，返回无限区间禁用进度条。
    func pictureInPictureControllerTimeRangeForPlayback(
      _ pipController: AVPictureInPictureController
    ) -> CMTimeRange {
      return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
      _ pipController: AVPictureInPictureController
    ) -> Bool {
      return !isPlayingState
    }

    func pictureInPictureController(
      _ pipController: AVPictureInPictureController,
      didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {
    }

    /// 直播不支持快进快退，直接完成。
    func pictureInPictureController(
      _ pipController: AVPictureInPictureController,
      skipByInterval skipInterval: CMTime,
      completion completionHandler: @escaping () -> Void
    ) {
      completionHandler()
    }
  }
#endif
