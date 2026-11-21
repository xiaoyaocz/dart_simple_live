import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  final String picUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;
  final bool resizeToWidth;
  const NetImage(this.picUrl,
      {this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.borderRadius = 0,
      this.resizeToWidth = false,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (picUrl.isEmpty) {
      return Image.asset(
        'assets/images/logo.png',
        width: width,
        height: height,
      );
    }
    var pic = picUrl;
    if (pic.startsWith("//")) {
      pic = 'https:$pic';
    }
    if (resizeToWidth) {
      return LayoutBuilder(builder: (context, constraints) {
        final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
        final logicalWidth = width != null && width!.isFinite
            ? constraints.constrainWidth(width!)
            : constraints.maxWidth;
        final cacheWidth = logicalWidth.isFinite && logicalWidth > 0
            ? (logicalWidth * ratio).ceil().clamp(1, 1024).toInt()
            : null;
        return _buildImage(pic, cacheWidth: cacheWidth);
      });
    }
    return _buildImage(pic);
  }

  Widget _buildImage(String url, {int? cacheWidth}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ExtendedImage.network(
        url,
        fit: fit,
        height: height,
        width: width,
        cacheWidth: cacheWidth,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(borderRadius),
        loadStateChanged: (e) {
          if (e.extendedImageLoadState == LoadState.loading) {
            return const Icon(
              Icons.image,
              color: Colors.grey,
              size: 24,
            );
          }
          if (e.extendedImageLoadState == LoadState.failed) {
            return const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 24,
            );
          }
          return null;
        },
      ),
    );
  }
}
