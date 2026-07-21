import '../config/app_config.dart';

/// Some backend-seeded/test media URLs point at `localhost` or `127.0.0.1`
/// instead of the real LAN host — meaningless from a phone, which resolves
/// "localhost" to itself, not the server. Rewrite the scheme+host+port to
/// match [AppConfig.appUrl] (derived from the same base URL as every other
/// API call) whenever it's one of those loopback hosts, and leave any other
/// URL untouched.
String? normalizeMediaUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  if (!uri.hasAuthority) {
    // A bare relative path (e.g. '/storage/uploads/x.jpg', as stored by the
    // backend for chat/email attachments) has no scheme/host at all —
    // left alone, this gets passed straight to an image/file loader with
    // nothing to resolve it against, which is exactly what surfaces as
    // "No host specified in URI file:///storage/...". Resolve it against
    // the app's own base URL instead.
    final appUri = Uri.tryParse(AppConfig.appUrl);
    if (appUri == null) return url;
    return appUri.resolve(url).toString();
  }

  if (uri.host != 'localhost' && uri.host != '127.0.0.1') return url;

  final appUri = Uri.tryParse(AppConfig.appUrl);
  if (appUri == null) return url;

  return uri.replace(scheme: appUri.scheme, host: appUri.host, port: appUri.port).toString();
}
