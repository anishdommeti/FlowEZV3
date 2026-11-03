import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/queue_provider.dart';
import 'providers/user_provider.dart';
import 'screens/app_initialization_error_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/queue_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = await ThemeProvider.load();

  Object? initializationError;

  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'firebase_core',
        context: ErrorDescription('while initializing Firebase'),
      ),
    );
    initializationError = error;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'application',
        context: ErrorDescription('during application startup'),
      ),
    );
    initializationError = error;
  }

  //ErrorWidget.builder = (FlutterErrorDetails details) {
    //FlutterError.presentError(details);
    //return Material(
      //color: Colors.white,
      //child: Center(
        //child: Padding(
          //padding: const EdgeInsets.all(24),
          //child: Text(
            //'Unexpected application error: ${details.exceptionAsString()}',
            //textAlign: TextAlign.center,
          //),
        //),
      //),
    //);
  //};

  runApp(FlowEZApp(
    initializationError: initializationError,
    themeProvider: themeProvider,
  ));
}

class FlowEZApp extends StatelessWidget {
  const FlowEZApp({
    super.key,
    this.initializationError,
    required this.themeProvider,
  });

  final Object? initializationError;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<QueueService>(
          create: (_) => QueueService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
          ),
          update: (context, authService, previous) =>
              previous ?? AuthProvider(authService: authService),
        ),
        ChangeNotifierProxyProvider<QueueService, QueueProvider>(
          create: (context) => QueueProvider(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) =>
              previous ?? QueueProvider(queueService: queueService),
        ),
        ChangeNotifierProxyProvider2<AuthService, QueueService, UserProvider>(
          create: (context) => UserProvider(
            authService: context.read<AuthService>(),
            queueService: context.read<QueueService>(),
          ),
          update: (context, authService, queueService, previous) =>
              previous ??
              UserProvider(
                authService: authService,
                queueService: queueService,
              ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'FlowEZ',
            debugShowCheckedModeBanner: false,
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: themeProvider.mode,
            initialRoute: initializationError == null
                ? AppRoutes.bootstrap
                : AppRoutes.initializationError,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            onUnknownRoute: AppRoutes.onUnknownRoute,
            builder: (context, child) {
              if (initializationError != null) {
                return AppInitializationErrorScreen(
                  error: initializationError.toString(),
                );
              }

              return child ?? const SplashScreen();
            },
          );
        },
      ),
    );
  }
}
