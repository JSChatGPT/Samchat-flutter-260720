import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cache/chat_cache_service.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/realtime/pusher_service.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../models/chat.dart';
import '../../../models/message.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/messages_repository.dart';

const _uuid = Uuid();

class ChatDetailState {
  const ChatDetailState({
    this.chat,
    this.messages = const [],
    this.isLoadingInitial = true,
    this.isLoadingMore = false,
    this.hasMoreOlder = false,
    this.currentPage = 1,
    this.typingUserIds = const {},
    this.error,
  });

  final Chat? chat;
  final List<ChatMessage> messages;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMoreOlder;
  final int currentPage;
  final Set<String> typingUserIds;
  final String? error;

  bool get canSend => chat == null || (!chat!.isBlocked && !chat!.blockedByMe);

  ChatDetailState copyWith({
    Chat? chat,
    List<ChatMessage>? messages,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMoreOlder,
    int? currentPage,
    Set<String>? typingUserIds,
    String? error,
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      currentPage: currentPage ?? this.currentPage,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      error: error,
    );
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(dioProvider), ref.watch(e2eeServiceProvider));
});

final chatDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatDetailNotifier, ChatDetailState, String>((ref, chatId) {
  final notifier = ChatDetailNotifier(
    chatId: chatId,
    repository: ref.watch(messagesRepositoryProvider),
    pusher: ref.watch(pusherServiceProvider),
    myUserId: ref.watch(currentUserIdProvider),
    e2ee: ref.watch(e2eeServiceProvider),
    cache: ref.watch(chatCacheServiceProvider),
  );
  ref.onDispose(notifier.disposeSubscription);
  return notifier;
});

class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  ChatDetailNotifier({
    required this.chatId,
    required this.repository,
    required this.pusher,
    required this.myUserId,
    required this.e2ee,
    required this.cache,
  }) : super(const ChatDetailState()) {
    pusher.subscribe(RealtimeChannels.chat(chatId));
    _sub = pusher.events.listen(_onRealtimeEvent);
    _loadInitial();
  }

  final String chatId;
  final MessagesRepository repository;
  final PusherService pusher;
  final String myUserId;
  final E2eeService e2ee;
  final ChatCacheService cache;
  StreamSubscription? _sub;
  Timer? _typingStopTimer;
  bool _iAmTyping = false;

  Future<void> _loadInitial() async {
    // Paints instantly from the local cache (no network round trip) before
    // ever attempting the real fetch below — the only thing that makes
    // reopening a chat while offline show its already-seen history instead
    // of a blank/error screen.
    try {
      final cachedChat = await cache.getCachedChat(chatId);
      final cachedMessages = await cache.getCachedMessages(chatId);
      if (mounted && cachedMessages.isNotEmpty) {
        state = state.copyWith(
          chat: cachedChat,
          messages: [...cachedMessages.reversed],
          isLoadingInitial: false,
          hasMoreOlder: true,
        );
      }
    } catch (_) {
      // Best-effort — the network fetch below is still the source of truth.
    }

    try {
      final result = await repository.getChatDetail(chatId, page: 1);
      // autoDispose: backing out of this chat while the initial load is
      // still in flight disposes the notifier before the response lands —
      // setting state afterward throws "Tried to use X after dispose was
      // called" instead of just being a harmless no-op.
      if (!mounted) return;
      final ordered = [...result.messages.items.reversed];
      state = state.copyWith(
        chat: result.chat,
        messages: ordered,
        isLoadingInitial: false,
        hasMoreOlder: result.messages.hasMore,
        currentPage: result.messages.currentPage,
      );
      // Opportunistically reseals this chat's key to any participant
      // device that's missing a grant (a reinstalled/new phone) — turns
      // "the next message someone sends repairs it" into "the next time
      // *anyone* opens this chat repairs it," closing the liveness gap
      // where the realtime grant-request only works if another key-holder
      // happens to be online at that exact moment. No-op if this device
      // doesn't hold the chat's key itself.
      unawaited(e2ee.healMissingGrants(chatId).catchError((_) {}));
      unawaited(cache.cacheMessages(chatId, result.messages.items));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Only surface the error state if there's genuinely nothing to show
      // (isLoadingInitial is already false above if the cache branch
      // painted something) — otherwise silently keep the cached view
      // rather than replacing it with an error banner just because this
      // one network attempt failed (e.g. no connectivity).
      if (state.messages.isEmpty) {
        state = state.copyWith(isLoadingInitial: false, error: e.message);
      }
    }
  }

  Future<void> loadMoreOlder() async {
    if (state.isLoadingMore || !state.hasMoreOlder) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await repository.getChatDetail(chatId, page: state.currentPage + 1);
      if (!mounted) return;
      final older = [...result.messages.items.reversed];
      state = state.copyWith(
        messages: [...older, ...state.messages],
        isLoadingMore: false,
        hasMoreOlder: result.messages.hasMore,
        currentPage: result.messages.currentPage,
      );
      unawaited(cache.cacheMessages(chatId, result.messages.items));
    } on ApiException {
      if (!mounted) return;
      // Offline fallback: page further back through whatever's already
      // cached from a previous session rather than just giving up —
      // matches the "already loaded messages stay viewable" goal for
      // scroll-up pagination too, not just the first page.
      final oldestLoadedMillis =
          state.messages.isNotEmpty ? state.messages.first.createdAt.millisecondsSinceEpoch : null;
      try {
        final olderCached = oldestLoadedMillis != null
            ? await cache.getCachedMessages(chatId, beforeMillis: oldestLoadedMillis)
            : const <ChatMessage>[];
        if (!mounted) return;
        state = state.copyWith(
          messages: [...olderCached.reversed, ...state.messages],
          isLoadingMore: false,
          hasMoreOlder: olderCached.isNotEmpty,
        );
      } catch (_) {
        if (!mounted) return;
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  Future<void> sendMessage({
    required MessageType type,
    String? content,
    String? attachmentPath,
    Map<String, dynamic>? metadata,
    String? quotedMessageId,
  }) async {
    final tempId = _uuid.v4();
    final optimistic = ChatMessage(
      id: tempId,
      chatId: chatId,
      senderId: myUserId,
      messageType: type,
      content: content,
      createdAt: DateTime.now(),
      sendStatus: SendStatus.sending,
      clientTempId: tempId,
      quotedMessageId: quotedMessageId,
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);
    try {
      final sent = await repository.sendMessage(
        chatId: chatId,
        type: type,
        content: content,
        attachmentPath: attachmentPath,
        metadata: metadata,
        quotedMessageId: quotedMessageId,
      );
      final replacement = sent.copyWith(sendStatus: SendStatus.sent);
      _replaceMessage(tempId, replacement);
      unawaited(cache.cacheMessage(replacement));
    } catch (_) {
      _replaceMessage(tempId, optimistic.copyWith(sendStatus: SendStatus.failed));
    }
  }

  /// Toggle semantics mirror the backend (`ChatController::reactToMessage`):
  /// tapping the same emoji again removes my reaction, tapping a different
  /// one replaces it. Optimistic locally, then reconciled with the server's
  /// authoritative reactions list once the request resolves.
  Future<void> toggleReaction(ChatMessage message, String emoji) async {
    final existing = message.reactions.where((r) => r.userId == myUserId).firstOrNull;
    final optimistic = [...message.reactions.where((r) => r.userId != myUserId)];
    if (existing?.emoji != emoji) {
      optimistic.add(MessageReaction(userId: myUserId, emoji: emoji));
    }
    _updateMessageReactions(message.id, optimistic);
    try {
      final serverReactions = await repository.react(message.id, emoji);
      _updateMessageReactions(message.id, serverReactions);
    } on ApiException {
      // Revert to the pre-optimistic state on failure.
      _updateMessageReactions(message.id, message.reactions);
    }
  }

  void _updateMessageReactions(String messageId, List<MessageReaction> reactions) {
    if (!mounted) return;
    ChatMessage? updatedMessage;
    final messages = state.messages.map((m) {
      if (m.id != messageId) return m;
      updatedMessage = m.copyWith(reactions: reactions);
      return updatedMessage!;
    }).toList();
    state = state.copyWith(messages: messages);
    if (updatedMessage != null) unawaited(cache.cacheMessage(updatedMessage!));
  }

  Future<void> deleteMessage(ChatMessage message, {required bool forEveryone}) async {
    try {
      await repository.deleteMessage(message.id, forEveryone: forEveryone);
      _removeMessage(message.id);
      unawaited(cache.deleteMessage(message.id));
    } on ApiException {
      // Leave the message in place if the delete request failed.
    }
  }

  Future<void> clearChat() async {
    try {
      await repository.clearChat(chatId);
      if (!mounted) return;
      state = state.copyWith(messages: const []);
      unawaited(cache.clearMessagesForChat(chatId));
    } on ApiException {
      // No-op — surfacing a toast is the screen's responsibility if desired.
    }
  }

  Future<void> retry(ChatMessage failed) async {
    _removeMessage(failed.id);
    await sendMessage(
      type: failed.messageType,
      content: failed.content,
      quotedMessageId: failed.quotedMessageId,
    );
  }

  void _replaceMessage(String tempId, ChatMessage replacement) {
    // autoDispose: covers every caller that only reaches this after an
    // await (sendMessage's response/failure) — the chat may already be
    // closed (and this notifier disposed) by the time that resolves.
    if (!mounted) return;
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == tempId ? replacement : m).toList(),
    );
  }

  void _removeMessage(String id) {
    if (!mounted) return;
    state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
  }

  /// Appends an already-created message straight from a REST response —
  /// for flows that create a message outside of [sendMessage] (e.g. Sampay
  /// payment requests, which POST directly to their own endpoint). The
  /// server excludes the sender from the MessageSent broadcast (matching
  /// `sendMessage`'s "the sender's own bubble already came from the REST
  /// response" rule), so without this the sender wouldn't see their own
  /// payment request until the chat was reopened and re-fetched from the
  /// server.
  void addSentMessage(ChatMessage message) {
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void onComposerTextChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    if (hasText && !_iAmTyping) {
      _iAmTyping = true;
      repository.setTyping(chatId, true);
    }
    _typingStopTimer?.cancel();
    if (hasText) {
      _typingStopTimer = Timer(const Duration(seconds: 2), () {
        _iAmTyping = false;
        repository.setTyping(chatId, false);
      });
    } else if (_iAmTyping) {
      _iAmTyping = false;
      repository.setTyping(chatId, false);
    }
  }

  Future<void> _onRealtimeEvent(RealtimeEvent event) async {
    if (event.channelName != RealtimeChannels.chat(chatId)) return;

    switch (event.eventName) {
      case RealtimeEventNames.messageSent:
        final json = event.data['message'];
        if (json is! Map) return;
        // Same decrypt-at-the-boundary rule as the repository's REST paths —
        // this event bypasses MessagesRepository entirely, so it has to
        // decrypt for itself before the message ever reaches state/UI.
        final message = await repository.decryptIfNeeded(
          ChatMessage.fromJson(Map<String, dynamic>.from(json), fallbackChatId: chatId),
        );
        if (!mounted) return;
        final existingIndex = state.messages.indexWhere((m) => m.id == message.id);
        if (existingIndex != -1) {
          // Update to an already-known message (e.g. a Sampay payment_request
          // status transition) — apply regardless of sender.
          final updated = [...state.messages];
          updated[existingIndex] = message;
          state = state.copyWith(messages: updated);
          unawaited(cache.cacheMessage(message));
          return;
        }
        // A brand-new message. The sender's own bubble already came from the
        // REST response of sendMessage() — avoid a duplicate insert from the
        // echoed broadcast.
        if (message.senderId == myUserId) return;
        state = state.copyWith(messages: [...state.messages, message]);
        repository.markRead(message.id);
        unawaited(cache.cacheMessage(message));
        break;
      case RealtimeEventNames.messagesRead:
        final ids = (event.data['message_ids'] as List? ?? []).map((e) => e.toString()).toSet();
        if (ids.isEmpty) return;
        state = state.copyWith(
          messages: state.messages
              .map((m) => ids.contains(m.id) ? m.copyWith(isReadByRecipient: true) : m)
              .toList(),
        );
        break;
      case RealtimeEventNames.userTyping:
        final userId = event.data['user_id']?.toString();
        final isTyping = event.data['is_typing'] == true;
        if (userId == null || userId == myUserId) return;
        final updated = {...state.typingUserIds};
        isTyping ? updated.add(userId) : updated.remove(userId);
        state = state.copyWith(typingUserIds: updated);
        break;
      case RealtimeEventNames.messageReactionUpdated:
        final messageId = event.data['message_id']?.toString();
        final reactionsRaw = event.data['reactions'];
        if (messageId == null || reactionsRaw is! List) return;
        final reactions = reactionsRaw
            .whereType<Map>()
            .map((e) => MessageReaction.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _updateMessageReactions(messageId, reactions);
        break;
    }
  }

  void disposeSubscription() {
    _sub?.cancel();
    _typingStopTimer?.cancel();
    if (_iAmTyping) repository.setTyping(chatId, false);
    pusher.unsubscribe(RealtimeChannels.chat(chatId));
  }
}
