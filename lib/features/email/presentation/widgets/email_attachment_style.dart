import 'package:flutter/material.dart';

/// Icon + tint used for a file attachment chip, picked by extension so
/// common file types (PDF, docs, spreadsheets, archives, media) are visually
/// distinguishable at a glance rather than all sharing one generic icon.
(IconData, Color) iconForFileExtension(String extension) {
  return switch (extension.toLowerCase()) {
    'pdf' => (Icons.picture_as_pdf, Colors.red),
    'doc' || 'docx' => (Icons.description, Colors.blue),
    'xls' || 'xlsx' || 'csv' => (Icons.table_chart, Colors.green),
    'ppt' || 'pptx' => (Icons.slideshow, Colors.orange),
    'zip' || 'rar' || '7z' => (Icons.folder_zip, Colors.brown),
    'mp3' || 'wav' || 'm4a' => (Icons.audiotrack, Colors.purple),
    'mp4' || 'mov' || 'avi' || 'mkv' => (Icons.videocam, Colors.deepPurple),
    _ => (Icons.insert_drive_file, Colors.blueGrey),
  };
}

bool isImageFileExtension(String extension) =>
    const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(extension.toLowerCase());

String readableFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
