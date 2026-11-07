import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider? getAvatarImageProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.trim().isEmpty) return null;
  final trimmed = photoUrl.trim();

  if (trimmed.startsWith('data:image')) {
    try {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex != -1) {
        final base64Str = trimmed.substring(commaIndex + 1);
        final bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      }
    } catch (_) {
      return null;
    }
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }

  return null;
}
