import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../models/email_account.dart';
import '../../../models/email_message.dart';
import '../data/email_repository.dart';
import '../../auth/application/auth_notifier.dart';

final emailRepositoryProvider = Provider<EmailRepository>((ref) {
  return EmailRepository(ref.watch(dioProvider));
});

enum EmailAccountsStatus { loading, loaded, error }

class EmailAccountsState {
  const EmailAccountsState({this.status = EmailAccountsStatus.loading, this.accounts = const [], this.error});

  final EmailAccountsStatus status;
  final List<EmailAccount> accounts;
  final String? error;

  EmailAccountsState copyWith({EmailAccountsStatus? status, List<EmailAccount>? accounts, String? error}) {
    return EmailAccountsState(status: status ?? this.status, accounts: accounts ?? this.accounts, error: error);
  }
}

final emailAccountsNotifierProvider = StateNotifierProvider<EmailAccountsNotifier, EmailAccountsState>((ref) {
  return EmailAccountsNotifier(ref.watch(emailRepositoryProvider));
});

/// Summed across every connected account — drives the badge on the Email
/// tab/icon. Capped display (99+) is a presentation concern, left to the
/// widget that renders this.
final totalUnreadEmailCountProvider = Provider<int>((ref) {
  final accounts = ref.watch(emailAccountsNotifierProvider).accounts;
  return accounts.fold<int>(0, (sum, account) => sum + account.unreadCount);
});

/// App-lifetime side-effect provider: subscribes to `user.{myId}` and
/// refreshes account/unread counts whenever the backend's `emails:sync`
/// scheduled job (every 5 minutes, see samchats_web's SyncEmailAccounts
/// command) finds new mail — keeps the tab/account badges live while the
/// app is foregrounded, complementing the FCM push shown when it isn't (see
/// push_service.dart's `new_email` handling). Read once (e.g. in app.dart)
/// to activate.
final emailRealtimeListenerProvider = Provider<void>((ref) {
  final pusher = ref.watch(pusherServiceProvider);
  final myUserId = ref.watch(currentUserIdProvider);

  final sub = pusher.events.listen((event) {
    if (event.eventName != RealtimeEventNames.newEmailReceived) return;
    if (myUserId.isEmpty || event.channelName != RealtimeChannels.user(myUserId)) return;
    ref.read(emailAccountsNotifierProvider.notifier).refresh();
  });

  ref.onDispose(sub.cancel);
});

class EmailAccountsNotifier extends StateNotifier<EmailAccountsState> {
  EmailAccountsNotifier(this._repository) : super(const EmailAccountsState()) {
    refresh();
  }

  final EmailRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(status: EmailAccountsStatus.loading);
    try {
      final accounts = await _repository.getAccounts();
      state = state.copyWith(status: EmailAccountsStatus.loaded, accounts: accounts);
    } on ApiException catch (e) {
      state = state.copyWith(status: EmailAccountsStatus.error, error: e.message);
    }
  }

  /// Rethrows on failure (bad app password / unreachable server) so the
  /// connect screen can show the specific reason inline.
  Future<void> connect({
    required EmailProvider provider,
    required String emailAddress,
    required String appPassword,
    String? imapHost,
    int? imapPort,
    MailEncryption? imapEncryption,
    String? smtpHost,
    int? smtpPort,
    MailEncryption? smtpEncryption,
  }) async {
    await _repository.connectAccount(
      provider: provider,
      emailAddress: emailAddress,
      appPassword: appPassword,
      imapHost: imapHost,
      imapPort: imapPort,
      imapEncryption: imapEncryption,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      smtpEncryption: smtpEncryption,
    );
    await refresh();
  }

  Future<void> disconnect(String id) async {
    await _repository.disconnectAccount(id);
    await refresh();
  }

  /// Optimistically decrements an account's unread count the moment one of
  /// its emails is read — see EmailInboxNotifier.markEmailRead. Keeps the
  /// tab/account badges in sync without waiting on a full [refresh].
  void decrementUnread(String accountId) {
    final idx = state.accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1 || state.accounts[idx].unreadCount <= 0) return;
    final list = [...state.accounts];
    list[idx] = list[idx].copyWith(unreadCount: list[idx].unreadCount - 1);
    state = state.copyWith(accounts: list);
  }
}

enum EmailInboxStatus { loading, loaded, error }

class EmailInboxState {
  const EmailInboxState({
    this.status = EmailInboxStatus.loading,
    this.emails = const [],
    this.hasMore = false,
    this.nextPage = 1,
    this.loadingMore = false,
    this.error,
  });

  final EmailInboxStatus status;
  final List<EmailMessage> emails;
  final bool hasMore;
  final int nextPage;
  final bool loadingMore;
  final String? error;

  EmailInboxState copyWith({
    EmailInboxStatus? status,
    List<EmailMessage>? emails,
    bool? hasMore,
    int? nextPage,
    bool? loadingMore,
    String? error,
  }) {
    return EmailInboxState(
      status: status ?? this.status,
      emails: emails ?? this.emails,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }
}

final emailInboxNotifierProvider =
    StateNotifierProvider.autoDispose.family<EmailInboxNotifier, EmailInboxState, String>((ref, accountId) {
  return EmailInboxNotifier(ref.watch(emailRepositoryProvider), accountId);
});

class EmailInboxNotifier extends StateNotifier<EmailInboxState> {
  EmailInboxNotifier(this._repository, this._accountId) : super(const EmailInboxState()) {
    refresh();
  }

  final EmailRepository _repository;
  final String _accountId;

  /// Loads the already-synced list from our own DB first — fast, no third-
  /// party network I/O — then kicks off a real IMAP sync in the background
  /// and only re-renders if it actually found new mail. Previously this
  /// awaited the IMAP sync (real, sometimes multi-second network I/O against
  /// Gmail/Yahoo) before showing anything, which made every inbox open feel
  /// slow even though the list itself loads instantly from our database.
  Future<void> refresh() async {
    state = state.copyWith(status: EmailInboxStatus.loading);
    try {
      final page = await _repository.getEmails(_accountId, page: 1);
      // autoDispose: switching away from this inbox (e.g. to another tab)
      // while this request is in flight disposes the notifier before the
      // response lands — setting state afterward throws "Tried to use X
      // after dispose was called" instead of just being a harmless no-op.
      if (!mounted) return;
      state = state.copyWith(
        status: EmailInboxStatus.loaded,
        emails: page.emails,
        hasMore: page.hasMore,
        nextPage: page.nextPage,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(status: EmailInboxStatus.error, error: e.message);
      return;
    }
    unawaited(_syncInBackground());
  }

  /// Best-effort: a sync failure (server unreachable, credentials since
  /// revoked, etc.) shouldn't disturb whatever's already showing.
  Future<void> _syncInBackground() async {
    try {
      final newCount = await _repository.syncAccount(_accountId);
      if (newCount == 0 || !mounted) return;
      final page = await _repository.getEmails(_accountId, page: 1);
      if (!mounted) return;
      state = state.copyWith(emails: page.emails, hasMore: page.hasMore, nextPage: page.nextPage);
    } on ApiException {
      // Ignored — see above.
    }
  }

  /// Optimistically marks an email read the moment it's opened — the
  /// backend's `GET /emails/{id}` already marks it read server-side (see
  /// EmailDetailScreen), so this just keeps the list/badges in sync without
  /// a redundant round trip.
  void markEmailRead(String emailId) {
    final idx = state.emails.indexWhere((e) => e.id == emailId);
    if (idx == -1 || state.emails[idx].isRead) return;
    final list = [...state.emails];
    list[idx] = list[idx].copyWith(isRead: true);
    state = state.copyWith(emails: list);
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repository.getEmails(_accountId, page: state.nextPage);
      if (!mounted) return;
      state = state.copyWith(
        emails: [...state.emails, ...page.emails],
        hasMore: page.hasMore,
        nextPage: page.nextPage,
        loadingMore: false,
      );
    } on ApiException {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }
}
