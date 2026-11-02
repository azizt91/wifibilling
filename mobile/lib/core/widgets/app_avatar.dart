import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarContent = _buildContent();

    if (onTap != null) {
      avatarContent = GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarContent,
    );
  }

  Widget _buildContent() {
    final url = photoUrl?.trim();

    // 1. Check if empty or null
    if (url == null || url.isEmpty) {
      return _buildFallback();
    }

    // 2. Check if it's the system default SVG avatar
    if (url.contains('avatar_male') || url.contains('avatar_female') || url.contains('default_avatar')) {
      final assetPath = url.contains('avatar_female')
          ? 'assets/images/avatar_female.svg'
          : 'assets/images/avatar_male.svg';
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    // 3. Check if base64 data URI
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }

    // 4. Check if standard HTTP/HTTPS URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          );
        },
      );
    }

    // 5. Check if local asset
    if (url.startsWith('assets/')) {
      if (url.endsWith('.svg')) {
        final normalized = url.startsWith('assets/images/') ? url : url.replaceFirst('assets/', 'assets/images/');
        return SvgPicture.asset(
          normalized,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } else {
        return Image.asset(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      }
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return SvgPicture.asset(
      'assets/images/avatar_male.svg',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

