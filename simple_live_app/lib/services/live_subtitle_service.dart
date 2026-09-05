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
  static const bool kFeatureEnabled = false;

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
    } catch (e) {
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

  Future<void> _setStartupGuard(bool value) async {
    await LocalStorageService.instance.setValue(
      LocalStorageService.kLiveSubtitleStartupGuard,
      value,
    );
  }

  void _stopRuntimeOnly() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _engineSubscription?.cancel();
    _engineSubscription = null;
    _desktopSubscription?.cancel();
    _desktopSubscription = null;
    unawaited(_desktopEngine?.stop());
    _desktopEngine = null;
    _activeDesktopKey = null;
    unawaited(engine?.stop());
  }

  void stop() {
    _stopRuntimeOnly();
    running.value = false;
    subtitleText.value = "";
    statusText.value = "";
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
  static const int _chunkSeconds = 4;
  static const int _chunkBytes = _sampleRate * _bytesPerSample * _chunkSeconds;

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
  String _lastText = "";

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
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      unawaited(_readAndDecode());
    });
  }

  void _createRecognizer() {
    final dir = modelInfo.directory;
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
              numThreads: 1,
              debug: false,
              modelType: "zipformer2",
              modelingUnit: "bpe",
              bpeVocab: p.join(dir, "bpe.vocab"),
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
      if (length <= _readOffset + _chunkBytes) {
        return;
      }
      final available = length - _readOffset;
      final readBytes = available > _chunkBytes ? _chunkBytes : available;
      await _audioFile!.setPosition(_readOffset);
      final bytes = await _audioFile!.read(readBytes);
      _readOffset += bytes.length;
      final samples = _pcm16ToFloat32(bytes);
      if (samples.isEmpty) {
        return;
      }
      final text = _decodeSamples(samples).trim();
      if (text.isNotEmpty && text != _lastText) {
        _lastText = text;
        _controller.add(text);
      }
    } catch (e) {
      _controller.add("字幕识别失败：$e");
    } finally {
      _decoding = false;
    }
  }

  String _decodeSamples(Float32List samples) {
    final onlineRecognizer = _onlineRecognizer;
    final onlineStream = _onlineStream;
    if (onlineRecognizer != null && onlineStream != null) {
      onlineStream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      while (onlineRecognizer.isReady(onlineStream)) {
        onlineRecognizer.decode(onlineStream);
      }
      final result = onlineRecognizer.getResult(onlineStream).text;
      if (onlineRecognizer.isEndpoint(onlineStream)) {
        onlineRecognizer.reset(onlineStream);
      }
      return result;
    }

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
