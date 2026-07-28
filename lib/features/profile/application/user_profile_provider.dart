import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user.dart';
import '../../settings/application/profile_notifier.dart';

/// The read-only "tap a name/avatar to view this person" screen's data —
/// see ProfileRepository.getUserProfile / UserController::show for exactly
/// which fields are exposed about someone who isn't the signed-in user.
final userProfileProvider =
    FutureProvider.autoDispose.family<({AppUser user, int sharedGroupsCount}), String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).getUserProfile(userId);
});

/// Whether the *viewer* currently has this user blocked — derived from the
/// same blocked-list endpoint the Settings > Blocked users screen uses,
/// since `AppUser.isBlocked` is a different, platform-level flag (see
/// BlockController vs. the `is_blocked` column) and would answer the wrong
/// question here.
final isUserBlockedProvider = FutureProvider.autoDispose.family<bool, String>((ref, userId) async {
  final blocked = await ref.watch(profileRepositoryProvider).getBlockedUsers();
  return blocked.any((u) => u.id == userId);
});
