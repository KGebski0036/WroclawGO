import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NetworkItemImage extends StatelessWidget {
  const NetworkItemImage({
    required this.url,
    this.fit = BoxFit.contain,
    this.loadingSize = 18,
    this.fallback,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final double loadingSize;
  final Widget? fallback;

  bool get _isSvg {
    final lower = url.toLowerCase();
    return lower.endsWith('.svg') || lower.contains('.svg?');
  }

  Widget _defaultFallback() {
    return const Center(child: Icon(Icons.broken_image_outlined));
  }

  @override
  Widget build(BuildContext context) {
    final fallbackWidget = fallback ?? _defaultFallback();

    if (_isSvg) {
      return SvgPicture.network(
        url,
        fit: fit,
        placeholderBuilder: (context) => Center(
          child: SizedBox(
            width: loadingSize,
            height: loadingSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Center(
          child: SizedBox(
            width: loadingSize,
            height: loadingSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => fallbackWidget,
    );
  }
}
