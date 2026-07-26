/// Central runtime configuration. Override any of these at build/run time with
/// `--dart-define=KEY=VALUE` (e.g. `flutter run --dart-define=API_BASE_URL=https://api.samchat.app/api`).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://samchat.sampay.biz/api',
  );

  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://samchat.sampay.biz',
  );

  // Realtime is Pusher Channels (pusher.com), not self-hosted Reverb — the
  // backend switched off Reverb to stop paying for a self-hosted websocket
  // server. Same Pusher app as the web client (resources/js/echo.js /
  // config/broadcasting.php on the backend); mobile and web share one set of
  // channels/events. Override with --dart-define if the backend's Pusher app
  // ever changes; only the key is needed client-side, never the secret.
  static const String pusherAppKey = String.fromEnvironment(
    'PUSHER_APP_KEY',
    defaultValue: 'a0c6fe77c87e5dd86809',
  );

  static const String pusherCluster = String.fromEnvironment(
    'PUSHER_APP_CLUSTER',
    defaultValue: 'ap2',
  );

  static String get pusherWsHost => 'ws-$pusherCluster.pusher.com';
  static const int pusherWsPort = 443;
  static const bool pusherUseTls = true;

  // WebRTC TURN relay. STUN (hard-coded in call_service) only discovers public
  // addresses; when a direct peer path is blocked (Wi-Fi AP/client isolation,
  // symmetric NAT, mobile data), media needs a TURN relay or ICE fails. The
  // primary relay is now a short-lived Cloudflare Realtime TURN credential
  // fetched per-call from the backend (see CallsRepository.turnCredentials /
  // CallController::turnCredentials) — reachable from anywhere, unlike a
  // self-hosted TURN box tied to one LAN's IP. `turnUrl` here is just an
  // optional *extra* static TURN server appended on top of that (e.g. a
  // dedicated always-on relay, if one is ever stood up); left empty by
  // default since Cloudflare's fetched credential already covers this.
  static const String turnUrl = String.fromEnvironment('TURN_URL', defaultValue: '');
  static const String turnUsername = String.fromEnvironment('TURN_USERNAME', defaultValue: '');
  static const String turnCredential = String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

  static const Duration onlineHeartbeatInterval = Duration(seconds: 75);
  static const Duration typingDebounce = Duration(milliseconds: 1600);
  static const Duration sampaySyncInterval = Duration(seconds: 8);
}
