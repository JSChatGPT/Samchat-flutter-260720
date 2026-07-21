import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/email_account.dart';
import '../../application/email_notifier.dart';

class _MailPreset {
  const _MailPreset(this.imapHost, this.imapPort, this.imapEncryption, this.smtpHost, this.smtpPort, this.smtpEncryption);

  final String imapHost;
  final int imapPort;
  final MailEncryption imapEncryption;
  final String smtpHost;
  final int smtpPort;
  final MailEncryption smtpEncryption;
}

/// Well-known public IMAP/SMTP settings for common providers, keyed by email
/// domain, so a "Custom" account mostly needs just an address + password.
/// Anything not in this table falls back to a `mail.<domain>` guess (the
/// convention most small/self-hosted mail setups follow) — the fields stay
/// editable specifically so a wrong guess can be corrected before connecting.
const _knownMailPresets = <String, _MailPreset>{
  'gmail.com': _MailPreset('imap.gmail.com', 993, MailEncryption.ssl, 'smtp.gmail.com', 465, MailEncryption.ssl),
  'googlemail.com': _MailPreset('imap.gmail.com', 993, MailEncryption.ssl, 'smtp.gmail.com', 465, MailEncryption.ssl),
  'yahoo.com': _MailPreset('imap.mail.yahoo.com', 993, MailEncryption.ssl, 'smtp.mail.yahoo.com', 465, MailEncryption.ssl),
  'ymail.com': _MailPreset('imap.mail.yahoo.com', 993, MailEncryption.ssl, 'smtp.mail.yahoo.com', 465, MailEncryption.ssl),
  'outlook.com': _MailPreset('outlook.office365.com', 993, MailEncryption.ssl, 'smtp-mail.outlook.com', 587, MailEncryption.tls),
  'hotmail.com': _MailPreset('outlook.office365.com', 993, MailEncryption.ssl, 'smtp-mail.outlook.com', 587, MailEncryption.tls),
  'live.com': _MailPreset('outlook.office365.com', 993, MailEncryption.ssl, 'smtp-mail.outlook.com', 587, MailEncryption.tls),
  'msn.com': _MailPreset('outlook.office365.com', 993, MailEncryption.ssl, 'smtp-mail.outlook.com', 587, MailEncryption.tls),
  'icloud.com': _MailPreset('imap.mail.me.com', 993, MailEncryption.ssl, 'smtp.mail.me.com', 587, MailEncryption.tls),
  'me.com': _MailPreset('imap.mail.me.com', 993, MailEncryption.ssl, 'smtp.mail.me.com', 587, MailEncryption.tls),
  'mac.com': _MailPreset('imap.mail.me.com', 993, MailEncryption.ssl, 'smtp.mail.me.com', 587, MailEncryption.tls),
  'aol.com': _MailPreset('imap.aol.com', 993, MailEncryption.ssl, 'smtp.aol.com', 465, MailEncryption.ssl),
  'zoho.com': _MailPreset('imap.zoho.com', 993, MailEncryption.ssl, 'smtp.zoho.com', 465, MailEncryption.ssl),
  'gmx.com': _MailPreset('imap.gmx.com', 993, MailEncryption.ssl, 'smtp.gmx.com', 465, MailEncryption.ssl),
};

_MailPreset _guessPresetForDomain(String domain) {
  final known = _knownMailPresets[domain];
  if (known != null) return known;
  return _MailPreset('mail.$domain', 993, MailEncryption.ssl, 'mail.$domain', 465, MailEncryption.ssl);
}

class ConnectEmailScreen extends ConsumerStatefulWidget {
  const ConnectEmailScreen({super.key});

  @override
  ConsumerState<ConnectEmailScreen> createState() => _ConnectEmailScreenState();
}

class _ConnectEmailScreenState extends ConsumerState<ConnectEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imapHostController = TextEditingController();
  final _imapPortController = TextEditingController();
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController();
  EmailProvider _provider = EmailProvider.gmail;
  MailEncryption _imapEncryption = MailEncryption.ssl;
  MailEncryption _smtpEncryption = MailEncryption.ssl;
  bool _customFieldsVisible = false;
  bool _connecting = false;
  String? _error;

  bool get _isCustom => _provider == EmailProvider.custom;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    super.dispose();
  }

  /// Keeps the (possibly hidden) IMAP/SMTP fields in sync with whatever
  /// domain the user has typed so far — connecting works without ever
  /// opening "Edit IMAP/SMTP settings" for a recognized/guessable domain.
  /// Stops once the panel is open so it doesn't clobber manual edits.
  void _onEmailChanged() {
    if (!_isCustom || _customFieldsVisible) {
      setState(() {});
      return;
    }
    _applyPresetFromEmail();
  }

  void _applyPresetFromEmail() {
    final email = _emailController.text.trim();
    final atIndex = email.indexOf('@');
    if (atIndex == -1 || atIndex == email.length - 1) {
      setState(() {});
      return;
    }
    final domain = email.substring(atIndex + 1).toLowerCase();
    final preset = _guessPresetForDomain(domain);
    _imapHostController.text = preset.imapHost;
    _imapPortController.text = preset.imapPort.toString();
    _smtpHostController.text = preset.smtpHost;
    _smtpPortController.text = preset.smtpPort.toString();
    setState(() {
      _imapEncryption = preset.imapEncryption;
      _smtpEncryption = preset.smtpEncryption;
    });
  }

  void _toggleCustomFields() {
    final opening = !_customFieldsVisible;
    if (opening) _applyPresetFromEmail();
    setState(() => _customFieldsVisible = opening);
  }

  Uri get _appPasswordHelpUrl => _provider == EmailProvider.yahoo
      ? Uri.parse('https://login.yahoo.com/myaccount/security')
      : Uri.parse('https://myaccount.google.com/apppasswords');

  bool get _canConnect {
    if (_connecting) return false;
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) return false;
    if (!_isCustom) return true;
    return _imapHostController.text.trim().isNotEmpty &&
        _imapPortController.text.trim().isNotEmpty &&
        _smtpHostController.text.trim().isNotEmpty &&
        _smtpPortController.text.trim().isNotEmpty;
  }

  Future<void> _connect() async {
    if (!_canConnect) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await ref.read(emailAccountsNotifierProvider.notifier).connect(
            provider: _provider,
            emailAddress: _emailController.text.trim(),
            appPassword: _passwordController.text.trim(),
            imapHost: _isCustom ? _imapHostController.text.trim() : null,
            imapPort: _isCustom ? int.tryParse(_imapPortController.text.trim()) : null,
            imapEncryption: _isCustom ? _imapEncryption : null,
            smtpHost: _isCustom ? _smtpHostController.text.trim() : null,
            smtpPort: _isCustom ? int.tryParse(_smtpPortController.text.trim()) : null,
            smtpEncryption: _isCustom ? _smtpEncryption : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link an email account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<EmailProvider>(
            segments: const [
              ButtonSegment(value: EmailProvider.gmail, label: Text('Gmail')),
              ButtonSegment(value: EmailProvider.yahoo, label: Text('Yahoo')),
              ButtonSegment(value: EmailProvider.custom, label: Text('Custom')),
            ],
            selected: {_provider},
            onSelectionChanged: (s) => setState(() {
              _provider = s.first;
              _customFieldsVisible = false;
              if (_isCustom) _applyPresetFromEmail();
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: _isCustom ? 'Password' : 'App password',
              prefixIcon: const Icon(Icons.key_outlined),
            ),
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_isCustom) ...[
            Text(
              'We auto-detect your mail server settings from the email address. '
              'Tap below to review or change them before connecting.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: _toggleCustomFields,
              icon: Icon(_customFieldsVisible ? Icons.expand_less : Icons.settings_outlined),
              label: Text(_customFieldsVisible ? 'Hide IMAP/SMTP settings' : 'Edit IMAP/SMTP settings'),
            ),
            if (_customFieldsVisible) ...[
              const SizedBox(height: 8),
              Text('Incoming mail (IMAP)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _imapHostController,
                      decoration: const InputDecoration(labelText: 'IMAP host'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _imapPortController,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MailEncryption>(
                initialValue: _imapEncryption,
                decoration: const InputDecoration(labelText: 'IMAP encryption'),
                items: [
                  for (final e in MailEncryption.values) DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: (v) => setState(() => _imapEncryption = v ?? _imapEncryption),
              ),
              const SizedBox(height: 16),
              Text('Outgoing mail (SMTP)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _smtpHostController,
                      decoration: const InputDecoration(labelText: 'SMTP host'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _smtpPortController,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MailEncryption>(
                initialValue: _smtpEncryption,
                decoration: const InputDecoration(labelText: 'SMTP encryption'),
                items: const [
                  DropdownMenuItem(value: MailEncryption.ssl, child: Text('SSL')),
                  DropdownMenuItem(value: MailEncryption.tls, child: Text('TLS / STARTTLS')),
                  DropdownMenuItem(value: MailEncryption.none, child: Text('None')),
                ],
                onChanged: (v) => setState(() => _smtpEncryption = v ?? _smtpEncryption),
              ),
            ],
          ] else ...[
            Text(
              'This is NOT your normal ${_provider.label} password. Generate a 16-character '
              'app password in your account\'s security settings and paste it here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () => launchUrl(_appPasswordHelpUrl, mode: LaunchMode.externalApplication),
              child: Text('Generate an app password for ${_provider.label}'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _canConnect ? _connect : null,
            child: _connecting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
