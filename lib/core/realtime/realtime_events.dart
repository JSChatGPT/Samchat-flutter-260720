/// A decoded event coming off any subscribed Pusher channel.
/// [eventName] is the *wire* name — for CallSignal this is the dynamic
/// `client-user-joined` / `client-webrtc-signal`, not "CallSignal". Note the
/// name is the raw Pusher-frame name with NO leading dot: the `.`-prefix seen
/// in Laravel Echo (`.listen('.client-webrtc-signal')`) is Echo's
/// skip-the-namespace marker and never appears on the wire.
class RealtimeEvent {
  const RealtimeEvent({required this.channelName, required this.eventName, required this.data});

  final String channelName;
  final String eventName;
  final Map<String, dynamic> data;
}

/// Well-known event names, exactly as they appear on the wire per
/// API_DOCUMENTATION.md §6.
class RealtimeEventNames {
  RealtimeEventNames._();

  static const messageSent = 'MessageSent';
  static const messagesRead = 'MessagesRead';
  static const messageReactionUpdated = 'MessageReactionUpdated';
  static const userTyping = 'UserTyping';
  static const incomingCall = 'IncomingCall';
  static const callAnswered = 'CallAnswered';
  static const callDeclined = 'CallDeclined';
  static const newEmailReceived = 'NewEmailReceived';
  static const chatKeyGrantRequested = 'ChatKeyGrantRequested';
  static const clientUserJoined = 'client-user-joined';
  static const clientUserLeft = 'client-user-left';
  static const clientWebrtcSignal = 'client-webrtc-signal';

  // Pusher connection lifecycle "events" the plugin also surfaces on the
  // same subscription-succeeded channel — not part of the app protocol but
  // occasionally useful to filter out.
  static const subscriptionSucceeded = 'pusher_internal:subscription_succeeded';
}

class RealtimeChannels {
  RealtimeChannels._();

  static String user(String userId) => 'private-user.$userId';
  static String chat(String chatId) => 'private-chat.$chatId';
  static String call(String callId) => 'private-call.$callId';
  static const presenceApp = 'presence-app';
}
