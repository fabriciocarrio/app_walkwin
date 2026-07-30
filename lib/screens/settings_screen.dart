import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/celebration_service.dart';
import '../services/websocket_service.dart';
import '../services/step_background_service.dart';
import '../services/step_counting_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedSource = 'native_sensor';
  static const _storage = FlutterSecureStorage();
  bool _celebrationSoundEnabled = true;
  bool _celebrationVibrationEnabled = true;
  bool _googleFitAuthorized = false;
  bool _healthkitAuthorized = false;

  @override
  void initState() {
    super.initState();
    _loadSource();
    _loadCelebrationSettings();
    _checkHealthAuth();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSource() async {
    final saved = await _storage.read(key: 'step_source');
    if (saved != null && mounted) {
      setState(() => _selectedSource = saved);
    }
  }

  Future<void> _loadCelebrationSettings() async {
    final sound = await CelebrationService.isSoundEnabled();
    final vibration = await CelebrationService.isVibrationEnabled();
    if (mounted) {
      setState(() {
        _celebrationSoundEnabled = sound;
        _celebrationVibrationEnabled = vibration;
      });
    }
  }

  Future<void> _checkHealthAuth() async {
    final gfAuth = await _storage.read(key: 'google_fit_authorized');
    final hkAuth = await _storage.read(key: 'healthkit_authorized');
    if (mounted) {
      setState(() {
        _googleFitAuthorized = gfAuth == 'true';
        _healthkitAuthorized = hkAuth == 'true';
      });
    }
  }

  Future<void> _toggleSound(bool value) async {
    await CelebrationService.setSoundEnabled(value);
    setState(() => _celebrationSoundEnabled = value);
  }

  Future<void> _toggleVibration(bool value) async {
    await CelebrationService.setVibrationEnabled(value);
    setState(() => _celebrationVibrationEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Ajustes',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),

              // Appearance
              _buildSectionTitle('Apariencia', textSecondary),
              const SizedBox(height: 10),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) {
                  final darkOn = mode == ThemeMode.dark;
                  return _buildCard(
                    isDark: isDark,
                    card: card,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardAltDark
                                : AppColors.dividerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            darkOn
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo oscuro',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Cambiar tema de la app',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: darkOn,
                          onChanged: (val) {
                            themeNotifier.value = val
                                ? ThemeMode.dark
                                : ThemeMode.light;
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Fuente de Pasos', textSecondary),
              const SizedBox(height: 10),
              _buildSourceOption(
                'Sensor nativo',
                'Usa el podómetro del dispositivo',
                'native_sensor',
                Icons.phone_android_rounded,
                isDark,
                card,
                textPrimary,
                textSecondary,
              ),
              _buildSourceOption(
                'Google Fit',
                'Sincroniza con Google Fit',
                'google_fit',
                Icons.fitness_center_rounded,
                isDark,
                card,
                textPrimary,
                textSecondary,
              ),
              _buildSourceOption(
                'Apple Health',
                'Sincroniza con Apple Health',
                'healthkit',
                Icons.favorite_rounded,
                isDark,
                card,
                textPrimary,
                textSecondary,
              ),

              _buildHealthInstructions(isDark, card, textPrimary, textSecondary),

              const SizedBox(height: 24),
              _buildSectionTitle('Celebración', textSecondary),
              const SizedBox(height: 10),
              _buildCard(
                isDark: isDark,
                card: card,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardAltDark
                                : AppColors.dividerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sonido de celebración',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Reproducir sonido al alcanzar meta',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _celebrationSoundEnabled,
                          onChanged: _toggleSound,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[300], height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardAltDark
                                : AppColors.dividerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.vibration,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vibración de celebración',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Vibración al alcanzar meta',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _celebrationVibrationEnabled,
                          onChanged: _toggleVibration,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Cuenta', textSecondary),
              const SizedBox(height: 10),
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Perfil',
                isDark: isDark,
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
              ),
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones',
                isDark: isDark,
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.shield_outlined,
                title: 'Privacidad',
                isDark: isDark,
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Ayuda',
                isDark: isDark,
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {},
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Exploria v1.0.0',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildHealthInstructions(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isGoogleFit = _selectedSource == 'google_fit';
    final isHealthKit = _selectedSource == 'healthkit';
    if (!isGoogleFit && !isHealthKit) return const SizedBox.shrink();

    final isAuthorized =
        isGoogleFit ? _googleFitAuthorized : _healthkitAuthorized;
    final isAndroid = isGoogleFit;

    if (isAuthorized) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${isGoogleFit ? 'Google Fit' : 'Apple Health'} está conectado. Tus pasos se sincronizarán automáticamente.',
                  style: TextStyle(color: textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _buildCard(
        isDark: isDark,
        card: card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '¿Cómo conectar?',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isAndroid
                  ? '1. Tocá "Google Fit" arriba para solicitar permisos.\n'
                      '2. En la ventana de Google, elegí la cuenta y permití el acceso a tu actividad física.\n'
                      '3. Una vez conectado, verás el estado "Conectado" en verde.'
                  : '1. Tocá "Apple Health" arriba para solicitar permisos.\n'
                      '2. En la ventana de Salud, activá la lectura de pasos.\n'
                      '3. Una vez conectado, verás el estado "Conectado" en verde.',
              style: TextStyle(color: textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required Color card,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildSourceOption(
    String title,
    String subtitle,
    String value,
    IconData icon,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedSource == value;
    final isGoogleFit = value == 'google_fit';
    final isHealthKit = value == 'healthkit';
    final isHealthSource = isGoogleFit || isHealthKit;
    final isAuthorized =
        isGoogleFit ? _googleFitAuthorized : (isHealthKit ? _healthkitAuthorized : false);

    return GestureDetector(
      onTap: () async {
        if (isHealthSource) {
          final granted = await HealthService.requestAuthorization();
          if (!granted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permiso denegado. Revisá los ajustes del dispositivo.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          if (granted) {
            final key = isGoogleFit ? 'google_fit_authorized' : 'healthkit_authorized';
            await _storage.write(key: key, value: 'true');
            if (mounted) {
              setState(() {
                if (isGoogleFit) _googleFitAuthorized = true;
                if (isHealthKit) _healthkitAuthorized = true;
              });
            }
          }
        }
        setState(() => _selectedSource = value);
        await _storage.write(key: 'step_source', value: value);
        try {
          await ApiService.updateStepSource(value);
        } catch (_) {}
        await StepBackgroundService.syncWithSource();
        await StepCountingService.instance.refreshMode();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(30)
                    : (isDark ? AppColors.cardAltDark : AppColors.bgLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHealthSource) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAuthorized
                                ? const Color(0xFF10B981).withAlpha(25)
                                : (isSelected
                                    ? const Color(0xFFEF4444).withAlpha(25)
                                    : Colors.grey.withAlpha(20)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAuthorized
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                size: 11,
                                color: isAuthorized
                                    ? const Color(0xFF10B981)
                                    : (isSelected
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isAuthorized ? 'Conectado' : 'No conectado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isAuthorized
                                      ? const Color(0xFF10B981)
                                      : (isSelected
                                          ? const Color(0xFFEF4444)
                                          : Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isDark,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: textSecondary, size: 22),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    await WebSocketService.instance.disconnect();
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
