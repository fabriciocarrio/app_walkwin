import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

final _avatars = List.generate(34, (i) => '${i + 1}.png');

String get _avatarBaseUrl {
  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  return '$base/img-profile/';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _selectedAvatar;
  List<String> _provinces = [];
  String? _selectedProvince;
  bool _loadingProvinces = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProvinces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getUserProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = data['name']?.toString() ?? '';
        _emailController.text = data['email']?.toString() ?? '';
        _phoneController.text = data['phone']?.toString() ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _weightController.text = data['weight_kg']?.toString() ?? '';
        _heightController.text = data['height_cm']?.toString() ?? '';
        _selectedAvatar = data['avatar']?.toString();
        _selectedProvince = data['province']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final provs = await ApiService.getAuthProvinces();
      if (mounted) {
        setState(() {
          _provinces = provs.cast<String>();
          _loadingProvinces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProvinces = false);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final heightText = _heightController.text.trim();
    final height = heightText.isEmpty ? null : int.tryParse(heightText);

    if (name.isEmpty) {
      _showError('El nombre es obligatorio');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Ingresá un email válido');
      return;
    }
    if (age == null || weight == null) {
      _showError('Completá edad y peso correctamente');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ApiService.updateUserProfile(
        name: name,
        email: email,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        avatar: _selectedAvatar,
        age: age,
        weightKg: weight,
        heightCm: height,
        province: _selectedProvince,
      );
      if (mounted) {
        if (result['updated'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        } else {
          _showError(result['message'] ?? 'Error al guardar');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error de conexión');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildAvatarSection(isDark, card, textPrimary, textSecondary),
                  const SizedBox(height: 28),
                  _buildField(
                    'Nombre',
                    _nameController,
                    textPrimary,
                    textSecondary,
                    icon: TablerIcons.user,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    'Email',
                    _emailController,
                    textPrimary,
                    textSecondary,
                    icon: TablerIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    'Teléfono (opcional)',
                    _phoneController,
                    textPrimary,
                    textSecondary,
                    icon: TablerIcons.phone,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildProvinceField(isDark, textPrimary, textSecondary),
                  const SizedBox(height: 28),
                  _buildPersonalDataSection(isDark, card, textPrimary, textSecondary),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final avatarId = _selectedAvatar ?? '1.png';
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: card,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipOval(
            child: Image.network(
              '$_avatarBaseUrl$avatarId',
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Icon(
                    TablerIcons.user,
                    size: 56,
                    color: textSecondary,
                  ),
              errorBuilder: (_, __, ___) => Icon(
                TablerIcons.user,
                size: 56,
                color: textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showAvatarPicker,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(TablerIcons.pencil, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Editar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAvatarPicker() async {
    String? tempSelected = _selectedAvatar;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
            final card = isDark ? AppColors.cardDark : AppColors.cardLight;

            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Scaffold(
                backgroundColor: bg,
                appBar: AppBar(
                  title: const Text('Elegí tu avatar'),
                  actions: [
                    TextButton(
                      onPressed: tempSelected != null
                          ? () => Navigator.of(ctx).pop(tempSelected)
                          : null,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
                body: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (_, index) {
                    final avatarId = _avatars[index];
                    final selected = tempSelected == avatarId;
                    return GestureDetector(
                      onTap: () =>
                          setInnerState(() => tempSelected = avatarId),
                      child: Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            selected ? 11 : 14,
                          ),
                          child: Image.network(
                            '$_avatarBaseUrl$avatarId',
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Icon(
                                        TablerIcons.user,
                                        size: 28,
                                        color: Colors.grey,
                                      ),
                            errorBuilder: (_, __, ___) => Icon(
                              TablerIcons.user,
                              size: 28,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedAvatar = result);
    }
  }

  Widget _buildPersonalDataSection(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos personales',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Precargá tus datos para un cálculo más preciso de calorías y progreso semanal.',
                style: TextStyle(color: textSecondary, fontSize: 12),
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
                      isDark: isDark,
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
                      isDark: isDark,
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
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
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
        fillColor: isDark ? AppColors.cardAltDark : AppColors.bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    Color textPrimary,
    Color textSecondary, {
    IconData? icon,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: textSecondary, size: 20) : null,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildProvinceField(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_loadingProvinces) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvince,
          hint: Text(
            'Provincia',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          isExpanded: true,
          icon: Icon(TablerIcons.chevron_down, color: textSecondary, size: 22),
          style: TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          items: _provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _selectedProvince = v),
        ),
      ),
    );
  }

}
