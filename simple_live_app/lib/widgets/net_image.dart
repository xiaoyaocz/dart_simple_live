import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  static const liveCoverCacheName = 'simple_live_live_covers';

  final String picUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool clearMemoryCacheWhenDispose;
  final String? imageCacheName;
  final Duration? cacheMaxAge;
  final bool cache;
  const NetImage(this.picUrl,
      {this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.borderRadius = 0,
      this.cacheWidth,
      this.cacheHeight,
      this.clearMemoryCacheWhenDispose = false,
      this.imageCacheName,
      this.cacheMaxAge,
      this.cache = true,
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
    if (pic.startsWith("asset://")) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          pic.substring("asset://".length),
          fit: fit,
          height: height,
          width: width,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ExtendedImage.network(
        pic,
        fit: fit,
        height: height,
        width: width,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(borderRadius),
        cache: cache,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
        imageCacheName: imageCacheName,
        cacheMaxAge: cacheMaxAge,
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
