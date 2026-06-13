import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/circles/circles_screen.dart';
import '../screens/profile/profile_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _homeKey = GlobalKey<NavigatorState>();
final _discoverKey = GlobalKey<NavigatorState>();
final _circlesKey = GlobalKey<NavigatorState>();
final _profileKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeKey,
          routes: [
            GoRoute(path: '/home', builder: (context, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _discoverKey,
          routes: [
            GoRoute(path: '/discover', builder: (context, _) => const DiscoverScreen()),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _circlesKey,
          routes: [
            GoRoute(path: '/circles', builder: (context, _) => const CirclesScreen()),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _profileKey,
          routes: [
            GoRoute(path: '/profile', builder: (context, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
