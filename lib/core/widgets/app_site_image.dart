import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppSiteImage extends StatelessWidget {
  const AppSiteImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackAssetPath = 'assets/images/algeria_landing.png',
    this.fallback,
  });

  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String fallbackAssetPath;
  final Widget? fallback;

  bool get _isNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        placeholder: (BuildContext context, String url) =>
            _buildPlaceholder(context),
        errorWidget: (BuildContext context, String url, Object error) =>
            _buildFallback(),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              _buildFallback(),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }

  Widget _buildFallback() {
    return fallback ??
        Image.asset(fallbackAssetPath, width: width, height: height, fit: fit);
  }
}
