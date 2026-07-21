import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/email_account.dart';
import '../../application/email_notifier.dart';
import '../widgets/email_attachment_style.dart';

/// Handles compose, reply, and reply-all — when [replyToEmailId] is set,
/// [to]/[subject] are pre-filled read-only, [replyAll] pre-selects the
/// "Reply all" toggle, and sending calls the reply endpoint (which threads
/// off the original message) instead of a raw send.
class ComposeEmailScreen extends ConsumerStatefulWidget {
  const ComposeEmailScreen({
    super.key,
    required this.account,
    this.replyToEmailId,
    this.initialTo,
    this.initialSubject,
    this.replyAll = false,
    this.hasOtherRecipients = false,
  });

  final EmailAccount account;
  final String? replyToEmailId;
  final String? initialTo;
  final String? initialSubject;
  final bool replyAll;

  /// Whether the original message had other To/Cc recipients besides the
  /// sender — controls whether "Reply all" is even offered as an option.
  final bool hasOtherRecipients;

  @override
  ConsumerState<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends ConsumerState<ComposeEmailScreen> {
  late final _toController = TextEditingController(text: widget.initialTo ?? '');
  late final _subjectController = TextEditingController(text: widget.initialSubject ?? '');
  final _ccController = TextEditingController();
  final _bodyController = TextEditingController();
  final _attachments = <fp.PlatformFile>[];
  bool _ccVisible = false;
  late bool _replyAll = widget.replyAll;
  bool _sending = false;
  double? _uploadProgress;

  bool get _isReply => widget.replyToEmailId != null;

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _ccController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await fp.FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path != null) _attachments.add(file);
      }
    });
  }

  void _removeAttachment(fp.PlatformFile file) {
    setState(() => _attachments.remove(file));
  }

  Future<void> _send() async {
    if (_bodyController.text.trim().isEmpty) return;
    if (!_isReply && (_toController.text.trim().isEmpty || _subjectController.text.trim().isEmpty)) return;
    setState(() {
      _sending = true;
      _uploadProgress = null;
    });
    final paths = _attachments.map((f) => f.path!).toList();
    try {
      if (_isReply) {
        await ref.read(emailRepositoryProvider).replyToEmail(
              widget.replyToEmailId!,
              body: _bodyController.text.trim(),
              replyAll: _replyAll,
              cc: _ccController.text.trim(),
              attachmentPaths: paths,
              onSendProgress: (sent, total) {
                if (total > 0 && mounted) setState(() => _uploadProgress = sent / total);
              },
            );
      } else {
        await ref.read(emailRepositoryProvider).sendEmail(
              widget.account.id,
              to: _toController.text.trim(),
              cc: _ccController.text.trim(),
              subject: _subjectController.text.trim(),
              body: _bodyController.text.trim(),
              attachmentPaths: paths,
              onSendProgress: (sent, total) {
                if (total > 0 && mounted) setState(() => _uploadProgress = sent / total);
              },
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildAttachmentChip(fp.PlatformFile file) {
    final extension = file.extension ?? '';
    final scheme = Theme.of(context).colorScheme;

    Widget leading;
    if (isImageFileExtension(extension) && file.path != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(file.path!), width: 40, height: 40, fit: BoxFit.cover),
      );
    } else {
      final (icon, color) = iconForFileExtension(extension);
      leading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 22),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(readableFileSize(file.size), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _sending ? null : () => _removeAttachment(file),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending &&
        _bodyController.text.trim().isNotEmpty &&
        (_isReply || (_toController.text.trim().isNotEmpty && _subjectController.text.trim().isNotEmpty));
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReply ? (_replyAll ? 'Reply all' : 'Reply') : 'New email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: 'Attach files',
            onPressed: _sending ? null : _pickAttachments,
          ),
          IconButton(
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            onPressed: canSend ? _send : null,
          ),
        ],
        bottom: _sending && _uploadProgress != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _uploadProgress, minHeight: 3),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('From: ${widget.account.emailAddress}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_isReply && widget.hasOtherRecipients) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Reply')),
                ButtonSegment(value: true, label: Text('Reply all')),
              ],
              selected: {_replyAll},
              onSelectionChanged: (s) => setState(() => _replyAll = s.first),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _toController,
                  enabled: !_isReply,
                  decoration: const InputDecoration(labelText: 'To', helperText: 'Separate multiple addresses with commas'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (!_ccVisible)
                TextButton(onPressed: () => setState(() => _ccVisible = true), child: const Text('Cc')),
            ],
          ),
          if (_ccVisible) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ccController,
              decoration: const InputDecoration(labelText: 'Cc', helperText: 'Separate multiple addresses with commas'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            enabled: !_isReply,
            decoration: const InputDecoration(labelText: 'Subject'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            maxLines: 12,
            minLines: 6,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _sending ? null : _pickAttachments,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_attachments.isEmpty)
            Text('No files attached', style: Theme.of(context).textTheme.bodySmall)
          else
            Wrap(spacing: 10, runSpacing: 10, children: [for (final file in _attachments) _buildAttachmentChip(file)]),
        ],
      ),
    );
  }
}
