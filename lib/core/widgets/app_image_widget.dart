import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

class AppImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String placeholderAsset;

  const AppImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderAsset = 'assets/images/placeholder.png',
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    final trimmed = imageUrl.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      int? cacheWidth;
      if (width != null && width!.isFinite && width! > 0) {
        cacheWidth = (width! * 2).toInt();
      }

      imageWidget = CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
        ),
        errorWidget: (context, url, error) => _buildFallbackWidget(),
      );
    } else if (trimmed.isNotEmpty) {
      imageWidget = Image.asset(
        trimmed,
        width: width,
        height: height,
        fit: fit,
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
