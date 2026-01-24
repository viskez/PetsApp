import 'dart:io';

import 'package:flutter/material.dart';

import '../models/pet_utils.dart';

class PetImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PetImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage();
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return SizedBox(
      width: width,
      height: height,
      child: image,
    );
  }

  Widget _buildImage() {
    final src = source.isEmpty ? kPetPlaceholderImage : source;

    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    final file = File(src);
    if (file.isAbsolute && file.existsSync()) {
      return Image.file(file, fit: fit, errorBuilder: (_, __, ___) => _placeholder());
    }

    return Image.asset(src, fit: fit, errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Image.asset(kPetPlaceholderImage, fit: fit);
}
