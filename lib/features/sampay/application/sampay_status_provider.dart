import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../models/sampay_account.dart';
import '../data/sampay_repository.dart';

class SampayLinkState {
  const SampayLinkState({this.loading = true, this.isLinked = false, this.account, this.error});

  final bool loading;
  final bool isLinked;
  final SampayAccount? account;
  final String? error;

  SampayLinkState copyWith({bool? loading, bool? isLinked, SampayAccount? account, String? error}) {
    return SampayLinkState(
      loading: loading ?? this.loading,
      isLinked: isLinked ?? this.isLinked,
      account: account ?? this.account,
      error: error,
    );
  }
}

final sampayRepositoryProvider = Provider<SampayRepository>((ref) {
  return SampayRepository(ref.watch(dioProvider));
});

final sampayStatusProvider = StateNotifierProvider<SampayStatusNotifier, SampayLinkState>((ref) {
  return SampayStatusNotifier(ref.watch(sampayRepositoryProvider));
});

class SampayStatusNotifier extends StateNotifier<SampayLinkState> {
  SampayStatusNotifier(this.repository) : super(const SampayLinkState()) {
    _ready = refresh();
  }

  final SampayRepository repository;
  late final Future<void> _ready;

  /// Resolves once the initial status fetch has completed, so callers that
  /// need a definitive `isLinked` value right after the provider is first
  /// created (e.g. on the very first tap of a Sampay action) can await this
  /// instead of racing the constructor's fire-and-forget refresh().
  Future<void> get ready => _ready;

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final result = await repository.getStatus();
      state = state.copyWith(loading: false, isLinked: result.isLinked, account: result.account);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> unlink() async {
    await repository.unlink();
    state = const SampayLinkState(loading: false, isLinked: false);
  }
}
