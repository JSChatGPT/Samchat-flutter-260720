import 'dart:convert';

import 'package:dio/dio.dart';

/// Shared multipart request builder — used by every feature that uploads a
/// file (chat attachments, voice notes, profile photo, group image, status
/// media) so upload-progress reporting and field/file assembly stay
/// consistent instead of being re-implemented per feature.
class MultipartHelper {
  MultipartHelper._();

  static Future<FormData> build({
    Map<String, dynamic> fields = const {},
    Map<String, String> files = const {}, // fieldName -> filePath
    Map<String, List<String>> multiFiles = const {}, // fieldName -> filePaths (repeated field, e.g. multiple attachments)
  }) async {
    final map = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is Map || value is List) {
        map[key] = jsonEncode(value);
      } else {
        map[key] = value.toString();
      }
    });
    for (final entry in files.entries) {
      map[entry.key] = await MultipartFile.fromFile(entry.value);
    }
    for (final entry in multiFiles.entries) {
      map[entry.key] = [
        for (final path in entry.value) await MultipartFile.fromFile(path),
      ];
    }
    return FormData.fromMap(map);
  }
}
