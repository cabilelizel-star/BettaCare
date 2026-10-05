// ignore_for_file: type=lint
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

// BettaCare UI Screens
import '../screens/splash_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home_screen.dart';
import '../screens/my_betta_screen.dart';
import '../screens/care_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/profile_screen.dart';

// Auth screens
import '../screens/auth/landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/mfa_screen.dart';
import '../screens/auth/setup_owner_screen.dart';

// Owner screens
import '../screens/owner/owner_dashboard.dart';
import '../screens/owner/fish_profiles_screen.dart';
import '../screens/owner/feeding_schedule_screen.dart';
import '../screens/owner/care_logs_screen.dart';
import '../screens/owner/fish_listings_screen.dart';
import '../screens/owner/orders_screen.dart';
import '../screens/owner/cod_management_screen.dart';
import '../screens/owner/payment_management_screen.dart';
import '../screens/owner/reports_screen.dart';
import '../screens/owner/messages_screen.dart';
import '../screens/owner/breeding_screen.dart';
import '../screens/owner/schedule_screen.dart';
import '../screens/owner/settings_screen.dart';

// Customer screens
import '../screens/customer/customer_dashboard.dart';
import '../screens/customer/browse_fish_screen.dart';
import '../screens/customer/place_order_screen.dart';
import '../screens/customer/track_orders_screen.dart';
import '../screens/customer/order_tracking_screen.dart';
import '../screens/customer/customer_messages_screen.dart';
import '../screens/chat/chat_screen.dart';

GoRouter createRouter(AppAuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final loading = authProvider.loading;
      final path = state.uri.path;

      // Don't redirect while auth status is initializing
      if (loading) return null;

      // Let Splash Screen handle its own 2.5s timer before redirecting
      if (path == '/splash') return null;

      final publicRoutes = [
        '/splash',
        '/login',
        '/register',
        '/forgot-password',
        '/mfa',
        '/setup-owner',
        '/landing',
      ];
      final isPublic = publicRoutes.contains(path);

      // Unauthenticated user trying to access protected screen -> redirect to Login
      if (!loggedIn && !isPublic) {
        return '/login';
      }

      // Authenticated user on MFA verification or Login page -> redirect straight to Dashboard!
      if (loggedIn && (path == '/login' || path == '/mfa')) {
        return authProvider.isOwner ? '/owner/dashboard' : '/customer/dashboard';
      }

      // Role-Based Access Control
      if (loggedIn) {
        final isOwnerRoute = path.startsWith('/owner');
        final isCustomerRoute = path.startsWith('/customer');

        // Prevent Customer from accessing Admin/Owner screens
        if (isOwnerRoute && !authProvider.isOwner) {
          return '/customer/dashboard';
        }

        // Prevent Owner from accessing Customer-only screens
        if (isCustomerRoute && authProvider.isOwner) {
          return '/owner/dashboard';
        }
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Root path directs to splash screen
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth screens
      GoRoute(path: '/landing', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/mfa',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return MfaScreen(
            email:       extra?['email']    ?? '',
            password:    extra?['password'] ?? '',
            expectedOtp: extra?['otp'],
          );
        },
      ),
      GoRoute(path: '/setup-owner', builder: (context, state) => const SetupOwnerScreen()),

      // Main BettaCare Shell Route (Bottom Navigation)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/my-betta', builder: (context, state) => const MyBettaScreen()),
          GoRoute(path: '/care', builder: (context, state) => const CareScreen()),
          GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),

      // Owner/Admin screens
      GoRoute(path: '/owner/dashboard', builder: (context, state) => const OwnerDashboard()),
      GoRoute(path: '/owner/fish-profiles', builder: (context, state) => const FishProfilesScreen()),
      GoRoute(path: '/owner/feeding-schedule', builder: (context, state) => const FeedingScheduleScreen()),
      GoRoute(path: '/owner/care-logs', builder: (context, state) => const CareLogsScreen()),
      GoRoute(path: '/owner/fish-listings', builder: (context, state) => const FishListingsScreen()),
      GoRoute(path: '/owner/orders', builder: (context, state) => const OrdersScreen()),
      GoRoute(path: '/owner/breeding', builder: (context, state) => const BreedingScreen()),
      GoRoute(path: '/owner/schedule', builder: (context, state) => const ScheduleScreen()),
      GoRoute(path: '/owner/cod-management', builder: (context, state) => const CODManagementScreen()),
      GoRoute(path: '/owner/payment-management', builder: (context, state) => const PaymentManagementScreen()),
      GoRoute(path: '/owner/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/owner/messages', builder: (context, state) => const MessagesScreen()),
      GoRoute(path: '/owner/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/owner/chat/:chatId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            chatId: state.pathParameters['chatId']!,
            orderId: extra['orderId'] ?? '',
            fish: extra['fish'] ?? 'Order Chat',
            otherPartyName: extra['customerName'] ?? 'Customer',
            role: 'owner',
          );
        },
      ),

      // Customer screens
      GoRoute(path: '/customer/dashboard', builder: (context, state) => const CustomerDashboard()),
      GoRoute(path: '/customer/browse', builder: (context, state) => const BrowseFishScreen()),
      GoRoute(
        path: '/customer/place-order',
        builder: (context, state) {
          final fish = state.extra as Map<String, dynamic>?;
          return PlaceOrderScreen(fish: fish);
        },
      ),
      GoRoute(path: '/customer/orders', builder: (context, state) => const TrackOrdersScreen()),
      GoRoute(path: '/customer/messages', builder: (_, __) => const CustomerMessagesScreen()),
      GoRoute(
        path: '/customer/track/:orderId',
        builder: (context, state) => OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/customer/chat/:chatId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            chatId: state.pathParameters['chatId']!,
            orderId: extra['orderId'] ?? '',
            fish: extra['fish'] ?? 'Order Chat',
            otherPartyName: 'Owner',
            role: 'user',
          );
        },
      ),
    ],
  );
}
