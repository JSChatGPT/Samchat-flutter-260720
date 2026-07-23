import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/widgets/count_badge.dart';
import '../../chats/application/inbox_notifier.dart';
import '../../email/application/email_notifier.dart';
import '../../settings/application/theme_mode_notifier.dart';
import '../../sms/application/sms_notifier.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabCount = 6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCount,
      initialIndex: widget.navigationShell.currentIndex,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant HomeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController.index != widget.navigationShell.currentIndex) {
      _tabController.index = widget.navigationShell.currentIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.read(themeModeNotifierProvider.notifier).setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void _handleTabTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Widget _tabWithBadge(String text, int count) {
    if (count <= 0) return Tab(text: text);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          const SizedBox(width: 6),
          CountBadge(count: count, color: Colors.white, textColor: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadChatsCount = ref.watch(totalUnreadChatsCountProvider);
    final unreadSmsCount = ref.watch(totalUnreadSmsCountProvider);
    final unreadEmailCount = ref.watch(totalUnreadEmailCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Samchat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => ref.read(inboxSearchFocusRequestProvider.notifier).state++,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'New chat',
            onPressed: () => context.pushNamed(RouteNames.contactPicker),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.nightlight_round),
            tooltip: 'Toggle theme',
            onPressed: _toggleTheme,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'new_group':
                  context.pushNamed(RouteNames.createGroup);
                case 'meetings':
                  context.pushNamed(RouteNames.meetings);
                case 'sampay':
                  context.pushNamed(RouteNames.sampay);
                case 'settings':
                  context.pushNamed(RouteNames.settings);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new_group', child: Text('New group')),
              PopupMenuItem(value: 'meetings', child: Text('Meetings')),
              PopupMenuItem(value: 'sampay', child: Text('Sampay Payments')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              _tabWithBadge('CHATS', unreadChatsCount),
              const Tab(text: 'STATUS'),
              const Tab(text: 'GROUPS'),
              const Tab(text: 'CALLS'),
              _tabWithBadge('SMS', unreadSmsCount),
              _tabWithBadge('EMAIL', unreadEmailCount),
            ],
            onTap: _handleTabTap,
          ),
        ),
      ),
      body: widget.navigationShell,
    );
  }
}
