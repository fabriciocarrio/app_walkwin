import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Run both the minimum delay and the initialization logic simultaneously
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 5)),
      _checkAuth(),
    ]);

    final token = results[1] as String?;

    if (mounted) {
      if (token != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  Future<String?> _checkAuth() async {
    await _requestPermissions();
    await ApiService.loadToken();
    return await ApiService.getToken();
  }

  Future<void> _requestPermissions() async {
    await [Permission.activityRecognition].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fondosplash.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo "EXPLORIA"
              RichText(
                text: TextSpan(
                  style: GoogleFonts.montserrat(
                    fontSize: 44,
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
                              size: 48,
                              color: Color(
                                0xFF20D4A4,
                              ), // Cyan/Green color of the pin
                            ),
                            Positioned(
                              top: 10,
                              child: Container(
                                width: 14,
                                height: 14,
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
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                'Explorá tu ciudad.\nDescubrí. Caminá. Ganá.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 245, 247, 248),
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 5),
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF20D4A4)),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando datos...',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF284869),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
