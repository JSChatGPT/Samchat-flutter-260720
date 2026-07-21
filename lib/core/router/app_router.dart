import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../native/app_intent_channel.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/calls/presentation/screens/call_history_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/chat_detail/presentation/screens/chat_detail_screen.dart';
import '../../features/chats/presentation/screens/inbox_screen.dart';
import '../../features/chats/presentation/screens/share_target_screen.dart';
import '../../features/email/presentation/screens/email_accounts_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/group_info_screen.dart';
import '../../features/home_shell/presentation/home_shell_screen.dart';
import '../../features/meetings/presentation/screens/meeting_list_screen.dart';
import '../../features/meetings/presentation/screens/schedule_meeting_screen.dart';
import '../../features/onboarding_contacts/presentation/screens/contact_picker_screen.dart';
import '../../features/sampay/presentation/screens/sampay_home_screen.dart';
import '../../features/sampay/presentation/screens/sampay_link_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/app_lock_settings_screen.dart';
import '../../features/settings/presentation/screens/blocked_users_screen.dart';
import '../../features/settings/presentation/screens/privacy_settings_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/settings_home_screen.dart';
import '../../features/sms/application/sms_notifier.dart';
import '../../features/sms/presentation/screens/sms_inbox_screen.dart';
import '../../features/sms/presentation/screens/sms_thread_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/statuses/presentation/screens/status_create_screen.dart';
import '../../features/statuses/presentation/screens/status_list_screen.dart';
import '../../features/statuses/presentation/screens/status_viewer_screen.dart';
import '../../features/statuses/presentation/screens/status_views_screen.dart';
import '../../models/status.dart';
import 'go_router_refresh_stream.dart';
import 'route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      final onAuthStack = loc == RoutePaths.phoneEntry ||
          loc == RoutePaths.register ||
          loc == RoutePaths.otpVerify;

      if (authState.status == AuthStatus.unknown) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return onAuthStack ? null : RoutePaths.phoneEntry;
      }
      // authenticated
      if (onAuthStack || loc == RoutePaths.splash) return RoutePaths.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.phoneEntry,
        name: RouteNames.phoneEntry,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        builder: (context, state) => RegisterScreen(initialPhone: state.extra as String?),
      ),
      GoRoute(
        path: RoutePaths.otpVerify,
        name: RouteNames.otpVerify,
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: RoutePaths.chatDetail,
        name: RouteNames.chatDetail,
        builder: (context, state) =>
            ChatDetailScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: RoutePaths.contactPicker,
        name: RouteNames.contactPicker,
        builder: (context, state) => const ContactPickerScreen(),
      ),
      GoRoute(
        path: RoutePaths.createGroup,
        name: RouteNames.createGroup,
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: RoutePaths.groupInfo,
        name: RouteNames.groupInfo,
        builder: (context, state) => GroupInfoScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: RoutePaths.statusViewer,
        name: RouteNames.statusViewer,
        builder: (context, state) => StatusViewerScreen(statuses: state.extra as List<StatusItem>),
      ),
      GoRoute(
        path: RoutePaths.statusCreate,
        name: RouteNames.statusCreate,
        builder: (context, state) => const StatusCreateScreen(),
      ),
      GoRoute(
        path: RoutePaths.statusViews,
        name: RouteNames.statusViews,
        builder: (context, state) => StatusViewsScreen(statusId: state.extra as String),
      ),
      GoRoute(
        path: RoutePaths.outgoingCall,
        name: RouteNames.outgoingCall,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CallScreen(
            outgoingReceiverId: extra['receiverId'] as String?,
            outgoingChatId: extra['chatId'] as String?,
            outgoingVideo: extra['video'] as bool,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.incomingCall,
        name: RouteNames.incomingCall,
        builder: (context, state) => const CallScreen(),
      ),
      GoRoute(
        path: RoutePaths.sampayLink,
        name: RouteNames.sampayLink,
        builder: (context, state) => SampayLinkScreen(authorizationUrl: state.extra as String),
      ),
      GoRoute(
        path: RoutePaths.profileEdit,
        name: RouteNames.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacySettings,
        name: RouteNames.privacySettings,
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.appLockSettings,
        name: RouteNames.appLockSettings,
        builder: (context, state) => const AppLockSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.blockedUsers,
        name: RouteNames.blockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.sampay,
        name: RouteNames.sampay,
        builder: (context, state) => const SampayHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.meetings,
        name: RouteNames.meetings,
        builder: (context, state) => const MeetingListScreen(),
      ),
      GoRoute(
        path: RoutePaths.scheduleMeeting,
        name: RouteNames.scheduleMeeting,
        builder: (context, state) => const ScheduleMeetingScreen(),
      ),
      GoRoute(
        path: RoutePaths.smsThread,
        name: RouteNames.smsThread,
        builder: (context, state) => SmsThreadScreen(args: state.extra as SmsThreadArgs),
      ),
      GoRoute(
        path: RoutePaths.shareTarget,
        name: RouteNames.shareTarget,
        builder: (context, state) => ShareTargetScreen(intent: state.extra as AppIntent),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.chats,
              name: RouteNames.chats,
              builder: (context, state) => const InboxScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.statuses,
              name: RouteNames.statuses,
              builder: (context, state) => const StatusListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.calls,
              name: RouteNames.calls,
              builder: (context, state) => const CallHistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.smsInbox,
              name: RouteNames.smsInbox,
              builder: (context, state) => const SmsInboxScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.emailAccounts,
              name: RouteNames.emailAccounts,
              builder: (context, state) => const EmailAccountsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
