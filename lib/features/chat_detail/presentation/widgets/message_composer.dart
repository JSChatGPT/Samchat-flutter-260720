import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.enabled,
    required this.onSend,
    required this.onChanged,
    required this.onVoiceNote,
    this.onAttach,
    this.onSendPayment,
    this.replyPreview,
    this.onCancelReply,
  });

  final bool enabled;
  final void Function(String text) onSend;
  final void Function(String text) onChanged;
  final void Function(String path, Duration duration) onVoiceNote;
  final VoidCallback? onAttach;
  final VoidCallback? onSendPayment;
  final Widget? replyPreview;
  final VoidCallback? onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  bool _hasText = false;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void dispose() {
    _controller.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${const Uuid().v4()}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    final path = await _recorder.stop();
    _recordTimer?.cancel();
    final duration = _recordDuration;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
    if (send && path != null) {
      widget.onVoiceNote(path, duration);
    } else if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!widget.enabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Text(
          'You can\'t reply to this conversation',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyPreview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: widget.replyPreview,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: _isRecording ? _buildRecordingRow(scheme) : _buildTextRow(scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingRow(ColorScheme scheme) {
    final minutes = _recordDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (_recordDuration.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: scheme.error),
          onPressed: () => _stopRecording(send: false),
        ),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$minutes:$seconds'),
        const Spacer(),
        const Text('Recording…'),
        const Spacer(),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded),
          onPressed: () => _stopRecording(send: true),
        ),
      ],
    );
  }

  Widget _buildTextRow(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: widget.onAttach,
          color: scheme.primary,
        ),
        if (widget.onSendPayment != null)
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            tooltip: 'Send payment',
            onPressed: widget.onSendPayment,
            color: scheme.primary,
          ),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Message'),
              onChanged: (v) {
                widget.onChanged(v);
                setState(() => _hasText = v.trim().isNotEmpty);
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        _hasText
            ? IconButton.filled(icon: const Icon(Icons.send_rounded), onPressed: _submit)
            : IconButton.filled(
                icon: const Icon(Icons.mic_rounded),
                onPressed: _startRecording,
              ),
      ],
    );
  }
}
