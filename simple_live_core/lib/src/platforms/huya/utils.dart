int rotl64(int t) {
  final low = t & 0xFFFFFFFF;
  final rotatedLow =
  ((low << 8) | (low >> 24)) & 0xFFFFFFFF;
  final high = t & ~0xFFFFFFFF;
  return high | rotatedLow;
}