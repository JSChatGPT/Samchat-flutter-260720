import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/sms_conversation.dart';
import '../../../models/sms_message.dart';
import '../data/sms_repository.dart';

final smsRepositoryProvider = Provider<SmsRepository>((ref) => SmsRepository());

enum SmsInboxStatus { loading, notDefault, ready, error }

class SmsInboxState {
  const SmsInboxState({this.status = SmsInboxStatus.loading, this.conversations = const [], this.error});

  final SmsInboxStatus status;
  final List<SmsConversation> conversations;
  final String? error;

  SmsInboxState copyWith({SmsInboxStatus? status, List<SmsConversation>? conversations, String? error}) {
    return SmsInboxState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      error: error,
    );
  }
}

final smsInboxNotifierProvider = StateNotifierProvider<SmsInboxNotifier, SmsInboxState>((ref) {
  return SmsInboxNotifier(ref.watch(smsRepositoryProvider));
});

/// Summed across every conversation — drives the badge on the SMS tab.
final totalUnreadSmsCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(smsInboxNotifierProvider).conversations;
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

class SmsInboxNotifier extends StateNotifier<SmsInboxState> {
  SmsInboxNotifier(this._repository) : super(const SmsInboxState()) {
    _init();
  }

  final SmsRepository _repository;
  StreamSubscription<SmsMessage>? _incomingSub;

  Future<void> _init() async {
    final isDefault = await _repository.isDefaultSmsApp();
    if (!isDefault) {
      state = state.copyWith(status: SmsInboxStatus.notDefault);
      return;
    }
    await refresh();
    _incomingSub ??= _repository.incomingMessages().listen((_) => refresh());
  }

  /// Optimistically zeroes a conversation's unread count the moment the
  /// user opens it — the native `markThreadRead` call (see SmsThreadNotifier)
  /// updates the OS content provider separately, but doesn't touch this
  /// already-fetched list, so without this the tab/list badge would stay
  /// stale until the next full [refresh].
  void markThreadRead(String threadId) {
    final idx = state.conversations.indexWhere((c) => c.threadId == threadId);
    if (idx == -1 || state.conversations[idx].unreadCount == 0) return;
    final list = [...state.conversations];
    list[idx] = list[idx].copyWith(unreadCount: 0);
    state = state.copyWith(conversations: list);
  }

  Future<void> requestDefault() async {
    final granted = await _repository.requestDefaultSmsApp();
    if (!granted) {
      state = state.copyWith(status: SmsInboxStatus.notDefault);
      return;
    }
    await refresh();
    _incomingSub ??= _repository.incomingMessages().listen((_) => refresh());
  }

  Future<void> refresh() async {
    state = state.copyWith(status: SmsInboxStatus.loading);
    try {
      final conversations = await _repository.getConversations();
      state = state.copyWith(status: SmsInboxStatus.ready, conversations: conversations);
    } catch (e) {
      state = state.copyWith(status: SmsInboxStatus.error, error: '$e');
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
}

/// Identifies a thread screen. [threadId] is empty when composing to
/// [address] for the very first time — resolved (and created) on first send.
class SmsThreadArgs extends Equatable {
  const SmsThreadArgs({required this.threadId, required this.address});

  final String threadId;
  final String address;

  @override
  List<Object?> get props => [threadId, address];
}

class SmsThreadState {
  const SmsThreadState({this.threadId = '', this.messages = const [], this.loading = true, this.sending = false});

  final String threadId;
  final List<SmsMessage> messages;
  final bool loading;
  final bool sending;

  SmsThreadState copyWith({String? threadId, List<SmsMessage>? messages, bool? loading, bool? sending}) {
    return SmsThreadState(
      threadId: threadId ?? this.threadId,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
    );
  }
}

final smsThreadNotifierProvider =
    StateNotifierProvider.autoDispose.family<SmsThreadNotifier, SmsThreadState, SmsThreadArgs>((ref, args) {
  return SmsThreadNotifier(ref.watch(smsRepositoryProvider), args);
});

class SmsThreadNotifier extends StateNotifier<SmsThreadState> {
  SmsThreadNotifier(this._repository, this._args)
      : super(SmsThreadState(threadId: _args.threadId, loading: _args.threadId.isNotEmpty)) {
    if (_args.threadId.isNotEmpty) _load();
    _incomingSub = _repository.incomingMessages().listen(_onIncoming);
  }

  final SmsRepository _repository;
  final SmsThreadArgs _args;
  late final StreamSubscription<SmsMessage> _incomingSub;

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    final messages = await _repository.getMessages(state.threadId);
    // autoDispose: backing out of this thread while the load is still in
    // flight disposes the notifier before it resolves — setting state
    // afterward throws "Tried to use X after dispose was called" instead of
    // just being a harmless no-op.
    if (!mounted) return;
    state = state.copyWith(loading: false, messages: messages);
    await _repository.markThreadRead(state.threadId);
  }

  void _onIncoming(SmsMessage message) {
    final matchesThread = state.threadId.isNotEmpty && message.threadId == state.threadId;
    final matchesNewAddress = state.threadId.isEmpty && message.address == _args.address;
    if (!matchesThread && !matchesNewAddress) return;
    state = state.copyWith(threadId: message.threadId ?? state.threadId, messages: [...state.messages, message]);
    if (state.threadId.isNotEmpty) _repository.markThreadRead(state.threadId);
  }

  Future<void> send(String body) async {
    if (body.trim().isEmpty) return;
    state = state.copyWith(sending: true);
    try {
      final sent = await _repository.sendSms(address: _args.address, body: body.trim());
      if (!mounted) return;
      final message = SmsMessage(
        id: sent.id,
        address: _args.address,
        body: body.trim(),
        date: DateTime.now(),
        outgoing: true,
      );
      state = state.copyWith(threadId: sent.threadId, messages: [...state.messages, message], sending: false);
    } catch (e) {
      if (mounted) state = state.copyWith(sending: false);
      rethrow;
    }
  }

  @override
  void dispose() {
    _incomingSub.cancel();
    super.dispose();
  }
}
