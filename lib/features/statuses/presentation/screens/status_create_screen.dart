import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../models/status.dart';
import '../../application/statuses_notifier.dart';

const _kStatusColors = [
  Color(0xFFFF6A1A),
  Color(0xFF2A9D8F),
  Color(0xFF264653),
  Color(0xFFE76F51),
  Color(0xFF6A4C93),
  Color(0xFF1D3557),
];

class StatusCreateScreen extends ConsumerStatefulWidget {
  const StatusCreateScreen({super.key});

  @override
  ConsumerState<StatusCreateScreen> createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends ConsumerState<StatusCreateScreen> {
  final _textController = TextEditingController();
  Color _bgColor = _kStatusColors.first;
  XFile? _mediaFile;
  bool _isVideo = false;
  bool _posting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool video, required ImageSource source}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    setState(() {
      _mediaFile = file;
      _isVideo = video;
    });
  }

  Future<void> _post() async {
    setState(() => _posting = true);
    try {
      if (_mediaFile != null) {
        await ref.read(statusesRepositoryProvider).createStatus(
              type: _isVideo ? StatusType.video : StatusType.image,
              content: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
              mediaPath: _mediaFile!.path,
            );
      } else {
        final text = _textController.text.trim();
        if (text.isEmpty) return;
        await ref.read(statusesRepositoryProvider).createStatus(
              type: StatusType.text,
              content: text,
              backgroundColor: '#${_bgColor.toARGB32().toRadixString(16).substring(2)}',
            );
      }
      if (!mounted) return;
      ref.read(statusesNotifierProvider.notifier).refresh();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post status: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mediaFile == null ? _bgColor : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('New status'),
        actions: [
          if (_mediaFile == null) ...[
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _pickMedia(video: false, source: ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo_outlined),
              onPressed: () => _pickMedia(video: false, source: ImageSource.gallery),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => _pickMedia(video: true, source: ImageSource.gallery),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _mediaFile != null
                  ? Center(
                      child: _isVideo
                          ? const Icon(Icons.videocam, color: Colors.white54, size: 64)
                          : Image.file(File(_mediaFile!.path), fit: BoxFit.contain),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: TextField(
                          controller: _textController,
                          maxLines: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Type a status',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ),
            ),
            if (_mediaFile == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _kStatusColors.map((c) {
                    final selected = c == _bgColor;
                    return GestureDetector(
                      onTap: () => setState(() => _bgColor = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: selected ? 32 : 26,
                        height: selected ? 32 : 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a caption',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _posting ? null : _post,
                  icon: _posting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Post status'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
