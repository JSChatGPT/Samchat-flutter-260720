import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Curated "sticker" tray — no sticker art pipeline exists, so this ships as
/// large single emoji sent instantly (mirrors WhatsApp's own oversized-emoji
/// rendering for a lone-emoji message). Kept identical to the picker used by
/// the web client for visual parity across platforms.
const kStickerEmojis = [
  '🎉', '❤️', '😂', '😍', '😢', '😮', '🙏', '🔥',
  '👍', '👏', '🥳', '😎', '🤔', '😴', '🤗', '😇',
  '🥰', '😜', '🤯', '💯', '✨', '🎂', '🌈', '☕',
];

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.enabled,
    required this.onSend,
    required this.onChanged,
    required this.onVoiceNote,
    required this.onSendSticker,
    this.onAttach,
    this.onSendPayment,
    this.replyPreview,
    this.onCancelReply,
  });

  final bool enabled;
  final void Function(String text) onSend;
  final void Function(String text) onChanged;
  final void Function(String path, Duration duration) onVoiceNote;
  final void Function(String emoji) onSendSticker;
  final VoidCallback? onAttach;
  final VoidCallback? onSendPayment;
  final Widget? replyPreview;
  final VoidCallback? onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  late final TabController _pickerTabController;
  bool _hasText = false;
  bool _isRecording = false;
  bool _showPicker = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _pickerTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pickerTabController.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _togglePicker() {
    FocusScope.of(context).unfocus();
    setState(() => _showPicker = !_showPicker);
  }

  void _sendSticker(String emoji) {
    widget.onSendSticker(emoji);
    setState(() => _showPicker = false);
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
            if (_showPicker) _buildPicker(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(ColorScheme scheme) {
    return SizedBox(
      height: 280,
      child: Column(
        children: [
          TabBar(
            controller: _pickerTabController,
            tabs: const [
              Tab(icon: Icon(Icons.emoji_emotions_outlined), text: 'Emoji'),
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Stickers'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _pickerTabController,
              children: [
                EmojiPicker(
                  textEditingController: _controller,
                  onEmojiSelected: (category, emoji) =>
                      setState(() => _hasText = _controller.text.trim().isNotEmpty),
                  config: const Config(height: 230),
                ),
                _buildStickerGrid(scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(ColorScheme scheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
      itemCount: kStickerEmojis.length,
      itemBuilder: (context, index) {
        final emoji = kStickerEmojis[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _sendSticker(emoji),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
        );
      },
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
              decoration: InputDecoration(
                hintText: 'Message',
                prefixIcon: IconButton(
                  icon: Icon(
                    _showPicker ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: _togglePicker,
                ),
              ),
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
