import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../models/meeting.dart';
import '../data/meetings_repository.dart';

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return MeetingsRepository(ref.watch(dioProvider));
});

enum MeetingsLoadStatus { loading, loaded, error }

class MeetingsState {
  const MeetingsState({this.status = MeetingsLoadStatus.loading, this.meetings = const [], this.error});

  final MeetingsLoadStatus status;
  final List<Meeting> meetings;
  final String? error;

  MeetingsState copyWith({MeetingsLoadStatus? status, List<Meeting>? meetings, String? error}) {
    return MeetingsState(
      status: status ?? this.status,
      meetings: meetings ?? this.meetings,
      error: error,
    );
  }
}

final meetingsNotifierProvider = StateNotifierProvider<MeetingsNotifier, MeetingsState>((ref) {
  return MeetingsNotifier(ref.watch(meetingsRepositoryProvider));
});

class MeetingsNotifier extends StateNotifier<MeetingsState> {
  MeetingsNotifier(this.repository) : super(const MeetingsState()) {
    refresh();
  }

  final MeetingsRepository repository;

  Future<void> refresh() async {
    state = state.copyWith(status: MeetingsLoadStatus.loading);
    try {
      final meetings = await repository.getMeetings()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      state = state.copyWith(status: MeetingsLoadStatus.loaded, meetings: meetings);
    } on ApiException catch (e) {
      state = state.copyWith(status: MeetingsLoadStatus.error, error: e.message);
    }
  }

  Future<void> respond(String meetingId, {required bool accept}) async {
    await repository.respond(meetingId, accept: accept);
    await refresh();
  }

  Future<void> start(String meetingId) => repository.start(meetingId);
}
