import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/discover/strain_detail_screen.dart';
import '../screens/discover/dispensary_detail_screen.dart';
import '../screens/circles/circles_screen.dart';
import '../screens/circles/circle_detail_screen.dart';
import '../screens/circles/create_circle_screen.dart';
import '../screens/circles/share_to_circle_screen.dart';
import '../screens/circles/join_circle_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/dispensary/add_dispensary_screen.dart';
import '../screens/strain/add_strain_screen.dart';
import '../screens/session/log_session_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _homeKey = GlobalKey<NavigatorState>();
final _discoverKey = GlobalKey<NavigatorState>();
final _circlesKey = GlobalKey<NavigatorState>();
final _profileKey = GlobalKey<NavigatorState>();
final _settingsKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    // ── Global modal routes (float above all tabs) ──────────────────────────
    GoRoute(
      path: '/circles/join',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => JoinCircleScreen(
        circleId: state.uri.queryParameters['id'] ?? '',
        token: state.uri.queryParameters['token'] ?? '',
      ),
    ),
    GoRoute(
      path: '/circles/create',
      parentNavigatorKey: _rootKey,
      builder: (context, _) => const CreateCircleScreen(),
    ),
    GoRoute(
      path: '/circles/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => CircleDetailScreen(circleId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'share',
          builder: (context, state) => ShareToCircleScreen(
            circleId: state.pathParameters['id']!,
            preloadType: state.uri.queryParameters['type'],
            preloadName: state.uri.queryParameters['name'],
            preloadSub: state.uri.queryParameters['sub'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/share',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => ShareToCircleScreen(
        preloadType: state.uri.queryParameters['type'],
        preloadName: state.uri.queryParameters['name'],
        preloadSub: state.uri.queryParameters['sub'],
      ),
    ),
    GoRoute(
      path: '/add-dispensary',
      parentNavigatorKey: _rootKey,
      builder: (context, _) => const AddDispensaryScreen(),
    ),
    GoRoute(
      path: '/add-strain',
      parentNavigatorKey: _rootKey,
      builder: (context, _) => const AddStrainScreen(),
    ),
    GoRoute(
      path: '/log-session',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => LogSessionScreen(
        preloadStrainId: state.uri.queryParameters['strainId'],
        sessionId: state.uri.queryParameters['sessionId'],
      ),
    ),

    // ── Tab shell ────────────────────────────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeKey,
          routes: [GoRoute(path: '/home', builder: (context, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          navigatorKey: _discoverKey,
          routes: [
            GoRoute(
              path: '/discover',
              builder: (context, _) => const DiscoverScreen(),
              routes: [
                GoRoute(
                  path: 'strain/:id',
                  builder: (context, state) => StrainDetailScreen(strainId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'dispensary/:id',
                  builder: (context, state) => DispensaryDetailScreen(dispensaryId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => AddDispensaryScreen(dispensaryId: state.pathParameters['id']),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _circlesKey,
          routes: [GoRoute(path: '/circles', builder: (context, _) => const CirclesScreen())],
        ),
        StatefulShellBranch(
          navigatorKey: _profileKey,
          routes: [GoRoute(path: '/profile', builder: (context, _) => const ProfileScreen())],
        ),
        StatefulShellBranch(
          navigatorKey: _settingsKey,
          routes: [GoRoute(path: '/settings', builder: (context, _) => const SettingsScreen())],
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
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
