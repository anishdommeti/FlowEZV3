import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/routes/app_routes.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_bootstrapApp);
  }

  Future<void> _bootstrapApp() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }

      final authService = context.read<AuthService>();
      final firebaseUser = authService.currentUser;

      if (firebaseUser == null) {
        _goTo(AppRoutes.login);
        return;
      }

      final profile = await authService.getUserProfile(firebaseUser.uid);
      if (!mounted) {
        return;
      }

      _goTo(
        profile.role.trim().toLowerCase() == 'admin'
            ? AppRoutes.adminDashboard
            : AppRoutes.home,
      );
    } on SocketException {
      if (!mounted) {
        return;
      }
      _showErrorDialog(
        'No internet connection. Please reconnect and restart FlowEZ.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorDialog(
        error.toString().contains('User profile was not found.')
            ? 'Your account was authenticated, but the user profile document was not found in Firestore.'
            : error.toString(),
      );
    }
  }

  void _goTo(String routeName) {
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  Future<void> _showErrorDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Startup Error'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 44,
                    color: theme.colorScheme.onPrimaryContainer,
                    semanticLabel: 'FlowEZ logo',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.appName,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.appTagline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
