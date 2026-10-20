import 'package:flutter/material.dart';

Widget optimizedNetworkImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  int cacheWidth = 300,
  int cacheHeight = 300,
  BorderRadius? borderRadius,
}) {
  Widget imageWidget = Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    cacheWidth: cacheWidth,   // تقليل حجم فك الضغط في الذاكرة (مشابه لـ Next/Image)
    cacheHeight: cacheHeight, // منع استهلاك الذاكرة وسرعة استجابة فائقة
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        width: width,
        height: height,
        color: Colors.grey.withOpacity(0.08),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) => Container(
      width: width,
      height: height,
      color: Colors.grey.withOpacity(0.08),
      child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 20),
    ),
  );

  if (borderRadius != null) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: imageWidget,
    );
  }
  return imageWidget;
}