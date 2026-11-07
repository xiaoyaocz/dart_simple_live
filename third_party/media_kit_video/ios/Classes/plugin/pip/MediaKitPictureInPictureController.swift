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
        controller.isPictureInPictureActive
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
      displayLayer.flushAndRemoveImage()
      displayLayer.removeFromSuperlayer()
    }

    private func enqueue(pixelBuffer: CVPixelBuffer) {
      let retained = pixelBuffer
      enqueueQueue.async { [weak self] in
        guard let self = self else { return }
        guard self.displayLayer.isReadyForMoreMediaData else { return }
        guard let sample = self.makeSampleBuffer(from: retained) else { return }
        self.displayLayer.enqueue(sample)
        if !self.firstFrameEnqueued {
          self.firstFrameEnqueued = true
          if self.startRequested {
            DispatchQueue.main.async { [weak self] in
              self?.attemptStart()
            }
          }
        }
      }
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
    }

    func pictureInPictureController(
      _ controller: AVPictureInPictureController,
      restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
        @escaping (Bool) -> Void
    ) {
      didRestoreInterface = true
      eventCallback(["event": "restore"])
      completionHandler(true)
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
