import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../application/sampay_status_provider.dart';

/// Mobile flow per API_DOCUMENTATION.md §9: open `authorization_url` in an
/// in-app webview, Sampay redirects to `{APP_URL}/app?sampay_linked=1` (or
/// `sampay_error`) on completion — we intercept that navigation instead of
/// letting the webview actually load it, then pop and refresh link status.
class SampayLinkScreen extends ConsumerStatefulWidget {
  const SampayLinkScreen({super.key, required this.authorizationUrl});

  final String authorizationUrl;

  @override
  ConsumerState<SampayLinkScreen> createState() => _SampayLinkScreenState();
}

class _SampayLinkScreenState extends ConsumerState<SampayLinkScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith(AppConfig.appUrl) &&
                (url.contains('sampay_linked=1') || url.contains('sampay_error'))) {
              final linked = url.contains('sampay_linked=1');
              ref.read(sampayStatusProvider.notifier).refresh();
              Navigator.of(context).pop(linked);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Sampay account')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
