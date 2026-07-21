import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

/// Whether the given user has an active status the current user hasn't
/// viewed yet — used to ring their avatar on a profile/contact-info screen.
final hasUnviewedStatusProvider = FutureProvider.autoDispose.family<bool, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).hasUnviewedStatus(userId);
});

enum ProfileSaveStatus { idle, saving, saved, error }

class ProfileEditState {
  const ProfileEditState({this.status = ProfileSaveStatus.idle, this.error});
  final ProfileSaveStatus status;
  final String? error;

  ProfileEditState copyWith({ProfileSaveStatus? status, String? error}) {
    return ProfileEditState(status: status ?? this.status, error: error);
  }
}

final profileEditNotifierProvider =
    StateNotifierProvider.autoDispose<ProfileEditNotifier, ProfileEditState>((ref) {
  return ProfileEditNotifier(
    repository: ref.watch(profileRepositoryProvider),
    authNotifier: ref.watch(authNotifierProvider.notifier),
  );
});

class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  ProfileEditNotifier({required this.repository, required this.authNotifier})
      : super(const ProfileEditState());

  final ProfileRepository repository;
  final AuthNotifier authNotifier;

  Future<bool> save({
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? username,
    String? aboutStatus,
    String? photoPath,
  }) async {
    state = state.copyWith(status: ProfileSaveStatus.saving);
    try {
      final user = await repository.updateProfile(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        email: email,
        username: username,
        aboutStatus: aboutStatus,
        photoPath: photoPath,
      );
      authNotifier.updateCurrentUser(user);
      if (!mounted) return true;
      state = state.copyWith(status: ProfileSaveStatus.saved);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(status: ProfileSaveStatus.error, error: '$e');
      return false;
    }
  }
}
