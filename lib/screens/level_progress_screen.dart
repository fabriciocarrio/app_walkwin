import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final safeMaxLevel = maxLevel < 1 ? _defaultMaxLevel : maxLevel;
    final resolvedIsMaxLevel = isMaxLevel || level >= safeMaxLevel;
    final denominator = nextLevelXp - levelStartXp;
    final progress = resolvedIsMaxLevel || denominator <= 0
      ? 1.0
      : ((xpTotal - levelStartXp) / denominator).clamp(0.0, 1.0);
    final xpMissing = resolvedIsMaxLevel ? 0 : (nextLevelXp - xpTotal).clamp(0, 999999);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Progresión de Niveles'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _levelIllustration(level, size: 76),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tierLabel(level),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nivel actual',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nivel $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$xpTotal XP acumulada',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedIsMaxLevel
                        ? 'Nivel máximo alcanzado'
                        : 'Progreso al nivel $nextLevel',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedIsMaxLevel
                        ? 'Ya alcanzaste el nivel $safeMaxLevel'
                        : 'Te faltan $xpMissing XP para subir',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!resolvedIsMaxLevel) ...[
              Text(
                'Próximos niveles',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ..._buildUpcomingLevels(
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                maxLevel: safeMaxLevel,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingLevels({
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required int maxLevel,
  }) {
    final widgets = <Widget>[];
    int cursorLevel = level;
    int cursorXp = levelStartXp;

    while (cursorLevel < nextLevel) {
      cursorLevel++;
      cursorXp += levelBaseXp + ((cursorLevel - 1) * levelGrowthXp);
    }

    for (int i = 0; i < 5; i++) {
      final targetLevel = nextLevel + i;
      if (targetLevel > maxLevel) {
        break;
      }
      if (i > 0) {
        cursorXp += levelBaseXp + ((targetLevel - 1) * levelGrowthXp);
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _levelIllustration(targetLevel, size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel $targetLevel',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tierLabel(targetLevel),
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Requiere $cursorXp XP total',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _levelIllustration(int targetLevel, {double size = 64}) {
    final assetPath = _levelAssetPath(targetLevel);
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
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
