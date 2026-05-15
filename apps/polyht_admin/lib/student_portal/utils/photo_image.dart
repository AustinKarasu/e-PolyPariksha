import 'dart:convert';

import 'package:flutter/material.dart';

ImageProvider? profileImageProvider(String? value, String apiBaseUrl) {
  final photo = value?.trim();
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('data:image/')) {
    final comma = photo.indexOf(',');
    if (comma <= 0) return null;
    try {
      return MemoryImage(base64Decode(photo.substring(comma + 1)));
    } on FormatException {
      return null;
    }
  }
  if (photo.startsWith('http://') || photo.startsWith('https://')) return NetworkImage(photo);
  final base = apiBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  final path = photo.startsWith('/') ? photo : '/$photo';
  return NetworkImage('$base$path');
}
