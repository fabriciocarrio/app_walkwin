import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/offline_sync_service.dart';
import 'services/notification_service.dart';
import 'services/notification_store.dart';
import 'services/step_background_service.dart';
import 'services/step_counting_service.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.instance.init();
  await NotificationService.init();
  await NotificationStore.instance.init();
  OfflineSyncService.listenAndSync();
  await StepBackgroundService.initialize();
  await StepCountingService.instance.initialize();

  // Escuchar invocaciones del background service para actualizar la
  // notificación permanente incluso cuando la app está suspendida.
  FlutterBackgroundService().on('stepUpdate').listen((data) async {
    final daily = data?['daily'] as int? ?? 0;
    if (daily > 0) {
      await NotificationService.showProgressNotification(
        steps: daily,
        coins: 0,
        dailyGoal: 10000,
      );
    }
  });

  runApp(const ExploriaApp());
}

// Global notifier for theme switching
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class ExploriaApp extends StatelessWidget {
  const ExploriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'exploria_app',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const SplashScreen(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeShell(),
          },
        );
      },
    );
  }
}
