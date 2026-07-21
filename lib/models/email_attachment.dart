import '../core/utils/json_utils.dart';

class EmailAttachment {
  const EmailAttachment({
    required this.id,
    required this.fileName,
    required this.url,
    this.mimeType,
    required this.sizeBytes,
  });

  final String id;
  final String fileName;
  final String url;
  final String? mimeType;
  final int sizeBytes;

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  bool get isImage => mimeType?.startsWith('image/') ?? const ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension);

  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      id: asString(json['id']),
      fileName: asString(json['file_name']),
      url: asString(json['url']),
      mimeType: asStringOrNull(json['mime_type']),
      sizeBytes: asInt(json['size_bytes']),
    );
  }
}
