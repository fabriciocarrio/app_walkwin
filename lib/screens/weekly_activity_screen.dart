import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class WeeklyActivityScreen extends StatelessWidget {
  final WeeklyActivitySummary weekly;

  const WeeklyActivityScreen({super.key, required this.weekly});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46);
    final textSecondary = isDark ? AppColors.textSecondaryDark : const Color(0xFF3B4D63);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Actividad semanal section
            Center(
              child: Text(
                'Actividad semanal',
                style: GoogleFonts.montserrat(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekly.days
                  .map((d) => _buildDayBadge(d, isDark, textPrimary, textSecondary))
                  .toList(),
            ),
            const SizedBox(height: 40),

            // Resumen semanal title
            Text(
              'Resumen semanal',
              style: GoogleFonts.montserrat(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            
            // Resumen Grid
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.directions_walk_rounded,
                    iconColor: const Color(0xFF1877F2),
                    value: weekly.totalSteps.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (m) => '${m[1]}.'),
                    unit: 'Pasos',
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.map_rounded,
                    iconColor: const Color(0xFF20D4A4),
                    value: weekly.totalDistanceKm.toStringAsFixed(0),
                    unit: 'km\nDistancia',
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF6B00),
                    value: weekly.totalCaloriesKcal != null
                        ? weekly.totalCaloriesKcal!.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (m) => '${m[1]}.')
                        : '0',
                    unit: 'kcal\nCalorias',
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF00C2FF),
                    value: '${weekly.exerciseDaysCompleted}',
                    unit: 'días\nEjercicio cumplidos',
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Energía diaria Chart
            Text(
              'Energía diaria (kcal)',
              style: GoogleFonts.montserrat(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(isDark, textPrimary, textSecondary),

            const SizedBox(height: 32),
            // Profile hint
            if (weekly.needsProfileData)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardAltDark : const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF7A4A00)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        weekly.profileHint ??
                            'Completá tus datos en Ajustes\npara ver calorías precisas.',
                        style: GoogleFonts.montserrat(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final unitParts = unit.split('\n');
    final inlineUnit = unitParts.length > 1 ? unitParts[0] : '';
    final subText = unitParts.length > 1 ? unitParts[1] : unitParts[0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                    Text(
                      value,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF1877F2),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (inlineUnit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        inlineUnit,
                        style: GoogleFonts.montserrat(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: GoogleFonts.montserrat(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBadge(
    WeeklyActivityDay day,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final progress = (day.steps / (weekly.exerciseThresholdSteps > 0 ? weekly.exerciseThresholdSteps : 5000)).clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          day.label,
          style: GoogleFonts.montserrat(
            color: textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (day.completed) ...[
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF129B85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
              ] else ...[
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.dividerDark : const Color(0xFFE2E8F0),
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF129B85)),
                  strokeCap: StrokeCap.round,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(bool isDark, Color textPrimary, Color textSecondary) {
    // Find max calories to scale bars
    double maxCal = 1000;
    for (var day in weekly.days) {
      if (day.caloriesKcal != null && day.caloriesKcal! > maxCal) {
        maxCal = day.caloriesKcal!;
      }
    }
    // Round up maxCal to nearest 500
    maxCal = ((maxCal / 500).ceil() * 500).toDouble();

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y axis
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(maxCal / 1000).toStringAsFixed(0)}K', style: TextStyle(color: textSecondary, fontSize: 10)),
              Text('${(maxCal / 2).toStringAsFixed(0)}', style: TextStyle(color: textSecondary, fontSize: 10)),
              Text('0', style: TextStyle(color: textSecondary, fontSize: 10)),
              const SizedBox(height: 24), // Space for X axis labels
            ],
          ),
          const SizedBox(width: 12),
          // Bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekly.days.map((day) {
                final val = day.caloriesKcal ?? 0.0;
                final pct = (val / maxCal).clamp(0.0, 1.0);
                
                // Decide bar color (e.g., current day vs others, or based on progress)
                // We'll use a solid blue, and maybe a lighter blue for days with low activity or today
                final isCurrent = day == weekly.days.last; // Simple approximation for "today"
                final barColor = isCurrent ? const Color(0xFF62B9D9) : const Color(0xFF1877F2);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: 120 * pct,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day.label,
                      style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
