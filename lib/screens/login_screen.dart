import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : const Color(0xFFF8FAFC);

    final titleColor = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF112A46);
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF3B4D63);
    final labelColor = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF112A46);

    return Stack(
      children: [
        // Background Image with Fade
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/loginfondo.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg.withAlpha(200), bg.withAlpha(0)],
                    stops: const [0.0, 0.75, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Foreground Content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // Logo EXPLORIA
                    Center(child: _buildLogo()),

                    const SizedBox(height: 40),

                    // Title
                    Text(
                      '¡Bienvenido!',
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
                      'Iniciá sesión para\nseguir explorando.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: subtitleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Fields
                    _buildLabel('Email', labelColor),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _emailController,
                      hint: 'tu@email.com',
                      keyboardType: TextInputType.emailAddress,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    _buildLabel('Contraseña', labelColor),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _passwordController,
                      hint: '••••••••',
                      obscureText: _obscurePassword,
                      isDark: isDark,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: subtitleColor,
                          size: 22,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          // Acción de recuperar contraseña
                        },
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF0056D2), // Blue link color
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF1877F2,
                          ), // Bright blue
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
                                'Iniciar sesión',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿No tenés cuenta? ',
                          style: GoogleFonts.montserrat(
                            color: subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: Text(
                            'Registrarme',
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
        ),
      ],
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
                    Icons.location_on,
                    size: 36,
                    color: Color(0xFF20D4A4), // Cyan/Green color of the pin
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
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF112A46);
    final borderColor = isDark ? Colors.transparent : const Color(0xFFE2E8F0);
    final hintColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF64748B);

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
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
        return null;
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );
      if (result['token'] != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      } else {
        _showError(result['message'] ?? 'Error al iniciar sesión');
      }
    } catch (e, stackTrace) {
      debugPrint('================ ERROR DE LOGIN ================');
      debugPrint('Error: $e');
      debugPrint('Stacktrace: $stackTrace');
      debugPrint('================================================');
      _showError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
