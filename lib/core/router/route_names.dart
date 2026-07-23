class RouteNames {
  RouteNames._();

  static const splash = 'splash';
  static const phoneEntry = 'phoneEntry';
  static const register = 'register';
  static const otpVerify = 'otpVerify';

  static const home = 'home';
  static const chats = 'chats';
  static const statuses = 'statuses';
  static const groups = 'groups';
  static const calls = 'calls';
  static const sampay = 'sampay';
  static const settings = 'settings';
  static const meetings = 'meetings';
  static const scheduleMeeting = 'scheduleMeeting';
  static const emailAccounts = 'emailAccounts';

  static const smsInbox = 'smsInbox';
  static const smsThread = 'smsThread';
  static const shareTarget = 'shareTarget';

  static const chatDetail = 'chatDetail';
  static const contactPicker = 'contactPicker';
  static const createGroup = 'createGroup';
  static const groupInfo = 'groupInfo';
  static const chatBackupRestore = 'chatBackupRestore';
  static const chatBackupSettings = 'chatBackupSettings';

  static const statusViewer = 'statusViewer';
  static const statusCreate = 'statusCreate';
  static const statusViews = 'statusViews';

  static const outgoingCall = 'outgoingCall';
  static const incomingCall = 'incomingCall';
  static const inCall = 'inCall';

  static const sampayLink = 'sampayLink';

  static const profileEdit = 'profileEdit';
  static const privacySettings = 'privacySettings';
  static const appLockSettings = 'appLockSettings';
  static const blockedUsers = 'blockedUsers';
  static const about = 'about';
}

class RoutePaths {
  RoutePaths._();

  static const splash = '/splash';
  static const phoneEntry = '/phone-entry';
  static const register = '/register';
  static const otpVerify = '/otp-verify';

  static const home = chats;
  static const chats = '/chats';
  static const statuses = '/statuses';
  static const groups = '/groups';
  static const calls = '/calls';
  static const sampay = '/sampay';
  static const settings = '/settings';
  static const meetings = '/meetings';
  static const scheduleMeeting = '/meetings/schedule';
  static const emailAccounts = '/email';
  static const smsInbox = '/sms';
  static const smsThread = '/sms/thread';
  static const shareTarget = '/share-target';

  static const chatDetail = '/chat/:chatId';
  static const contactPicker = '/contact-picker';
  static const createGroup = '/create-group';
  static const groupInfo = '/chat/:chatId/group-info';
  static const chatBackupRestore = '/chat-backup/restore';
  static const chatBackupSettings = '/settings/chat-backup';

  static const statusViewer = '/status-viewer/:userId';
  static const statusCreate = '/status-create';
  static const statusViews = '/status-views';

  static const outgoingCall = '/call/outgoing';
  static const incomingCall = '/call/incoming';
  static const inCall = '/call/active';

  static const sampayLink = '/sampay/link';

  static const profileEdit = '/settings/profile-edit';
  static const privacySettings = '/settings/privacy';
  static const appLockSettings = '/settings/privacy/app-lock';
  static const blockedUsers = '/settings/blocked-users';
  static const about = '/settings/about';
}
