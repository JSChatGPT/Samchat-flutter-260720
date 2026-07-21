/// Central runtime configuration. Override any of these at build/run time with
/// `--dart-define=KEY=VALUE` (e.g. `flutter run --dart-define=API_BASE_URL=https://api.samchat.app/api`).
class AppConfig {
  AppConfig._();

  // This dev backend's LAN IP is DHCP-assigned and drifts when the host
  // reconnects to Wi-Fi (it has moved at least once already, from
  // 10.253.52.73 to 192.168.208.137) — apiBaseUrl/appUrl/turnUrl below all
  // point at whatever it currently is. If REST calls or TURN relay start
  // failing outright (not just realtime), check the backend's current LAN
  // IP first (`ip -4 addr show` on that host) before assuming a code bug.
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
  // symmetric NAT, mobile-data), media needs a TURN relay or ICE fails. Points
  // at the coturn instance running alongside this dev backend (systemd unit
  // `coturn`, /etc/turnserver.conf) — same LAN-IP-drift caveat as apiBaseUrl
  // above (coturn's listening-ip/external-ip/relay-ip in turnserver.conf must
  // match this host too, or TURN silently stops relaying). Override with
  // --dart-define for other environments; pass an empty TURN_URL to fall back
  // to STUN-only.
  static const String turnUrl = String.fromEnvironment(
    'TURN_URL',
    defaultValue: 'turn:192.168.208.137:3478',
  );
  static const String turnUsername = String.fromEnvironment(
    'TURN_USERNAME',
    defaultValue: 'samchat',
  );
  static const String turnCredential = String.fromEnvironment(
    'TURN_CREDENTIAL',
    defaultValue: 'd47e755ec54acf327ec48b26',
  );

  static const Duration onlineHeartbeatInterval = Duration(seconds: 75);
  static const Duration typingDebounce = Duration(milliseconds: 1600);
  static const Duration sampaySyncInterval = Duration(seconds: 8);
}
