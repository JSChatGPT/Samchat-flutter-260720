import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;

import '../../../../models/message.dart';

class AttachmentPickResult {
  const AttachmentPickResult({required this.path, required this.type, this.fileName});

  final String path;
  final MessageType type;
  final String? fileName;
}

Future<AttachmentPickResult?> showAttachmentPickerSheet(BuildContext context) async {
  return showModalBottomSheet<AttachmentPickResult>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
              if (ctx.mounted) {
                Navigator.pop(
                  ctx,
                  file != null ? AttachmentPickResult(path: file.path, type: MessageType.image) : null,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: const Text('Photo'),
            onTap: () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (ctx.mounted) {
                Navigator.pop(
                  ctx,
                  file != null ? AttachmentPickResult(path: file.path, type: MessageType.image) : null,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Video'),
            onTap: () async {
              final picker = ImagePicker();
              final file = await picker.pickVideo(source: ImageSource.gallery);
              if (ctx.mounted) {
                Navigator.pop(
                  ctx,
                  file != null ? AttachmentPickResult(path: file.path, type: MessageType.video) : null,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: const Text('Document'),
            onTap: () async {
              final result = await fp.FilePicker.platform.pickFiles();
              final file = result?.files.single;
              if (ctx.mounted) {
                Navigator.pop(
                  ctx,
                  (file != null && file.path != null)
                      ? AttachmentPickResult(path: file.path!, type: MessageType.file, fileName: file.name)
                      : null,
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
