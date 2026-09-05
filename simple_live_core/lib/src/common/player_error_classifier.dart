class PlayerErrorClassifier {
  const PlayerErrorClassifier._();

  static bool isRecoverableAudioDiagnostic(String error) {
    final normalized = error.trim().toLowerCase();
    return normalized.contains('error decoding audio.') ||
        normalized.contains('no sound.');
  }
}
