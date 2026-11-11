import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

abstract class LiveSubtitleEngine {
  Future<void> start({
    required String modelPath,
    required String language,
  });

  Future<void> stop();

  Stream<String> get textStream;
}

class LiveSubtitleModelInfo {
  final String type;
  final String title;
  final String directory;
  final String keyFilePath;
  final String recommendedKeyFileName;
  final List<String> requiredFileNames;
  final List<String> missingFileNames;

  const LiveSubtitleModelInfo({
    required this.type,
    required this.title,
    required this.directory,
    required this.keyFilePath,
    required this.recommendedKeyFileName,
    required this.requiredFileNames,
    required this.missingFileNames,
  });

  bool get isValid => missingFileNames.isEmpty;
}

class LiveSubtitleService extends GetxService {
  static LiveSubtitleService get instance => Get.find<LiveSubtitleService>();
  static const bool kFeatureEnabled = true;

  final RxString subtitleText = "".obs;
  final RxBool running = false.obs;
  final RxString statusText = "".obs;
  LiveSubtitleEngine? engine;

  Timer? _previewTimer;
  StreamSubscription<String>? _engineSubscription;
  _DesktopLiveSubtitleEngine? _desktopEngine;
  StreamSubscription<String>? _desktopSubscription;
  String? _playbackUrl;
  Map<String, String>? _playbackHeaders;
  String? _activeDesktopKey;
  static bool _sherpaBindingsInitialized = false;
  final Set<Future<void>> _pendingSynchronizations = {};
  final Set<Future<void>> _pendingStops = {};
  Future<void>? _roomHandoffStop;

  Future<T> _trackRuntimeOperation<T>(
    Future<T> operation,
    Set<Future<void>> pending,
  ) {
    // Track completion independently of success: even a failed initialization
    // must finish before the final stop can safely retire the shared engine.
    final completion = operation.then<void>((_) {},
        onError: (Object error, StackTrace stackTrace) {});
    pending.add(completion);
    completion.then((_) => pending.remove(completion));
    return operation;
  }

  Future<void> _waitForRuntimeOperations(Set<Future<void>> pending) async {
    while (pending.isNotEmpty) {
      await Future.wait<void>(pending.toList());
    }
  }

  void setEngine(LiveSubtitleEngine value) {
    engine = value;
  }

  bool get isDesktopExperiment =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool get uiEnabled => kFeatureEnabled;

  bool get canStartRuntime =>
      kFeatureEnabled && (engine != null || isDesktopExperiment);

  String get platformStatusLabel =>
      isDesktopExperiment ? "当前平台可加载本地模型" : "当前平台暂不支持实时识别";

  bool validateModelPathSync(String path) {
    return inspectModelPathSync(path)?.isValid ?? false;
  }

  Future<bool> validateModelPath(String path) async {
    return (await inspectModelPath(path))?.isValid ?? false;
  }

  LiveSubtitleModelInfo? inspectModelPathSync(String path) {
    final value = path.trim();
    if (value.isEmpty || kIsWeb) {
      return null;
    }
    final file = File(value);
    final dir = Directory(value);
    if (!file.existsSync() && !dir.existsSync()) {
      return null;
    }
    final directory = file.existsSync() ? p.dirname(value) : value;
    return _inspectDirectory(
      directory: directory,
      selectedPath: value,
      exists: (name) => File(p.join(directory, name)).existsSync(),
    );
  }

  Future<LiveSubtitleModelInfo?> inspectModelPath(String path) async {
    final value = path.trim();
    if (value.isEmpty || kIsWeb) {
      return null;
    }
    final fileExists = await File(value).exists();
    final dirExists = await Directory(value).exists();
    if (!fileExists && !dirExists) {
      return null;
    }
    final directory = fileExists ? p.dirname(value) : value;
    return _inspectDirectory(
      directory: directory,
      selectedPath: value,
      exists: (name) => File(p.join(directory, name)).existsSync(),
    );
  }

  LiveSubtitleModelInfo? _inspectDirectory({
    required String directory,
    required String selectedPath,
    required bool Function(String name) exists,
  }) {
    const candidates = [
      _SubtitleModelCandidate(
        type: "paraformer",
        title: "中级 Paraformer 中文 int8",
        recommendedKeyFileName: "model.int8.onnx",
        requiredFileNames: [
          "model.int8.onnx",
          "tokens.txt",
          "config.yaml",
          "am.mvn",
        ],
      ),
      _SubtitleModelCandidate(
        type: "whisper",
        title: "高级 Whisper large-v3 int8",
        recommendedKeyFileName: "large-v3-encoder.int8.onnx",
        requiredFileNames: [
          "large-v3-encoder.int8.onnx",
          "large-v3-decoder.int8.onnx",
          "large-v3-tokens.txt",
        ],
      ),
      _SubtitleModelCandidate(
        type: "zipformer",
        title: "甜点级 Zipformer 中英双语 int8",
        recommendedKeyFileName: "encoder-epoch-99-avg-1.int8.onnx",
        requiredFileNames: [
          "encoder-epoch-99-avg-1.int8.onnx",
          "decoder-epoch-99-avg-1.int8.onnx",
          "joiner-epoch-99-avg-1.int8.onnx",
          "tokens.txt",
          "bpe.model",
          "bpe.vocab",
        ],
      ),
    ];

    final selectedName = p.basename(selectedPath);
    _SubtitleModelCandidate? best;
    var bestScore = -1;
    for (final candidate in candidates) {
      var score = candidate.requiredFileNames.where(exists).length;
      if (candidate.requiredFileNames.contains(selectedName)) {
        score += 4;
      }
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (best == null || bestScore <= 0) {
      return null;
    }
    final missing = best.requiredFileNames.where((name) => !exists(name));
    return LiveSubtitleModelInfo(
      type: best.type,
      title: best.title,
      directory: directory,
      keyFilePath: p.join(directory, best.recommendedKeyFileName),
      recommendedKeyFileName: best.recommendedKeyFileName,
      requiredFileNames: best.requiredFileNames,
      missingFileNames: missing.toList(),
    );
  }

  String modelPathSubtitle(String path) {
    final value = path.trim();
    if (value.isEmpty) {
      return "不内置模型，需下载后选择关键 onnx 文件";
    }
    final info = inspectModelPathSync(value);
    if (info == null) {
      return "未识别模型，请选择推荐模型的关键 onnx 文件";
    }
    if (!info.isValid) {
      return "缺少：${info.missingFileNames.join("、")}";
    }
    return "${info.title} · ${info.directory}";
  }

  Future<bool> syncPreviewFromSettings({
    String? mediaUrl,
    Map<String, String>? httpHeaders,
  }) {
    if (_roomHandoffStop != null) return Future<bool>.value(false);
    return _trackRuntimeOperation(
      _syncPreviewFromSettings(mediaUrl: mediaUrl, httpHeaders: httpHeaders),
      _pendingSynchronizations,
    );
  }

  Future<bool> _syncPreviewFromSettings({
    String? mediaUrl,
    Map<String, String>? httpHeaders,
  }) async {
    if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
      _playbackUrl = mediaUrl.trim();
      _playbackHeaders = httpHeaders;
    }
    final settings = AppSettingsController.instance;
    if (!settings.liveSubtitleEnable.value) {
      stop();
      return true;
    }
    final modelPath = settings.liveSubtitleModelPath.value.trim();
    final modelInfo = await inspectModelPath(modelPath);
    if (modelInfo == null || !modelInfo.isValid) {
      stop();
      statusText.value = modelInfo == null
          ? "字幕模型未识别"
          : "字幕模型缺少：${modelInfo.missingFileNames.join("、")}";
      return false;
    }
    if (engine != null) {
      await _startEngine(
        modelPath: modelInfo.keyFilePath,
        language: settings.liveSubtitleLanguage.value,
      );
      return true;
    }
    if (!isDesktopExperiment) {
      _stopRuntimeOnly();
      running.value = true;
      statusText.value = "当前平台暂不支持播放器音频采集";
      subtitleText.value = "模型已校验，当前平台暂不支持实时采集播放音频";
      return false;
    }
    final url = _playbackUrl;
    if (url == null || url.isEmpty) {
      _stopRuntimeOnly();
      running.value = true;
      statusText.value = "${modelInfo.title} 已就绪";
      subtitleText.value = "模型已校验，等待直播音频输入";
      return true;
    }
    await _startDesktopEngine(
      modelInfo: modelInfo,
      mediaUrl: url,
      httpHeaders: _playbackHeaders,
      language: settings.liveSubtitleLanguage.value,
    );
    return true;
  }

  void startPreview({String language = "auto", bool forceRestart = false}) {
    if (!forceRestart && running.value && subtitleText.value.isNotEmpty) {
      return;
    }
    _engineSubscription?.cancel();
    _previewTimer?.cancel();
    running.value = true;

    final labels = _previewLabels(language);
    var index = 0;
    subtitleText.value = labels[index];
    _previewTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      index = (index + 1) % labels.length;
      subtitleText.value = labels[index];
    });
  }

  Future<void> _startEngine({
    required String modelPath,
    required String language,
  }) async {
    _previewTimer?.cancel();
    _previewTimer = null;
    await _engineSubscription?.cancel();
    final currentEngine = engine!;
    await currentEngine.start(modelPath: modelPath, language: language);
    _engineSubscription = currentEngine.textStream.listen((text) {
      subtitleText.value = text;
      statusText.value = text.trim().isEmpty ? statusText.value : "字幕识别中";
    });
    running.value = true;
  }

  Future<void> _startDesktopEngine({
    required LiveSubtitleModelInfo modelInfo,
    required String mediaUrl,
    required Map<String, String>? httpHeaders,
    required String language,
  }) async {
    _previewTimer?.cancel();
    _previewTimer = null;
    await _engineSubscription?.cancel();
    _engineSubscription = null;

    final desktopKey = [
      modelInfo.type,
      modelInfo.keyFilePath,
      mediaUrl,
      language,
    ].join("\u0001");
    if (running.value &&
        _desktopEngine != null &&
        _activeDesktopKey == desktopKey) {
      return;
    }

    await _desktopSubscription?.cancel();
    _desktopSubscription = null;
    await _desktopEngine?.stop();
    _desktopEngine = null;
    _activeDesktopKey = null;

    running.value = true;
    statusText.value = "正在启动实时字幕";
    subtitleText.value = "实时字幕启动中";
    try {
      await _setStartupGuard(true);
      if (!_sherpaBindingsInitialized) {
        sherpa.initBindings();
        _sherpaBindingsInitialized = true;
      }

      final desktopEngine = _DesktopLiveSubtitleEngine(
        modelInfo: modelInfo,
        mediaUrl: mediaUrl,
        httpHeaders: httpHeaders,
        language: language,
      );
      _desktopEngine = desktopEngine;
      _activeDesktopKey = desktopKey;
      _desktopSubscription = desktopEngine.textStream.listen((text) {
        subtitleText.value = text;
        statusText.value = text.trim().isEmpty ? statusText.value : "字幕识别中";
      });
      await desktopEngine.start();
      await _setStartupGuard(false);
      statusText.value = "实时字幕识别中";
    } catch (e, st) {
      _dbgLog("startup failed: $e\n$st");
      await _setStartupGuard(false);
      AppSettingsController.instance.setLiveSubtitleEnable(false);
      statusText.value = "实时字幕启动失败";
      subtitleText.value = "实时字幕启动失败，已自动关闭：$e";
      await _desktopSubscription?.cancel();
      _desktopSubscription = null;
      await _desktopEngine?.stop();
      _desktopEngine = null;
      _activeDesktopKey = null;
      running.value = false;
    }
  }

  /// Synchronous debug log that flushes immediately to survive native crashes.
  static void _dbgLog(String msg) {
    try {
      final ts = DateTime.now().toIso8601String();
      final line = "[$ts] $msg\n";
      // Write to stderr (visible when launched from console / batch redirect)
      // ignore: avoid_print
      stderr.write(line);
      // Also append synchronously to a file next to the exe
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final f = File("$exeDir\\subtitle_debug.log");
      f.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<void> _setStartupGuard(bool value) async {
    await LocalStorageService.instance.setValue(
      LocalStorageService.kLiveSubtitleStartupGuard,
      value,
    );
  }

  void _stopRuntimeOnly() {
    unawaited(_stopRuntimeOnlyAndWait());
  }

  Future<void> _stopRuntimeOnlyAndWait() {
    return _trackRuntimeOperation(_stopRuntime(), _pendingStops);
  }

  Future<void> _stopRuntime() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    _engineSubscription?.cancel();
    _engineSubscription = null;
    _desktopSubscription?.cancel();
    _desktopSubscription = null;
    final desktopStop = _desktopEngine?.stop();
    _desktopEngine = null;
    _activeDesktopKey = null;
    final mobileStop = engine?.stop();
    await Future.wait<void>([
      if (desktopStop != null) desktopStop,
      if (mobileStop != null) mobileStop,
    ]);
  }

  void stop() {
    _stopRuntimeOnly();
    running.value = false;
    subtitleText.value = "";
    statusText.value = "";
  }

  /// A room handoff must not start a new session while the previous engine's
  /// asynchronous stop can still change the shared subtitle service.
  Future<void> stopAndWait() {
    final active = _roomHandoffStop;
    if (active != null) return active;
    // Publish the barrier before its async body can start another operation.
    final stopping = Future<void>.microtask(_stopForRoomHandoff);
    _roomHandoffStop = stopping;
    return stopping.whenComplete(() {
      if (identical(_roomHandoffStop, stopping)) _roomHandoffStop = null;
    });
  }

  Future<void> _stopForRoomHandoff() async {
    await _waitForRuntimeOperations(_pendingSynchronizations);
    final stopped = _stopRuntimeOnlyAndWait();
    running.value = false;
    subtitleText.value = "";
    statusText.value = "";
    try {
      await stopped;
    } finally {
      // Include stop() calls already issued by settings or earlier syncs, whose
      // engines may have been detached before this final stop.
      await _waitForRuntimeOperations(_pendingStops);
    }
  }

  List<String> _previewLabels(String language) {
    final languageLabel = switch (language) {
      "zh" => "中文",
      "en" => "English",
      "ja" => "日本語",
      "ko" => "한국어",
      _ => "自动语言",
    };
    return [
      "字幕预览：$languageLabel",
      "实时字幕框架已启用",
    ];
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}

class _DesktopLiveSubtitleEngine {
  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2;
  // 正常每轮（200ms）只读到约 0.2s 新音频。积压超过该阈值（0.7s）时，
  // 丢弃最旧的音频、只追最新内容，保证字幕贴近直播、不突发追赶。
  static const int _keepUpBytes = (_sampleRate * _bytesPerSample * 7) ~/ 10;
  // 字幕条最多显示的字符数（始终保留最新内容），约两行，避免省略号吃掉新字幕。
  static const int _maxDisplayChars = 30;
  // 多久没有新识别结果后自动隐藏字幕条（毫秒）。
  static const int _hideAfterMs = 5000;

  final LiveSubtitleModelInfo modelInfo;
  final String mediaUrl;
  final Map<String, String>? httpHeaders;
  final String language;
  final _controller = StreamController<String>.broadcast();

  Player? _decoder;
  Timer? _pollTimer;
  RandomAccessFile? _audioFile;
  File? _pcmFile;
  int _readOffset = 44;
  bool _decoding = false;
  bool _stopped = false;
  sherpa.OfflineRecognizer? _offlineRecognizer;
  sherpa.OnlineRecognizer? _onlineRecognizer;
  sherpa.OnlineStream? _onlineStream;
  sherpa.OfflinePunctuation? _punctuation;
  // 已定稿的历史文本（跨端点累积），当前正在说的半句不包含在内。
  String _finalText = "";
  // 去重与自动隐藏：上一次推送的文本及其更新时间。
  String _lastEmitted = "";
  DateTime _lastChange = DateTime.now();

  _DesktopLiveSubtitleEngine({
    required this.modelInfo,
    required this.mediaUrl,
    required this.httpHeaders,
    required this.language,
  });

  Stream<String> get textStream => _controller.stream;

  Future<void> start() async {
    final tempDir = await getTemporaryDirectory();
    _pcmFile = File(
      p.join(
        tempDir.path,
        "simple_live_subtitle_${DateTime.now().millisecondsSinceEpoch}.wav",
      ),
    );
    if (await _pcmFile!.exists()) {
      await _pcmFile!.delete();
    }

    _createRecognizer();

    _decoder = Player(
      configuration: const PlayerConfiguration(
        title: "Simple Live Subtitle Decoder",
        logLevel: MPVLogLevel.error,
      ),
    );
    final platform = _decoder!.platform;
    if (platform is NativePlayer) {
      await platform.setProperty("vo", "null");
      await platform.setProperty("ao", "pcm");
      await platform.setProperty("ao-pcm-file", _pcmFile!.path);
      await platform.setProperty("audio-samplerate", "$_sampleRate");
      await platform.setProperty("audio-channels", "mono");
      await platform.setProperty("audio-format", "s16");
    }
    await _decoder!.open(
      Media(mediaUrl, httpHeaders: httpHeaders),
      play: true,
    );

    _controller.add("正在采集直播音频");
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      unawaited(_readAndDecode());
    });
  }

  /// 可选标点模型：在 ASR 模型目录下的 `punct/model.onnx`
  /// （sherpa-onnx CT-Transformer 中英标点模型）。存在才加载，缺失不影响识别。
  void _maybeLoadPunctuation(String asrDir) {
    final candidates = [
      p.join(asrDir, "punct", "model.onnx"),
      p.join(asrDir, "punct", "model.int8.onnx"),
      p.join(asrDir, "ct-transformer.onnx"),
    ];
    final punctPath = candidates.firstWhere(
      (path) => File(path).existsSync(),
      orElse: () => "",
    );
    if (punctPath.isEmpty) {
      return;
    }
    try {
      _punctuation = sherpa.OfflinePunctuation(
        config: sherpa.OfflinePunctuationConfig(
          model: sherpa.OfflinePunctuationModelConfig(
            ctTransformer: punctPath,
            numThreads: 1,
            debug: false,
          ),
        ),
      );
    } catch (e) {
      LiveSubtitleService._dbgLog("punctuation model load failed: $e");
      _punctuation = null;
    }
  }

  void _createRecognizer() {
    final dir = modelInfo.directory;
    _maybeLoadPunctuation(dir);
    switch (modelInfo.type) {
      case "paraformer":
        _offlineRecognizer = sherpa.OfflineRecognizer(
          sherpa.OfflineRecognizerConfig(
            feat: const sherpa.FeatureConfig(sampleRate: _sampleRate),
            model: sherpa.OfflineModelConfig(
              paraformer: sherpa.OfflineParaformerModelConfig(
                model: p.join(dir, "model.int8.onnx"),
              ),
              tokens: p.join(dir, "tokens.txt"),
              numThreads: 1,
              debug: false,
              modelType: "paraformer",
            ),
          ),
        );
        break;
      case "whisper":
        _offlineRecognizer = sherpa.OfflineRecognizer(
          sherpa.OfflineRecognizerConfig(
            feat: const sherpa.FeatureConfig(sampleRate: _sampleRate),
            model: sherpa.OfflineModelConfig(
              whisper: sherpa.OfflineWhisperModelConfig(
                encoder: p.join(dir, "large-v3-encoder.int8.onnx"),
                decoder: p.join(dir, "large-v3-decoder.int8.onnx"),
                language: language == "auto" ? "" : language,
                task: "transcribe",
              ),
              tokens: p.join(dir, "large-v3-tokens.txt"),
              numThreads: 1,
              debug: false,
              modelType: "whisper",
            ),
          ),
        );
        break;
      case "zipformer":
        _onlineRecognizer = sherpa.OnlineRecognizer(
          sherpa.OnlineRecognizerConfig(
            feat: const sherpa.FeatureConfig(sampleRate: _sampleRate),
            model: sherpa.OnlineModelConfig(
              transducer: sherpa.OnlineTransducerModelConfig(
                encoder: p.join(dir, "encoder-epoch-99-avg-1.int8.onnx"),
                decoder: p.join(dir, "decoder-epoch-99-avg-1.int8.onnx"),
                joiner: p.join(dir, "joiner-epoch-99-avg-1.int8.onnx"),
              ),
              tokens: p.join(dir, "tokens.txt"),
              numThreads: 2,
              debug: false,
              modelType: "zipformer",
              modelingUnit: "bpe",
              bpeVocab: p.join(dir, "bpe.model"),
            ),
          ),
        );
        _onlineStream = _onlineRecognizer!.createStream();
        break;
      default:
        throw UnsupportedError("暂不支持该字幕模型：${modelInfo.title}");
    }
  }

  Future<void> _readAndDecode() async {
    if (_stopped || _decoding || _pcmFile == null) {
      return;
    }
    _decoding = true;
    try {
      if (!await _pcmFile!.exists()) {
        return;
      }
      _audioFile ??= await _pcmFile!.open(mode: FileMode.read);
      final length = await _audioFile!.length();
      var available = length - _readOffset;
      if (available <= _bytesPerSample) {
        _checkStale();
        return;
      }
      // 同步优先：积压过多说明识别没跟上直播，丢弃最旧音频只保留最新 0.7s，
      // 避免延迟越积越大、再突发解码一大块（这会造成时快时慢和叠字）。
      if (available > _keepUpBytes) {
        final skip = available - _keepUpBytes;
        _readOffset += skip;
        available = _keepUpBytes;
        // 音频出现断层，丢弃当前半句并换全新识别流，避免跨断层重复。
        _recreateOnlineStream();
      }
      await _audioFile!.setPosition(_readOffset);
      final bytes = await _audioFile!.read(available);
      _readOffset += bytes.length;
      final samples = _pcm16ToFloat32(bytes);
      if (samples.isEmpty) {
        _checkStale();
        return;
      }
      if (_onlineRecognizer != null) {
        _feedOnline(samples);
      } else {
        final text = _decodeOffline(samples).trim();
        if (text.isNotEmpty) {
          _pushDisplay(_addPunctuation(text));
        }
      }
      _checkStale();
    } catch (e) {
      LiveSubtitleService._dbgLog("read/decode error: $e");
      _controller.add("字幕识别失败：$e");
    } finally {
      _decoding = false;
    }
  }

  /// 标准 sherpa-onnx 流式识别循环：小批量喂入 -> decode -> 取当前半句 ->
  /// 检测到端点则把该句定稿，并换全新识别流（而非复用 reset），杜绝跨句状态残留。
  void _feedOnline(Float32List samples) {
    final recognizer = _onlineRecognizer;
    var stream = _onlineStream;
    if (recognizer == null || stream == null) {
      return;
    }
    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final current = recognizer.getResult(stream).text.trim();
    if (recognizer.isEndpoint(stream)) {
      if (current.isNotEmpty) {
        _finalizeSegment(current);
      }
      _recreateOnlineStream();
      _pushDisplay("");
    } else {
      _pushDisplay(current);
    }
  }

  void _recreateOnlineStream() {
    final recognizer = _onlineRecognizer;
    if (recognizer == null) {
      return;
    }
    _onlineStream?.free();
    _onlineStream = recognizer.createStream();
  }

  void _finalizeSegment(String segment) {
    final punctuated = _addPunctuation(segment).trim();
    if (punctuated.isNotEmpty) {
      _finalText = (_finalText + punctuated).trim();
    }
  }

  /// 合并已定稿历史与当前半句，始终只保留最新的 [_maxDisplayChars] 个字符。
  void _pushDisplay(String current) {
    final combined = (_finalText + current).trim();
    final display = combined.length > _maxDisplayChars
        ? combined.substring(combined.length - _maxDisplayChars)
        : combined;
    if (display == _lastEmitted) {
      return;
    }
    _lastEmitted = display;
    _lastChange = DateTime.now();
    _controller.add(display);
  }

  /// 长时间没有新结果则清空并隐藏字幕条，给后续字幕留出空间。
  void _checkStale() {
    if (_lastEmitted.isEmpty) {
      return;
    }
    if (DateTime.now().difference(_lastChange).inMilliseconds > _hideAfterMs) {
      _finalText = "";
      _lastEmitted = "";
      _recreateOnlineStream();
      _controller.add("");
    }
  }

  /// 若加载了标点模型则补标点，否则原样返回。
  String _addPunctuation(String text) {
    final punct = _punctuation;
    if (punct == null || text.trim().isEmpty) {
      return text;
    }
    try {
      return punct.addPunct(text);
    } catch (_) {
      return text;
    }
  }

  String _decodeOffline(Float32List samples) {
    final recognizer = _offlineRecognizer;
    if (recognizer == null) {
      return "";
    }
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text;
    } finally {
      stream.free();
    }
  }

  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final data = Float32List(count);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      data[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return data;
  }

  Future<void> stop() async {
    _stopped = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _audioFile?.close();
    _audioFile = null;
    await _decoder?.dispose();
    _decoder = null;
    _offlineRecognizer?.free();
    _offlineRecognizer = null;
    _onlineStream?.free();
    _onlineStream = null;
    _onlineRecognizer?.free();
    _onlineRecognizer = null;
    _punctuation?.free();
    _punctuation = null;
    final file = _pcmFile;
    _pcmFile = null;
    if (file != null && await file.exists()) {
      unawaited(file.delete());
    }
    await _controller.close();
  }
}

class _SubtitleModelCandidate {
  final String type;
  final String title;
  final String recommendedKeyFileName;
  final List<String> requiredFileNames;

  const _SubtitleModelCandidate({
    required this.type,
    required this.title,
    required this.recommendedKeyFileName,
    required this.requiredFileNames,
  });
}
