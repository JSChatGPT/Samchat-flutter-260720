import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cache/chat_cache_service.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/crypto/message_decryptor.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/realtime/pusher_service.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../models/chat.dart';
import '../../../models/message.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/chats_repository.dart';

enum InboxLoadStatus { loading, loaded, error }

class InboxState {
  const InboxState({
    this.status = InboxLoadStatus.loading,
    this.chats = const [],
    this.blockedUserIds = const [],
    this.filter = InboxFilter.all,
    this.search = '',
    this.typingChatIds = const {},
    this.error,
  });

  final InboxLoadStatus status;
  final List<Chat> chats;
  final List<String> blockedUserIds;
  final InboxFilter filter;
  final String search;

  /// IDs of chats where the other participant is currently typing — drives
  /// the "typing…" preview in the chat list for chats that aren't open.
  final Set<String> typingChatIds;
  final String? error;

  InboxState copyWith({
    InboxLoadStatus? status,
    List<Chat>? chats,
    List<String>? blockedUserIds,
    InboxFilter? filter,
    String? search,
    Set<String>? typingChatIds,
    String? error,
  }) {
    return InboxState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      filter: filter ?? this.filter,
      search: search ?? this.search,
      typingChatIds: typingChatIds ?? this.typingChatIds,
      error: error,
    );
  }
}

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  return ChatsRepository(ref.watch(dioProvider), ref.watch(e2eeServiceProvider));
});

/// Bumped by the shared home-shell AppBar's search icon; InboxScreen listens
/// to it to focus its persistent search field. Other tabs ignore it.
final inboxSearchFocusRequestProvider = StateProvider<int>((ref) => 0);

/// Summed across every chat — drives the badge on the Chats tab.
final totalUnreadChatsCountProvider = Provider<int>((ref) {
  final chats = ref.watch(inboxNotifierProvider).chats;
  return chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
});

/// App-lifetime — the inbox stays subscribed to every participant chat via
/// each chat's own `user.{myId}` MessageSent broadcast, so it's alive for as
/// long as the user is logged in, not scoped to the Chats tab being visible.
final inboxNotifierProvider = StateNotifierProvider<InboxNotifier, InboxState>((ref) {
  final notifier = InboxNotifier(
    repository: ref.watch(chatsRepositoryProvider),
    pusher: ref.watch(pusherServiceProvider),
    myUserId: ref.watch(currentUserIdProvider),
    e2ee: ref.watch(e2eeServiceProvider),
    cache: ref.watch(chatCacheServiceProvider),
  );
  ref.onDispose(notifier.disposeSubscription);
  return notifier;
});

class InboxNotifier extends StateNotifier<InboxState> {
  InboxNotifier({
    required this.repository,
    required this.pusher,
    required this.myUserId,
    required this.e2ee,
    required this.cache,
  }) : super(const InboxState()) {
    _sub = pusher.events.listen(_onRealtimeEvent);
    _loadFromCacheThenRefresh();
  }

  final ChatsRepository repository;
  final PusherService pusher;
  final String myUserId;
  final E2eeService e2ee;
  final ChatCacheService cache;
  StreamSubscription? _sub;

  /// Paints the last-known chat list instantly from the local cache (no
  /// network round trip) before ever attempting [refresh] — the only thing
  /// that makes a cold app start while offline show anything at all,
  /// since a fresh notifier otherwise starts from an empty list with
  /// nothing to fall back to when the network call that follows fails.
  Future<void> _loadFromCacheThenRefresh() async {
    try {
      final cached = await cache.getCachedChats();
      if (cached.isNotEmpty && mounted) {
        state = state.copyWith(status: InboxLoadStatus.loaded, chats: _sorted(cached));
      }
    } catch (_) {
      // Best-effort — refresh() below is still the source of truth.
    }
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(status: InboxLoadStatus.loading);
    try {
      final result = await repository.getChats(filter: state.filter, search: state.search);
      state = state.copyWith(
        status: InboxLoadStatus.loaded,
        chats: _sorted(result.chats),
        blockedUserIds: result.blockedUserIds,
      );
      _healAllChats(result.chats);
      unawaited(cache.cacheChats(result.chats));
    } on ApiException catch (e) {
      // Deliberately does not touch `chats` — copyWith keeps whatever's
      // already in state (cache-loaded or from a previous successful
      // refresh) instead of blanking the list out from under the user just
      // because this one refresh failed (e.g. no connectivity).
      state = state.copyWith(status: InboxLoadStatus.error, error: e.message);
    }
  }

  /// Proactively reseals every chat's key (wherever this device already
  /// holds one) to any participant device missing a grant — turns "the next
  /// message someone sends repairs a reinstalled device" into "the next
  /// time *anyone* opens the app repairs it." Cheap: healMissingGrants
  /// no-ops immediately for any chat this device doesn't hold a key for.
  void _healAllChats(List<Chat> chats) {
    for (final chat in chats) {
      unawaited(e2ee.healMissingGrants(chat.id).catchError((_) {}));
    }
  }

  void setFilter(InboxFilter filter) {
    state = state.copyWith(filter: filter);
    refresh();
  }

  void setSearch(String query) {
    state = state.copyWith(search: query);
    refresh();
  }

  Future<void> toggleMute(String chatId) async {
    final muted = await repository.toggleMute(chatId);
    state = state.copyWith(
      chats: state.chats
          .map((c) => c.id == chatId ? c.copyWith(isMuted: muted) : c)
          .toList(),
    );
  }

  /// Optimistically zeroes a chat's unread count the moment the user opens
  /// it, so the inbox row and tab badge don't wait for a full [refresh] to
  /// catch up with the mark-read call ChatDetailNotifier makes separately.
  void markChatRead(String chatId) {
    final idx = state.chats.indexWhere((c) => c.id == chatId);
    if (idx == -1 || state.chats[idx].unreadCount == 0) return;
    final list = [...state.chats];
    list[idx] = list[idx].copyWith(unreadCount: 0);
    state = state.copyWith(chats: list);
  }

  Future<void> deleteChat(String chatId) async {
    await repository.deleteChat(chatId);
    state = state.copyWith(chats: state.chats.where((c) => c.id != chatId).toList());
    unawaited(cache.deleteChat(chatId));
  }

  List<Chat> _sorted(List<Chat> chats) {
    final list = [...chats];
    list.sort((a, b) {
      final at = a.lastMessage?.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastMessage?.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return list;
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!event.channelName.contains(myUserId)) return;
    switch (event.eventName) {
      case RealtimeEventNames.messageSent:
        _onMessageSent(event);
        break;
      case RealtimeEventNames.userTyping:
        _onUserTyping(event);
        break;
      case RealtimeEventNames.messagesRead:
        _onMessagesRead(event);
        break;
    }
  }

  /// Flips the inbox row's tick to "read" the moment the recipient reads a
  /// chat, even while sitting on this tab rather than that specific chat —
  /// mirrors the tick update ChatDetailNotifier already does for an open chat.
  void _onMessagesRead(RealtimeEvent event) {
    final ids = (event.data['message_ids'] as List? ?? []).map((e) => e.toString()).toSet();
    if (ids.isEmpty) return;
    final idx = state.chats.indexWhere((c) => c.lastMessage != null && ids.contains(c.lastMessage!.id));
    if (idx == -1) return;
    final list = [...state.chats];
    list[idx] = list[idx].copyWith(lastMessage: list[idx].lastMessage!.copyWith(isReadByRecipient: true));
    state = state.copyWith(chats: list);
  }

  Future<void> _onMessageSent(RealtimeEvent event) async {
    final messageJson = event.data['message'];
    if (messageJson is! Map) return;
    // Same decrypt-at-the-boundary rule as MessagesRepository/ChatsRepository
    // — this preview comes straight off the socket, bypassing both, so it
    // has to decrypt for itself before the snippet reaches state/UI.
    final message = await decryptChatMessage(
      e2ee,
      ChatMessage.fromJson(Map<String, dynamic>.from(messageJson)),
    );
    final idx = state.chats.indexWhere((c) => c.id == message.chatId);
    if (idx == -1) {
      // A new chat we don't have cached yet (first message in/out) — pull
      // the fresh list rather than trying to synthesize a Chat from a
      // bare message payload.
      refresh();
      return;
    }
    final existing = state.chats[idx];
    final isMine = message.senderId == myUserId;
    final updated = existing.copyWith(
      lastMessage: message,
      unreadCount: isMine ? existing.unreadCount : existing.unreadCount + 1,
    );
    final list = [...state.chats]..removeAt(idx);
    list.insert(0, updated);
    state = state.copyWith(chats: list);
    unawaited(cache.cacheChats([updated]));
  }

  void _onUserTyping(RealtimeEvent event) {
    final chatId = event.data['chat_id']?.toString();
    final userId = event.data['user_id']?.toString();
    final isTyping = event.data['is_typing'] == true;
    if (chatId == null || userId == null || userId == myUserId) return;
    final updated = {...state.typingChatIds};
    isTyping ? updated.add(chatId) : updated.remove(chatId);
    state = state.copyWith(typingChatIds: updated);
  }

  void disposeSubscription() => _sub?.cancel();
}
