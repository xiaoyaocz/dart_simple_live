import 'dart:math' as math;

class IosVideoOutputSize {
  final int width;
  final int height;

  const IosVideoOutputSize(this.width, this.height);

  @override
  bool operator ==(Object other) {
    return other is IosVideoOutputSize &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}

IosVideoOutputSize? calculateIosVideoOutputSize({
  required int sourceWidth,
  required int sourceHeight,
  required double screenPhysicalWidth,
  required double screenPhysicalHeight,
}) {
  if (sourceWidth < 2 ||
      sourceHeight < 2 ||
      !screenPhysicalWidth.isFinite ||
      !screenPhysicalHeight.isFinite ||
      screenPhysicalWidth < 2 ||
      screenPhysicalHeight < 2) {
    return null;
  }

  final scale = math.min(
    1.0,
    math.min(
      screenPhysicalWidth / sourceWidth,
      screenPhysicalHeight / sourceHeight,
    ),
  );

  int toEvenDimension(double value) {
    final roundedDown = value.floor();
    if (roundedDown <= 2) {
      return 2;
    }
    return roundedDown.isEven ? roundedDown : roundedDown - 1;
  }

  return IosVideoOutputSize(
    toEvenDimension(sourceWidth * scale),
    toEvenDimension(sourceHeight * scale),
  );
}
