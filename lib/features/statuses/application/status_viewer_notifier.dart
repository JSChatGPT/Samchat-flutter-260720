import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/status.dart';
import '../data/statuses_repository.dart';
import 'statuses_notifier.dart';

class StatusViewerState {
  const StatusViewerState({required this.statuses, this.index = 0, this.progress = 0, this.finished = false});

  final List<StatusItem> statuses;
  final int index;
  final double progress; // 0..1 within the current item
  final bool finished;

  StatusItem? get current => index < statuses.length ? statuses[index] : null;

  StatusViewerState copyWith({int? index, double? progress, bool? finished}) {
    return StatusViewerState(
      statuses: statuses,
      index: index ?? this.index,
      progress: progress ?? this.progress,
      finished: finished ?? this.finished,
    );
  }
}

/// Drives the auto-advancing full-screen story viewer for one poster's
/// statuses (5s for text/image, 15s for video, per API_DOCUMENTATION §8).
final statusViewerNotifierProvider = StateNotifierProvider.autoDispose
    .family<StatusViewerNotifier, StatusViewerState, List<StatusItem>>((ref, statuses) {
  final notifier = StatusViewerNotifier(statuses: statuses, repository: ref.watch(statusesRepositoryProvider));
  ref.onDispose(notifier.disposeTimer);
  return notifier;
});

class StatusViewerNotifier extends StateNotifier<StatusViewerState> {
  StatusViewerNotifier({required List<StatusItem> statuses, required this.repository})
      : super(StatusViewerState(statuses: statuses)) {
    _startCurrent();
  }

  final StatusesRepository repository;
  Timer? _ticker;
  static const _tickInterval = Duration(milliseconds: 50);
  Duration _elapsed = Duration.zero;

  void _startCurrent() {
    final item = state.current;
    if (item == null) {
      state = state.copyWith(finished: true);
      return;
    }
    repository.markViewed(item.id);
    _elapsed = Duration.zero;
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) {
      _elapsed += _tickInterval;
      final total = item.displayDuration.inMilliseconds;
      final progress = (_elapsed.inMilliseconds / total).clamp(0.0, 1.0);
      state = state.copyWith(progress: progress);
      if (progress >= 1.0) next();
    });
  }

  void next() {
    if (state.index + 1 >= state.statuses.length) {
      _ticker?.cancel();
      state = state.copyWith(finished: true);
      return;
    }
    state = state.copyWith(index: state.index + 1, progress: 0);
    _startCurrent();
  }

  void previous() {
    if (state.index == 0) return;
    state = state.copyWith(index: state.index - 1, progress: 0);
    _startCurrent();
  }

  void pause() => _ticker?.cancel();

  void resume() => _startCurrent();

  void disposeTimer() => _ticker?.cancel();
}
