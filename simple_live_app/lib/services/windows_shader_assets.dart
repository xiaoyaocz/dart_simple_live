import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Resolves desktop GLSL shader assets for Windows mpv playback.
class WindowsShaderAssets {
  static const String fsrcnnxAsset = 'assets/shaders/FSRCNNX_x2_8-0-4-1.glsl';
  static const String _fsrcnnxFileName = 'FSRCNNX_x2_8-0-4-1.glsl';

  @visibleForTesting
  static String? Function()? testOverrideResolver;

  static Future<String?> resolveFsrcnnxPath() async {
    final override = testOverrideResolver;
    if (override != null) {
      return override();
    }
    if (!Platform.isWindows) {
      return null;
    }

    final bundledPath = path.join(
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      'assets',
      'shaders',
      _fsrcnnxFileName,
    );
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }

    try {
      final data = await rootBundle.load(fsrcnnxAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final supportDir = await getApplicationSupportDirectory();
      final outFile = File(path.join(supportDir.path, 'shaders', _fsrcnnxFileName));
      if (!outFile.existsSync() || outFile.lengthSync() != bytes.length) {
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(bytes, flush: true);
      }
      return outFile.path;
    } catch (_) {
      return null;
    }
  }
}
