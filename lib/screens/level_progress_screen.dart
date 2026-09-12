import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class LevelProgressScreen extends StatelessWidget {
  static const int _defaultMaxLevel = 30;

  final int level;
  final int xpTotal;
  final int levelStartXp;
  final int nextLevelXp;
  final int nextLevel;
  final int levelBaseXp;
  final int levelGrowthXp;
  final int maxLevel;
  final bool isMaxLevel;

  const LevelProgressScreen({
    super.key,
    required this.level,
    required this.xpTotal,
    required this.levelStartXp,
    required this.nextLevelXp,
    required this.nextLevel,
    required this.levelBaseXp,
    required this.levelGrowthXp,
    this.maxLevel = _defaultMaxLevel,
    this.isMaxLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    AnalyticsService.instance.trackScreen('LevelProgressScreen');
    final safeMaxLevel = maxLevel < 1 ? _defaultMaxLevel : maxLevel;
    final resolvedIsMaxLevel = isMaxLevel || level >= safeMaxLevel;
    final denominator = nextLevelXp - levelStartXp;
    final progress = resolvedIsMaxLevel || denominator <= 0
        ? 1.0
        : ((xpTotal - levelStartXp) / denominator).clamp(0.0, 1.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF112A46)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFE2F0FF),
                  Color(0xFFD6F5F0),
                  Color(0xFFFFFFFF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Background Image
          Image.asset(
            'assets/nivelesfondo.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
          // Overlay to make the background lighter
          Container(
            color: Colors.white.withAlpha(140),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  // Current Level Badge
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: _levelIllustration(level),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nivel $level',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF112A46),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _tierLabel(level).toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF112A46),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Progress Bar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$xpTotal / $nextLevelXp XP',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF112A46),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: const Color(0xFF1877F2).withAlpha(30),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Next Level Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: _levelIllustration(nextLevel),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Próximo nivel',
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFF3B4D63),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _tierLabel(nextLevel),
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFF112A46),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Achievements
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Logros recientes',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF112A46),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAchievementCard('7 días seguidos', '¡Racha completada!'),
                  const SizedBox(height: 12),
                  _buildAchievementCard('Primer canje', '¡Cupón usado!'),
                  const SizedBox(height: 12),
                  _buildAchievementCard('Explorador de barrios', 'Visitaste 10 comercios'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF1877F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(TablerIcons.star_filled, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF112A46),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF3B4D63),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelIllustration(int targetLevel, {double size = 64}) {
    final assetPath = _levelAssetPath(targetLevel);
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  String _levelAssetPath(int targetLevel) {
    if (targetLevel >= 26) return 'assets/levels/legendaria.svg';
    if (targetLevel >= 21) return 'assets/levels/elite.svg';
    if (targetLevel >= 11) return 'assets/levels/explorador.svg';
    if (targetLevel >= 6) return 'assets/levels/aventurero.svg';
    return 'assets/levels/novato.svg';
  }

  String _tierLabel(int targetLevel) {
    if (targetLevel >= 26) return 'Maestro Explorador';
    if (targetLevel >= 21) return 'Coleccionista';
    if (targetLevel >= 16) return 'Aventurero';
    if (targetLevel >= 11) return 'Descubridor';
    if (targetLevel >= 6) return 'Explorador';
    return 'Caminante';
  }
}
