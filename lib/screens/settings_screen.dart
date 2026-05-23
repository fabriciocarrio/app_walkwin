import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/celebration_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedSource = 'native_sensor';
  static const _storage = FlutterSecureStorage();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _profileLoading = true;
  bool _profileSaving = false;
  bool _celebrationSoundEnabled = true;
  bool _celebrationVibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSource();
    _loadProfile();
    _loadCelebrationSettings();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
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

  Future<void> _toggleSound(bool value) async {
    await CelebrationService.setSoundEnabled(value);
    setState(() => _celebrationSoundEnabled = value);
  }

  Future<void> _toggleVibration(bool value) async {
    await CelebrationService.setVibrationEnabled(value);
    setState(() => _celebrationVibrationEnabled = value);
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getUserProfile();
      if (!mounted) return;
      setState(() {
        _ageController.text = data['age']?.toString() ?? '';
        _weightController.text = data['weight_kg']?.toString() ?? '';
        _heightController.text = data['height_cm']?.toString() ?? '';
        _profileLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final heightText = _heightController.text.trim();
    final height = heightText.isEmpty ? null : int.tryParse(heightText);

    if (age == null || weight == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá edad y peso para guardar tus datos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _profileSaving = true);
    try {
      await ApiService.updateUserProfile(
        age: age,
        weightKg: weight,
        heightCm: height,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos personales guardados.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Intentá nuevamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
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

              const SizedBox(height: 24),
              _buildSectionTitle('Datos personales', textSecondary),
              const SizedBox(height: 10),
              _buildCard(
                isDark: isDark,
                card: card,
                child: _profileLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precargá tus datos para un calculo mas preciso de calorias y progreso semanal.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  controller: _ageController,
                                  label: 'Edad',
                                  suffix: 'años',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildInput(
                                  controller: _weightController,
                                  label: 'Peso',
                                  suffix: 'kg',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInput(
                            controller: _heightController,
                            label: 'Altura (opcional)',
                            suffix: 'cm',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _profileSaving ? null : _saveProfile,
                              icon: _profileSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _profileSaving
                                    ? 'Guardando...'
                                    : 'Guardar datos',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

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
                onTap: () {},
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
                  'WalkWin v1.0.0',
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
    return GestureDetector(
      onTap: () async {
        // Request health permission if switching to a health source
        if (value == 'google_fit' || value == 'healthkit') {
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
        }
        setState(() => _selectedSource = value);
        await _storage.write(key: 'step_source', value: value);
        try {
          await ApiService.updateStepSource(value);
        } catch (_) {}
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
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontSize: 12),
        suffixText: suffix,
        suffixStyle: TextStyle(color: textSecondary, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardAltDark
            : AppColors.bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
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
