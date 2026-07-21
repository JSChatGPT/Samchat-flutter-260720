import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../models/status.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/statuses_repository.dart';

enum StatusesLoadState { loading, loaded, error }

class StatusesState {
  const StatusesState({
    this.loadState = StatusesLoadState.loading,
    this.myStatuses = const [],
    this.otherGroups = const [],
    this.error,
  });

  final StatusesLoadState loadState;
  final List<StatusItem> myStatuses;
  final List<StatusGroup> otherGroups;
  final String? error;

  StatusesState copyWith({
    StatusesLoadState? loadState,
    List<StatusItem>? myStatuses,
    List<StatusGroup>? otherGroups,
    String? error,
  }) {
    return StatusesState(
      loadState: loadState ?? this.loadState,
      myStatuses: myStatuses ?? this.myStatuses,
      otherGroups: otherGroups ?? this.otherGroups,
      error: error,
    );
  }
}

final statusesRepositoryProvider = Provider<StatusesRepository>((ref) {
  return StatusesRepository(ref.watch(dioProvider));
});

final statusesNotifierProvider = StateNotifierProvider<StatusesNotifier, StatusesState>((ref) {
  return StatusesNotifier(
    repository: ref.watch(statusesRepositoryProvider),
    myUserId: ref.watch(currentUserIdProvider),
  );
});

class StatusesNotifier extends StateNotifier<StatusesState> {
  StatusesNotifier({required this.repository, required this.myUserId}) : super(const StatusesState()) {
    refresh();
  }

  final StatusesRepository repository;
  final String myUserId;

  Future<void> refresh() async {
    state = state.copyWith(loadState: StatusesLoadState.loading);
    try {
      final groups = await repository.getStatuses();
      final mine = groups.where((g) => g.userId == myUserId).expand((g) => g.statuses).toList();
      final others = groups.where((g) => g.userId != myUserId).toList();
      state = state.copyWith(loadState: StatusesLoadState.loaded, myStatuses: mine, otherGroups: others);
    } on ApiException catch (e) {
      state = state.copyWith(loadState: StatusesLoadState.error, error: e.message);
    }
  }

  Future<void> deleteStatus(String id) async {
    await repository.deleteStatus(id);
    state = state.copyWith(myStatuses: state.myStatuses.where((s) => s.id != id).toList());
  }
}
