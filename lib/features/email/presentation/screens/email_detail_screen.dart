import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../models/email_account.dart';
import '../../../../models/email_attachment.dart';
import '../../../../models/email_message.dart';
import '../../application/email_notifier.dart';
import '../widgets/email_attachment_style.dart';
import 'compose_email_screen.dart';

/// Extracts bare addresses from a `"Display Name" <a@b.com>, ...` string,
/// mirroring the backend's reply-all parsing (real display names can
/// legitimately contain commas, so a naive split-on-comma isn't safe).
Set<String> _extractAddresses(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  return RegExp(r'[^\s<>",]+@[^\s<>",]+\.[^\s<>",]+')
      .allMatches(raw)
      .map((m) => m.group(0)!.toLowerCase())
      .toSet();
}

class EmailDetailScreen extends ConsumerStatefulWidget {
  const EmailDetailScreen({super.key, required this.account, required this.emailId});

  final EmailAccount account;
  final String emailId;

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  EmailMessage? _email;
  String? _error;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // GET /emails/{id} also marks it read server-side.
      final email = await ref.read(emailRepositoryProvider).getEmail(widget.emailId);
      if (!mounted) return;
      setState(() {
        _email = email;
        final html = email.bodyHtml;
        // Prefer the HTML body when the mailbox provided one — every synced
        // message has one, but the screen used to only ever show bodyText,
        // which is blank for a real chunk of mail (no plain-text part at
        // all), rendering as a bare "(no content)" — looking like the email
        // never opened. Plain text is still the fallback below when there's
        // truly no HTML part.
        if (html != null && html.trim().isNotEmpty) {
          _webViewController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.disabled)
            ..loadHtmlString(_wrapHtml(html));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Sender HTML usually assumes a desktop-width viewport and doesn't set
  /// its own viewport meta tag — without this the webview renders it
  /// zoomed out and tiny. Also caps images to the available width so a
  /// wide inline image doesn't force horizontal scrolling.
  String _wrapHtml(String bodyHtml) {
    return '''
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: -apple-system, Roboto, sans-serif; font-size: 16px; line-height: 1.4; padding: 16px; margin: 0; word-wrap: break-word; }
  img { max-width: 100%; height: auto; }
</style>
</head>
<body>$bodyHtml</body>
</html>
''';
  }

  bool _hasOtherRecipients(EmailMessage email) {
    final others = _extractAddresses('${email.toAddress ?? ''} ${email.ccAddress ?? ''}')
      ..remove(widget.account.emailAddress.toLowerCase())
      ..remove((email.fromAddress ?? '').toLowerCase());
    return others.isNotEmpty;
  }

  void _openReply(EmailMessage email, {required bool replyAll}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposeEmailScreen(
          account: widget.account,
          replyToEmailId: email.id,
          initialTo: email.fromAddress,
          initialSubject: email.subject,
          replyAll: replyAll,
          hasOtherRecipients: _hasOtherRecipients(email),
        ),
      ),
    );
  }

  Future<void> _openAttachment(EmailAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${attachment.fileName}')));
      }
    }
  }

  Widget _buildAttachmentChip(EmailAttachment attachment) {
    final scheme = Theme.of(context).colorScheme;
    Widget leading;
    if (attachment.isImage) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      final (icon, color) = iconForFileExtension(attachment.extension);
      leading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 22),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openAttachment(attachment),
      child: Container(
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
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(readableFileSize(attachment.sizeBytes), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.download_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email'),
        actions: [
          if (email != null && !email.isOutgoing) ...[
            if (_hasOtherRecipients(email))
              PopupMenuButton<bool>(
                icon: const Icon(Icons.reply),
                tooltip: 'Reply',
                onSelected: (replyAll) => _openReply(email, replyAll: replyAll),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: false, child: Text('Reply')),
                  PopupMenuItem(value: true, child: Text('Reply all')),
                ],
              )
            else
              IconButton(
                icon: const Icon(Icons.reply),
                tooltip: 'Reply',
                onPressed: () => _openReply(email, replyAll: false),
              ),
          ],
        ],
      ),
      // The header (subject/sender/recipients/attachments) is a plain
      // non-scrolling Column and the body takes the rest via Expanded —
      // a WebViewWidget can't live inside a ListView (it doesn't participate
      // in Flutter's scroll/sizing protocol the way a Text widget does), so
      // it needs to own a bounded region and scroll its own content instead.
      body: email == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email.subject, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '${email.senderDisplay}${email.fromAddress != null ? ' <${email.fromAddress}>' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (email.toAddress != null)
                        Text('To: ${email.toAddress}', style: Theme.of(context).textTheme.bodySmall),
                      if (email.ccAddress != null && email.ccAddress!.isNotEmpty)
                        Text('Cc: ${email.ccAddress}', style: Theme.of(context).textTheme.bodySmall),
                      Text(AppDateUtils.inboxTimestamp(email.receivedAt), style: Theme.of(context).textTheme.bodySmall),
                      if (email.attachments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [for (final a in email.attachments) _buildAttachmentChip(a)],
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _webViewController != null
                      ? WebViewWidget(controller: _webViewController!)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(email.bodyText ?? '(no content)'),
                        ),
                ),
              ],
            ),
    );
  }
}
