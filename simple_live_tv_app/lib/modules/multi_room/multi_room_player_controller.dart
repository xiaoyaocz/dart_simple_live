import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_tv_app/services/mpv_options_service.dart';

class MultiRoomPlayerController extends GetxController {
  final MultiRoomItem item;

  MultiRoomPlayerController(this.item);

  late final Player player = Player(
    configuration: PlayerConfiguration(
      title: item.userName,
      logLevel: MPVLogLevel.error,
    ),
  );
  late final VideoController videoController = VideoController(
    player,
    configuration: MpvOptionsService.videoControllerConfiguration(),
  );

  final detail = Rx<LiveRoomDetail?>(null);
  final loading = true.obs;
  final liveStatus = false.obs;
  final errorText = "".obs;
  final muted = true.obs;
  final qualityInfo = "".obs;
  final lineInfo = "".obs;

  List<LivePlayQuality> _qualities = const [];
  List<String> _playUrls = const [];
  Map<String, String>? _playHeaders;
  int _qualityIndex = -1;
  int _lineIndex = 0;
  int _mediaErrorRetryCount = 0;
  int _streamErrorRetryCount = 0;
  bool _disposed = false;
  int _loadGeneration = 0;
  DateTime? _lastAudioDiagnosticTime;
  bool _streamErrorRetrying = false;
  int? _streamRecoveryGeneration;
  bool _mediaRecoveryInProgress = false;
  int? _mediaRecoveryGeneration;
  Timer? _stablePlaybackTimer;
  Future<void>? _playerOpeningFuture;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription? _logSubscription;

  bool _isLoadCurrent(int generation) {
    return !_disposed && generation == _loadGeneration;
  }

  String get title {
    final roomTitle = detail.value?.title.trim();
    if (roomTitle != null && roomTitle.isNotEmpty) {
      return roomTitle;
    }
    return item.userName;
  }

  @override
  void onInit() {
    super.onInit();
    _initPlayerStreams();
    unawaited(MpvOptionsService.applyToPlayer(player));
    unawaited(load());
  }

  void _initPlayerStreams() {
    _errorSubscription = player.stream.error.listen((event) {
      if (PlayerErrorClassifier.isRecoverableAudioDiagnostic(event)) {
        final now = DateTime.now();
        if (_lastAudioDiagnosticTime == null ||
            now.difference(_lastAudioDiagnosticTime!) >=
                const Duration(seconds: 15)) {
          _lastAudioDiagnosticTime = now;
          Log.d(
            "多屏同播音频诊断（已忽略）：${item.site.id}/${item.roomId} $event",
          );
        }
        return;
      }
      Log.d("多屏同播播放器错误：${item.site.id}/${item.roomId} $event");

      // Fix TV多开灰屏: 检测流错误并自动重试
      if (_isStreamError(event)) {
        unawaited(_handleStreamError(event));
        return;
      }

      unawaited(_handleMediaError(event));
    });
    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        unawaited(_handleMediaEnd());
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("多屏同播播放器日志：${item.site.id}/${item.roomId} ${event.text}");
    });
  }

  // Fix TV多开灰屏: 判断是否为流错误
  bool _isStreamError(String error) {
    return error.contains('mbedtls_ssl_read') ||
        error.contains('Packet corrupt') ||
        error.contains('Packet corupt') ||
        error.contains('tls:') ||
        error.contains('Invalid NAL unit') ||
        error.contains('missing picture');
  }

  // Fix TV多开灰屏: 处理流错误，自动重试解码器
  Future<void> _handleStreamError(String error) async {
    final generation = _loadGeneration;
    if ((_streamErrorRetrying && _streamRecoveryGeneration == generation) ||
        (_mediaRecoveryInProgress && _mediaRecoveryGeneration == generation)) {
      return;
    }
    if (!_isLoadCurrent(generation) || _playUrls.isEmpty) {
      return;
    }
    _streamErrorRetrying = true;
    _streamRecoveryGeneration = generation;
    try {
      final opening = _playerOpeningFuture;
      if (opening != null) {
        try {
          await opening;
        } catch (e, stackTrace) {
          Log.e(
            "多屏同播流恢复等待打开完成失败：${item.site.id}/${item.roomId} $e",
            stackTrace,
          );
          return;
        }
      }
      if (!_isLoadCurrent(generation) || _playUrls.isEmpty) {
        return;
      }
      const maxStreamErrorRetries = 3;
      if (_streamErrorRetryCount >= maxStreamErrorRetries) {
        Log.w(
          "多屏同播流错误恢复次数已耗尽，转入线路恢复："
          "${item.site.id}/${item.roomId} $error",
        );
        await _handleMediaError(
          error,
          generation: generation,
          fromStreamError: true,
        );
        return;
      }
      _streamErrorRetryCount += 1;
      Log.w(
        "多屏同播检测到流错误，尝试恢复：${item.site.id}/${item.roomId} $error",
      );

      // 短暂暂停再恢复，触发重新连接
      await player.pause();
      if (!_isLoadCurrent(generation)) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isLoadCurrent(generation)) {
        return;
      }
      await player.play();
      if (!_isLoadCurrent(generation)) {
        return;
      }
    } catch (e, stackTrace) {
      Log.e(
        "多屏同播恢复流失败：${item.site.id}/${item.roomId} $e",
        stackTrace,
      );
      // 恢复失败，走线路切换逻辑
      if (_isLoadCurrent(generation)) {
        await _handleMediaError(
          error,
          generation: generation,
          fromStreamError: true,
        );
      }
    } finally {
      if (_streamRecoveryGeneration == generation) {
        _streamErrorRetrying = false;
        _streamRecoveryGeneration = null;
      }
    }
  }

  Future<void> load() async {
    if (_disposed) {
      return;
    }
    final generation = ++_loadGeneration;
    loading.value = true;
    errorText.value = "";
    liveStatus.value = false;
    _qualities = const [];
    _playUrls = const [];
    _playHeaders = null;
    _qualityIndex = -1;
    _lineIndex = 0;
    _mediaErrorRetryCount = 0;
    _streamErrorRetryCount = 0;
    _stablePlaybackTimer?.cancel();
    _stablePlaybackTimer = null;
    try {
      await _waitForPlayerOpen();
      if (!_isLoadCurrent(generation)) {
        return;
      }
      await player.stop();
      if (!_isLoadCurrent(generation)) {
        return;
      }
      Log.i("多屏同播开始加载房间：${item.site.id}/${item.roomId}");
      final roomDetail =
          await item.site.liveSite.getRoomDetail(roomId: item.roomId);
      if (!_isLoadCurrent(generation)) {
        return;
      }
      Log.i(
        "多屏同播房间详情：${item.site.id}/${item.roomId} "
        "status=${roomDetail.status} record=${roomDetail.isRecord} "
        "title=${roomDetail.title}",
      );
      detail.value = roomDetail;
      liveStatus.value = roomDetail.status || roomDetail.isRecord;
      if (!liveStatus.value) {
        errorText.value = "未开播";
        return;
      }
      await _loadQualities(roomDetail, generation);
      if (!_isLoadCurrent(generation)) {
        return;
      }
      await _loadPlayUrls(roomDetail, generation);
      if (!_isLoadCurrent(generation)) {
        return;
      }
      loading.value = false;
      await _openCurrentUrl(generation);
      if (!_isLoadCurrent(generation)) {
        return;
      }
    } catch (e) {
      if (!_isLoadCurrent(generation)) {
        return;
      }
      Log.e(
        "多屏同播加载失败：${item.site.id}/${item.roomId} $e",
        StackTrace.current,
      );
      errorText.value = e.toString();
    } finally {
      if (_isLoadCurrent(generation)) {
        loading.value = false;
      }
    }
  }

  Future<void> _loadQualities(
    LiveRoomDetail roomDetail,
    int generation,
  ) async {
    final qualities =
        await item.site.liveSite.getPlayQualites(detail: roomDetail);
    if (!_isLoadCurrent(generation)) {
      return;
    }
    if (qualities.isEmpty) {
      throw Exception("无法读取播放清晰度");
    }
    _qualities = qualities;
    final qualityLevel = Platform.isAndroid
        ? 0
        : AppSettingsController.instance.qualityLevel.value;
    if (qualityLevel == 2) {
      _qualityIndex = 0;
    } else if (qualityLevel == 0) {
      _qualityIndex = _qualities.length - 1;
    } else {
      _qualityIndex = (_qualities.length / 2).floor();
    }
    qualityInfo.value = _qualities[_qualityIndex].quality;
    Log.i(
      "多屏同播清晰度：${item.site.id}/${item.roomId} "
      "selected=${qualityInfo.value} index=$_qualityIndex total=${_qualities.length}",
    );
  }

  Future<void> _loadPlayUrls(
    LiveRoomDetail roomDetail,
    int generation,
  ) async {
    final quality = _qualities[_qualityIndex];
    final playUrl = await item.site.liveSite.getPlayUrls(
      detail: roomDetail,
      quality: quality,
    );
    if (!_isLoadCurrent(generation)) {
      return;
    }
    if (playUrl.urls.isEmpty) {
      throw Exception("无法读取播放地址");
    }
    _playUrls = playUrl.urls;
    _playHeaders = playUrl.headers;
    _lineIndex = 0;
    _mediaErrorRetryCount = 0;
    _streamErrorRetryCount = 0;
    lineInfo.value = "线路${_lineIndex + 1}";
    Log.i(
      "多屏同播播放地址：${item.site.id}/${item.roomId} "
      "quality=${qualityInfo.value} urls=${_playUrls.length} "
      "headers=${_playHeaders?.keys.join(',') ?? ''}",
    );
  }

  Future<void> _openCurrentUrl(int generation) async {
    if (!_isLoadCurrent(generation)) {
      return;
    }
    while (true) {
      final opening = _playerOpeningFuture;
      if (opening == null) {
        break;
      }
      try {
        await opening;
      } catch (e, stackTrace) {
        Log.e(
          "多屏同播等待旧播放链接打开失败："
          "${item.site.id}/${item.roomId} $e",
          stackTrace,
        );
      }
      if (!_isLoadCurrent(generation)) {
        return;
      }
    }
    final opening = _performOpenCurrentUrl(generation);
    _playerOpeningFuture = opening;
    try {
      await opening;
    } finally {
      if (identical(_playerOpeningFuture, opening)) {
        _playerOpeningFuture = null;
      }
    }
  }

  Future<void> _performOpenCurrentUrl(int generation) async {
    if (!_isLoadCurrent(generation)) {
      return;
    }
    if (_playUrls.isEmpty || _lineIndex < 0 || _lineIndex >= _playUrls.length) {
      throw Exception("播放线路为空");
    }
    final url = _playUrls[_lineIndex];
    final lineNumber = _lineIndex + 1;
    final lineCount = _playUrls.length;
    final headers = _playHeaders;
    final isMuted = muted.value;
    errorText.value = "";
    Log.i(
      "多屏同播打开播放器：${item.site.id}/${item.roomId} "
      "line=$lineNumber/$lineCount muted=$isMuted",
    );
    try {
      await player.open(Media(url, httpHeaders: headers));
    } catch (e, stackTrace) {
      Log.e(
        "多屏同播打开播放链接失败：${item.site.id}/${item.roomId} $e",
        stackTrace,
      );
      if (_isLoadCurrent(generation)) {
        unawaited(_handleMediaError(e.toString(), generation: generation));
      }
      return;
    }
    if (!_isLoadCurrent(generation)) {
      try {
        await player.stop();
      } catch (e, stackTrace) {
        if (!_disposed) {
          Log.e(
            "多屏同播旧播放链接清理失败：${item.site.id}/${item.roomId} $e",
            stackTrace,
          );
        }
      }
      return;
    }
    await player.setVolume(isMuted ? 0 : 100);
    if (!_isLoadCurrent(generation)) {
      return;
    }
    Log.d(
      "多屏同播播放链接：${item.site.id}/${item.roomId} "
      "线路$lineNumber/$lineCount $url",
    );
    _scheduleStablePlaybackReset(generation);
  }

  Future<void> _waitForPlayerOpen() async {
    final opening = _playerOpeningFuture;
    if (opening == null) {
      return;
    }
    try {
      await opening;
    } catch (e, stackTrace) {
      Log.e(
        "多屏同播等待播放器打开失败：${item.site.id}/${item.roomId} $e",
        stackTrace,
      );
    }
  }

  void _scheduleStablePlaybackReset(int generation) {
    _stablePlaybackTimer?.cancel();
    _stablePlaybackTimer = Timer(const Duration(seconds: 30), () {
      if (!_isLoadCurrent(generation) ||
          player.state.buffering ||
          !player.state.playing) {
        return;
      }
      _streamErrorRetryCount = 0;
      _mediaErrorRetryCount = 0;
    });
  }

  Future<void> _handleMediaEnd() async {
    final generation = _loadGeneration;
    if (!_isLoadCurrent(generation) ||
        _playUrls.isEmpty ||
        (_mediaRecoveryInProgress && _mediaRecoveryGeneration == generation) ||
        (_streamErrorRetrying && _streamRecoveryGeneration == generation)) {
      return;
    }
    _mediaRecoveryInProgress = true;
    _mediaRecoveryGeneration = generation;
    try {
      if (!_isLoadCurrent(generation) || _playUrls.isEmpty) {
        return;
      }
      if (_lineIndex < _playUrls.length - 1) {
        Log.w(
          "多屏同播播放结束，切换线路：${item.site.id}/${item.roomId} "
          "from=${_lineIndex + 1}",
        );
        _lineIndex += 1;
        _mediaErrorRetryCount = 0;
        _streamErrorRetryCount = 0;
        lineInfo.value = "线路${_lineIndex + 1}";
        await _openCurrentUrl(generation);
        if (!_isLoadCurrent(generation)) {
          return;
        }
        return;
      }
      errorText.value = "播放已结束";
      Log.w("多屏同播播放结束：${item.site.id}/${item.roomId}");
    } finally {
      if (_mediaRecoveryGeneration == generation) {
        _mediaRecoveryInProgress = false;
        _mediaRecoveryGeneration = null;
      }
    }
  }

  Future<void> _handleMediaError(
    String error, {
    int? generation,
    bool fromStreamError = false,
  }) async {
    final recoveryGeneration = generation ?? _loadGeneration;
    if (!_isLoadCurrent(recoveryGeneration) ||
        _playUrls.isEmpty ||
        (_mediaRecoveryInProgress &&
            _mediaRecoveryGeneration == recoveryGeneration) ||
        (_streamErrorRetrying &&
            _streamRecoveryGeneration == recoveryGeneration &&
            !fromStreamError)) {
      return;
    }
    _mediaRecoveryInProgress = true;
    _mediaRecoveryGeneration = recoveryGeneration;
    try {
      if (!_isLoadCurrent(recoveryGeneration) || _playUrls.isEmpty) {
        return;
      }
      if (_mediaErrorRetryCount < 2) {
        _mediaErrorRetryCount += 1;
        Log.w(
          "多屏同播播放错误，重试当前线路：${item.site.id}/${item.roomId} "
          "line=${_lineIndex + 1} retry=$_mediaErrorRetryCount error=$error",
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!_isLoadCurrent(recoveryGeneration)) {
          return;
        }
        await _openCurrentUrl(recoveryGeneration);
        if (!_isLoadCurrent(recoveryGeneration)) {
          return;
        }
        return;
      }
      if (_lineIndex < _playUrls.length - 1) {
        Log.w(
          "多屏同播播放错误，切换线路：${item.site.id}/${item.roomId} "
          "from=${_lineIndex + 1} error=$error",
        );
        _lineIndex += 1;
        _mediaErrorRetryCount = 0;
        _streamErrorRetryCount = 0;
        lineInfo.value = "线路${_lineIndex + 1}";
        await _openCurrentUrl(recoveryGeneration);
        if (!_isLoadCurrent(recoveryGeneration)) {
          return;
        }
        return;
      }
      errorText.value = "播放失败：$error";
      Log.e(
        "多屏同播播放失败：${item.site.id}/${item.roomId} $error",
        StackTrace.current,
      );
    } finally {
      if (_mediaRecoveryGeneration == recoveryGeneration) {
        _mediaRecoveryInProgress = false;
        _mediaRecoveryGeneration = null;
      }
    }
  }

  Future<void> refreshRoom() async {
    await load();
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    await player.setVolume(muted.value ? 0 : 100);
  }

  @override
  void onClose() {
    _disposed = true;
    _loadGeneration += 1;
    _stablePlaybackTimer?.cancel();
    _stablePlaybackTimer = null;
    unawaited(_errorSubscription?.cancel());
    unawaited(_completedSubscription?.cancel());
    unawaited(_logSubscription?.cancel());
    unawaited(_disposePlayer());
    super.onClose();
  }

  Future<void> _disposePlayer() async {
    await _waitForPlayerOpen();
    try {
      await player.stop();
      await player.dispose();
    } catch (e, stackTrace) {
      Log.e(
        "多屏同播释放播放器失败：${item.site.id}/${item.roomId} $e",
        stackTrace,
      );
    }
  }
}
