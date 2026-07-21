import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// One-way "share via" hand-off to WhatsApp/email/the OS share sheet —
/// not an inbox integration (that needs real WhatsApp Business API / Gmail
/// OAuth credentials the app doesn't have). This just opens the target app
/// pre-filled with [text], the same way the app's SMS invite already does.
Future<void> showShareViaSheet(BuildContext context, {required String text, String? subject}) async {
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Share via', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp'),
            onTap: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
                _showLaunchFailure(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            onTap: () async {
              Navigator.pop(ctx);
              final uri = Uri(
                scheme: 'mailto',
                queryParameters: {if (subject != null) 'subject': subject, 'body': text},
              );
              if (!await launchUrl(uri) && context.mounted) {
                _showLaunchFailure(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('More (Instagram, Twitter/X, LinkedIn…)'),
            subtitle: const Text('Uses whatever apps are installed on your device'),
            onTap: () {
              Navigator.pop(ctx);
              Share.share(text, subject: subject);
            },
          ),
        ],
      ),
    ),
  );
}

void _showLaunchFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open that app')),
  );
}
