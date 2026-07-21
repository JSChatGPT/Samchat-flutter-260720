import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import 'profile_notifier.dart';

class PrivacyState {
  const PrivacyState({this.loading = true, this.privacy = 'everyone', this.list = const []});

  final bool loading;
  final String privacy;
  final List<String> list;

  PrivacyState copyWith({bool? loading, String? privacy, List<String>? list}) {
    return PrivacyState(
      loading: loading ?? this.loading,
      privacy: privacy ?? this.privacy,
      list: list ?? this.list,
    );
  }
}

final privacyNotifierProvider = StateNotifierProvider<PrivacyNotifier, PrivacyState>((ref) {
  return PrivacyNotifier(ref.watch(profileRepositoryProvider));
});

class PrivacyNotifier extends StateNotifier<PrivacyState> {
  PrivacyNotifier(this.repository) : super(const PrivacyState()) {
    refresh();
  }

  final ProfileRepository repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final result = await repository.getPrivacy();
    state = state.copyWith(loading: false, privacy: result.privacy, list: result.list);
  }

  Future<void> setPrivacy(String privacy, {List<String>? list}) async {
    await repository.setPrivacy(privacy: privacy, list: list);
    state = state.copyWith(privacy: privacy, list: list ?? const []);
  }
}
