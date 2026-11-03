import 'package:flutter/material.dart';

import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/admin/analytics_screen.dart';
import '../../screens/admin/dashboard_screen.dart';
import '../../screens/admin/create_queue_screen.dart';
import '../../screens/admin/manage_queue_screen.dart';
import '../../screens/admin/queue_qr_screen.dart';
import '../../screens/app_initialization_error_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/user/history_screen.dart';
import '../../screens/user/home_screen.dart';
import '../../screens/user/profile_screen.dart';
import '../../screens/user/qr_scanner_screen.dart';
import '../../screens/user/queue_details_screen.dart';
import '../../screens/user/token_screen.dart';
import '../../models/queue_model.dart';

class AppRoutes {
  const AppRoutes._();

  static const String bootstrap = '/';
  static const String splash = '/splash';
  static const String initializationError = '/initialization-error';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String history = '/user/history';
  static const String profile = '/user/profile';
  static const String qrScanner = '/user/qr-scanner';
  static const String queueDetails = '/user/queue-details';
  static const String token = '/user/token';
  static const String adminDashboard = '/admin/dashboard';
  static const String createQueue = '/admin/create-queue';
  static const String manageQueue = '/admin/manage-queue';
  static const String queueQr = '/admin/queue-qr';
  static const String analytics = '/admin/analytics';

  static Map<String, WidgetBuilder> get routes => {
        bootstrap: (_) => const SplashScreen(),
        splash: (_) => const SplashScreen(),
        initializationError: (_) => const AppInitializationErrorScreen(),
        login: (_) => const LoginScreen(),
        signup: (_) => const SignUpScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        home: (_) => const HomeScreen(),
        history: (_) => const HistoryScreen(),
        profile: (_) => const ProfileScreen(),
        qrScanner: (_) => const QrScannerScreen(),
        adminDashboard: (_) => const DashboardScreen(),
        createQueue: (_) => const CreateQueueScreen(),
        analytics: (_) => const AnalyticsScreen(),
      };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case bootstrap:
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case initializationError:
        final error = settings.arguments is String
            ? settings.arguments! as String
            : null;
        return MaterialPageRoute<void>(
          builder: (_) => AppInitializationErrorScreen(error: error),
          settings: settings,
        );
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case signup:
        return MaterialPageRoute<void>(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute<void>(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case history:
        return MaterialPageRoute<void>(
          builder: (_) => const HistoryScreen(),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      case qrScanner:
        return MaterialPageRoute<void>(
          builder: (_) => const QrScannerScreen(),
          settings: settings,
        );
      case queueDetails:
        final arguments = settings.arguments;
        QueueModel? queue;
        bool showQrSuccessBanner = false;

        if (arguments is QueueModel) {
          queue = arguments;
        } else if (arguments is Map<String, dynamic>) {
          final candidate = arguments['queue'];
          if (candidate is QueueModel) {
            queue = candidate;
            showQrSuccessBanner = arguments['showQrSuccessBanner'] as bool? ?? false;
          }
        }

        if (queue == null) {
          return onUnknownRoute(settings);
        }
        return MaterialPageRoute<void>(
          builder: (_) => QueueDetailsScreen(
            queue: queue!,
            showQrSuccessBanner: showQrSuccessBanner,
          ),
          settings: settings,
        );
      case token:
        final queue = settings.arguments;
        if (queue is! QueueModel) {
          return onUnknownRoute(settings);
        }
        return MaterialPageRoute<void>(
          builder: (_) => TokenScreen(queue: queue),
          settings: settings,
        );
      case adminDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      case createQueue:
        return MaterialPageRoute<void>(
          builder: (_) => const CreateQueueScreen(),
          settings: settings,
        );
      case manageQueue:
        final queue = settings.arguments;
        if (queue is! QueueModel) {
          return onUnknownRoute(settings);
        }
        return MaterialPageRoute<bool?>(
          builder: (_) => ManageQueueScreen(queue: queue),
          settings: settings,
        );
      case queueQr:
        final queue = settings.arguments;
        if (queue is! QueueModel) {
          return onUnknownRoute(settings);
        }
        return MaterialPageRoute<void>(
          builder: (_) => QueueQrScreen(queue: queue),
          settings: settings,
        );
      case analytics:
        return MaterialPageRoute<void>(
          builder: (_) => const AnalyticsScreen(),
          settings: settings,
        );
      default:
        return onUnknownRoute(settings);
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      builder: (_) => const SplashScreen(),
      settings: settings,
    );
  }
}
