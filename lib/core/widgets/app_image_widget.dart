import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';

/// Performance-optimized Image widget with hardware-accelerated caching and memory downscaling.
/// Prevents main thread UI decode lag (jank) by applying memCacheWidth and memCacheHeight.
class AppImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;
  final String placeholderAsset;

  const AppImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
    this.placeholderAsset = 'assets/images/placeholder.png',
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final trimmed = imageUrl.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Scale resolution according to device pixel ratio to prevent decoding massive 4K images in memory
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
      final int calculatedMemWidth = memCacheWidth ??
          (width != null && width!.isFinite && width! > 0
              ? (width! * dpr).toInt().clamp(64, 1080)
              : 800);
      final int? calculatedMemHeight = memCacheHeight ??
          (height != null && height!.isFinite && height! > 0
              ? (height! * dpr).toInt().clamp(64, 1080)
              : null);

      imageWidget = CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: calculatedMemWidth,
        memCacheHeight: calculatedMemHeight,
        maxHeightDiskCache: 1200,
        maxWidthDiskCache: 1200,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
        ),
        errorWidget: (context, url, error) => _buildFallbackWidget(),
      );
    } else if (trimmed.isNotEmpty) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
      final int? calculatedMemWidth = memCacheWidth ??
          (width != null && width!.isFinite && width! > 0
              ? (width! * dpr).toInt().clamp(64, 1080)
              : null);
      final int? calculatedMemHeight = memCacheHeight ??
          (height != null && height!.isFinite && height! > 0
              ? (height! * dpr).toInt().clamp(64, 1080)
              : null);

      imageWidget = Image.asset(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: calculatedMemWidth,
        cacheHeight: calculatedMemHeight,
        errorBuilder: (context, error, stackTrace) => _buildFallbackWidget(),
      );
    } else {
      imageWidget = _buildFallbackWidget();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallbackWidget() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      child: Center(
        child: Icon(
          Icons.event_outlined,
          color: AppColors.textMuted,
          size: (height != null && height! < 50) ? 20 : 32,
        ),
      ),
    );
  }
}
