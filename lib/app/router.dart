import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/shell.dart';
import 'package:journal/features/accounts/connect_screens.dart';
import 'package:journal/features/analytics/analytics_screens.dart';
import 'package:journal/features/auth/lock_controller.dart';
import 'package:journal/features/auth/lock_screen.dart';
import 'package:journal/features/auth/setup_screen.dart';
import 'package:journal/features/auth/splash_onboarding.dart';
import 'package:journal/features/dashboard/home_screen.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/features/settings/more_screens.dart';
import 'package:journal/features/trades/trade_analysis_screen.dart';
import 'package:journal/features/trades/trade_screens.dart';

final _rootKey = GlobalKey<NavigatorState>();

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(
    journalProvider.select((s) => (s.ready, s.onboardingComplete)),
    (previous, next) => refresh.ping(),
  );
  ref.listen(
    lockProvider.select((s) => (s.ready, s.pinSet, s.unlocked)),
    (previous, next) => refresh.ping(),
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final journal = ref.read(journalProvider);
      final lock = ref.read(lockProvider);
      if (!journal.ready || !lock.ready) {
        return location == '/splash' ? null : '/splash';
      }
      if (!lock.pinSet || !journal.onboardingComplete) {
        return location == '/setup' ? null : '/setup';
      }
      if (!lock.unlocked) {
        return location == '/lock' ? null : '/lock';
      }
      if (location == '/splash' ||
          location == '/setup' ||
          location == '/lock' ||
          location == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(
        path: '/manual-trade',
        builder: (context, state) => const ManualTradeScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/trade/:id',
        builder: (context, state) =>
            TradeDetailScreen(tradeId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'journal',
            builder: (context, state) =>
                JournalScreen(tradeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ManualTradeScreen(tradeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'analysis',
            builder: (context, state) =>
                TradeAnalysisScreen(tradeId: state.pathParameters['id']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trades',
                builder: (context, state) => const TradesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
