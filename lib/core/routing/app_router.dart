import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_constants.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/room/presentation/screens/room_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RouteConstants.home,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final hasUser = authState.valueOrNull != null;
      final isLoggingIn = state.matchedLocation == RouteConstants.auth;

      if (isLoading) return null;

      if (!hasUser && !isLoggingIn) {
        return RouteConstants.auth;
      }

      if (hasUser && isLoggingIn) {
        return RouteConstants.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteConstants.auth,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.room,
        builder: (context, state) => RoomScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: RouteConstants.joinWithCode,
        builder: (context, state) => HomeScreen(
          initialJoinCode: state.pathParameters['code'],
        ),
      ),
    ],
  );
});
