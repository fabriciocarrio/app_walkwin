import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_shell.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  OfflineSyncService.listenAndSync();
  runApp(const WalkWinApp());
}

// Global notifier for theme switching
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class WalkWinApp extends StatelessWidget {
  const WalkWinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'WalkWin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeShell(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Solicitar permisos necesarios al primer lanzamiento
    await _requestPermissions();
    await ApiService.loadToken();
    final token = await ApiService.getToken();

    if (mounted) {
      if (token != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.activityRecognition, Permission.location].request();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
