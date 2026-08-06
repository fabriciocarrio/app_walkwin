import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _showReferral = false;
  String? _referralError; // error inline del campo de código
  List<String> _provinces = [];
  String? _selectedProvince;
  bool _loadingProvinces = true;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : const Color(0xFFF8FAFC);
    
    final titleColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46);
    final subtitleColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF3B4D63);
    final labelColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                
                // Logo EXPLORIA
                Center(child: _buildLogo()),
                
                const SizedBox(height: 30),
                
                // Title
                Text(
                  'Crear cuenta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: titleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                Text(
                  'Empezá a ganar Puntos\nExploria caminando.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: subtitleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Fields
                _buildLabel('Nombre', labelColor),
                const SizedBox(height: 8),
                _buildField(
                  controller: _nameController,
                  hint: 'Juan Pérez',
                  isDark: isDark,
                ),
                
                const SizedBox(height: 20),
                
                _buildLabel('Email', labelColor),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailController,
                  hint: 'tu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                ),
                
                const SizedBox(height: 20),
                
                _buildLabel('Contraseña', labelColor),
                const SizedBox(height: 8),
                _buildField(
                  controller: _passwordController,
                  hint: 'mínimo 8 caracteres',
                  obscureText: _obscurePassword,
                  isDark: isDark,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? TablerIcons.eye_off
                          : TablerIcons.eye,
                      color: subtitleColor,
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                
                const SizedBox(height: 20),

                _buildLabel('Provincia', labelColor),
                const SizedBox(height: 8),
                _buildProvinceDropdown(isDark: isDark, subtitleColor: subtitleColor),

                const SizedBox(height: 8),

                // Referral code toggle
                GestureDetector(
                  onTap: () => setState(() => _showReferral = !_showReferral),
                  child: Row(
                    children: [
                      Icon(
                        _showReferral ? TablerIcons.chevron_up : TablerIcons.chevron_down,
                        color: subtitleColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '¿Tenés código de referido?',
                        style: GoogleFonts.montserrat(
                          color: subtitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (_showReferral) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referralController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_referralError != null) {
                        setState(() => _referralError = null);
                      }
                    },
                    style: GoogleFonts.montserrat(
                      color: isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: JUAN-A3F8K2',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.cardDark : Colors.white,
                      prefixIcon: const Icon(TablerIcons.gift, color: Color(0xFF10B981)),
                      errorText: _referralError,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _referralError != null
                              ? AppColors.danger
                              : (isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _referralError != null
                              ? AppColors.danger
                              : (isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2), // Bright blue
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Crear Cuenta',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tenés cuenta? ',
                      style: GoogleFonts.montserrat(
                        color: subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Iniciá sesión',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF1877F2),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF112A46),
          letterSpacing: 1.5,
        ),
        children: [
          const TextSpan(text: 'EXPL'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    TablerIcons.map_pin,
                    size: 36,
                    color: Color(0xFF20D4A4),
                  ),
                  Positioned(
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TextSpan(text: 'RIA'),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        color: color, 
        fontSize: 14, 
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46);
    final borderColor = isDark ? Colors.transparent : const Color(0xFFE2E8F0);
    final hintColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.montserrat(
        color: textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(
          color: hintColor,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1877F2), width: 2),
        ),
        suffixIcon: suffix,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Campo requerido';
        if (keyboardType == TextInputType.emailAddress && !v.contains('@')) {
          return 'Email inválido';
        }
        if (obscureText && v.length < 8) return 'Mínimo 8 caracteres';
        return null;
      },
    );
  }

  Widget _buildProvinceDropdown({
    required bool isDark,
    required Color subtitleColor,
  }) {
    final card = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46);
    final hintColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B);

    if (_loadingProvinces) {
      return const LinearProgressIndicator();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvince,
          hint: Text('Seleccioná tu provincia', style: TextStyle(color: hintColor)),
          isExpanded: true,
          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _selectedProvince = v),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null) {
      _showError('Seleccioná tu provincia');
      return;
    }
    setState(() {
      _loading = true;
      _referralError = null;
    });
    try {
      final result = await ApiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        referralCode: _referralController.text,
        province: _selectedProvince,
      );

      if (result['token'] != null && mounted) {
        final bonusPe = result['referral_bonus_pe'] as int? ?? 0;
        final referralType = result['referral_type'] as String?;
        if (bonusPe > 0 && referralType != null && mounted) {
          // Mostrar pantalla de bienvenida con el bono antes de ir al home
          await _showReferralBonus(bonusPe);
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        }
      } else {
        // Verificar si hay error específico del campo referral_code
        final errors = result['errors'] as Map<String, dynamic>?;
        final referralErrors = errors?['referral_code'] as List<dynamic>?;
        if (referralErrors != null && referralErrors.isNotEmpty) {
          setState(() {
            _referralError = referralErrors.first.toString();
            _showReferral = true; // asegurar que el campo sea visible
          });
        } else {
          _showError(result['message'] ?? 'Error al registrar');
        }
      }
    } catch (e) {
      _showError('Error de conexión');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Muestra un diálogo de celebración cuando el nuevo usuario gana PE por código referido.
  Future<void> _showReferralBonus(int bonusPe) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withAlpha(80),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.gift, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              Text(
                '¡Bienvenido a Exploria!',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Usaste un código de referido y ganaste',
                style: GoogleFonts.montserrat(
                  color: Colors.white.withAlpha(210),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(80)),
                ),
                child: Text(
                  '+$bonusPe PE',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puntos Exploria acreditados',
                style: GoogleFonts.montserrat(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '¡Empezar a caminar!',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
