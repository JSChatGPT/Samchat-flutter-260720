/// All REST paths, relative to [AppConfig.apiBaseUrl]. Mirrors API_DOCUMENTATION.md.
class Endpoints {
  Endpoints._();

  // Auth
  static const register = '/auth/register';
  static const requestOtp = '/auth/request-otp';
  static const verifyOtp = '/auth/verify-otp';
  static const logout = '/auth/logout';
  static const me = '/user';

  // Users & profile
  static const updateProfile = '/user/profile';
  static const usersSearch = '/users/search';
  static String user(String id) => '/users/$id';
  static String onlineStatus(String id) => '/users/$id/online-status';
  static const heartbeat = '/user/online';
  static const privacy = '/users/privacy';
  static const blockedUsers = '/users/blocked';
  static String block(String userId) => '/users/$userId/block';

  // Contacts
  static const contacts = '/contacts';
  static String contact(String id) => '/contacts/$id';
  static const contactsSync = '/contacts/sync';

  // Chats
  static const chats = '/chats';
  static String chat(String chatId) => '/chats/$chatId';
  static String muteChat(String chatId) => '/chats/$chatId/mute';
  static String typing(String chatId) => '/chats/$chatId/typing';

  // Messages
  static String messages(String chatId) => '/chats/$chatId/messages';
  static String markMessageRead(String messageId) => '/messages/$messageId/read';
  static String deleteMessage(String messageId) => '/messages/$messageId';
  static String bulkDeleteMessages(String chatId) => '/chats/$chatId/messages/bulk';
  static String clearChatMessages(String chatId) => '/chats/$chatId/messages';
  static String forwardMessage(String chatId) => '/chats/$chatId/messages/forward';

  // Groups
  static const groups = '/groups';
  static String groupInfo(String chatId) => '/chats/$chatId/group';
  static String groupImage(String chatId) => '/chats/$chatId/group/image';
  static String leaveGroup(String chatId) => '/chats/$chatId/leave';
  static String participants(String chatId) => '/chats/$chatId/participants';
  static String participantRole(String chatId, String userId) =>
      '/chats/$chatId/participants/$userId/role';
  static String removeParticipant(String chatId, String userId) =>
      '/chats/$chatId/participants/$userId';

  // Realtime
  static const broadcastingAuth = '/broadcasting/auth';

  // Calls
  static const calls = '/calls';
  static const activeCalls = '/calls/active';
  static String call(String callId) => '/calls/$callId';
  static String acceptCall(String callId) => '/calls/$callId/accept';
  static String declineCall(String callId) => '/calls/$callId/decline';
  static String endCall(String callId) => '/calls/$callId/end';
  static String joinCall(String callId) => '/calls/$callId/join';
  static String offerCall(String callId) => '/calls/$callId/offer';
  static String answerCall(String callId) => '/calls/$callId/answer';
  static String candidateCall(String callId) => '/calls/$callId/candidate';
  static String signalCall(String callId) => '/calls/$callId/signal';

  // Statuses
  static const statuses = '/statuses';
  static String deleteStatus(String id) => '/statuses/$id';
  static String viewStatus(String id) => '/statuses/$id/view';
  static String statusViews(String id) => '/statuses/$id/views';

  // Sampay
  static const sampayLink = '/sampay/link';
  static const sampayStatus = '/sampay/status';
  static const sampayUnlink = '/sampay/unlink';
  static String sampayValidateRecipient(String chatId) =>
      '/chats/$chatId/sampay/validate-recipient';
  static String sampayRequestChat(String chatId) => '/chats/$chatId/sampay/request-chat';
  static String sampaySyncStatus(String chatId) => '/chats/$chatId/sampay/sync-status';
  static String sampayApprove(String chatId, String messageId) =>
      '/chats/$chatId/messages/$messageId/sampay/approve';
  static String sampayReject(String chatId, String messageId) =>
      '/chats/$chatId/messages/$messageId/sampay/reject';

  // Push
  static const deviceToken = '/user/device-token';

  // Meetings
  static const meetings = '/meetings';
  static String meeting(String id) => '/meetings/$id';
  static String meetingRespond(String id) => '/meetings/$id/respond';
  static String meetingStart(String id) => '/meetings/$id/start';
  static String meetingIcs(String id) => '/meetings/$id/ics';

  // Email (IMAP/SMTP account linking)
  static const emailAccounts = '/email-accounts';
  static String emailAccount(String id) => '/email-accounts/$id';
  static String syncEmailAccount(String id) => '/email-accounts/$id/sync';
  static String accountEmails(String accountId) => '/email-accounts/$accountId/emails';
  static String sendEmail(String accountId) => '/email-accounts/$accountId/send';
  static String email(String emailId) => '/emails/$emailId';
  static String replyEmail(String emailId) => '/emails/$emailId/reply';
}
