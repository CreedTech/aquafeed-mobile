import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/verify_otp_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/formulation/presentation/formulation_screen.dart';
import '../../features/formulation/presentation/quick_formulation_screen.dart';
import '../../features/payment/presentation/wallet_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter goRouter(Ref ref) {
  final userAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      // If user is loading, don't redirect yet
      if (userAsync.isLoading) return null;

      final user = userAsync.value;
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify-otp';

      if (user == null) {
        // Not logged in -> redirect to login unless already there
        return loggingIn ? null : '/login';
      }

      // Logged in -> redirect to dashboard if on login screen
      if (loggingIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String;
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/formulation',
        builder: (context, state) {
          final stepStr = state.uri.queryParameters['step'];
          final step = int.tryParse(stepStr ?? '0') ?? 0;
          return FormulationScreen(initialStep: step);
        },
      ),
      GoRoute(
        path: '/quick-formulation',
        builder: (context, state) => const QuickFormulationScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
    ],
  );
}
