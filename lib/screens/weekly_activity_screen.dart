import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class WeeklyActivityScreen extends StatefulWidget {
  final WeeklyActivitySummary weekly;

  const WeeklyActivityScreen({super.key, required this.weekly});

  @override
  State<WeeklyActivityScreen> createState() => _WeeklyActivityScreenState();
}

class _WeeklyActivityScreenState extends State<WeeklyActivityScreen> {
  late WeeklyActivitySummary _weekly;
  UserActivityHistory? _history;
  int _weekOffset = 0;
  bool _loadingWeek = false;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _weekly = widget.weekly;
    _weekOffset = widget.weekly.weekOffset;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiService.getActivityHistory();
      if (mounted) {
        setState(() {
          _history = UserActivityHistory.fromJson(res);
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _changeWeek(int newOffset) async {
    if (_loadingWeek || newOffset > 0) return;
    setState(() => _loadingWeek = true);
    try {
      final res = await ApiService.getWeeklyActivity(offset: newOffset);
      if (mounted) {
        setState(() {
          _weekly = WeeklyActivitySummary.fromJson(res);
          _weekOffset = newOffset;
          _loadingWeek = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingWeek = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar la semana: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = parts[2];
        final monthNum = int.tryParse(parts[1]) ?? 1;
        const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        return '$day ${months[monthNum - 1]}';
      }
    } catch (_) {}
    return dateStr;
  }

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
            // Week Selector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(TablerIcons.chevron_left),
                  color: textPrimary,
                  onPressed: _loadingWeek ? null : () => _changeWeek(_weekOffset - 1),
                  tooltip: 'Semana anterior',
                ),
                Column(
                  children: [
                    Text(
                      _weekOffset == 0
                          ? 'Semana actual'
                          : _weekOffset == -1
                              ? 'Semana anterior'
                              : 'Hace ${-_weekOffset} semanas',
                      style: GoogleFonts.montserrat(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_weekly.weekStart != null && _weekly.weekEnd != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_formatShortDate(_weekly.weekStart!)} - ${_formatShortDate(_weekly.weekEnd!)}',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(TablerIcons.chevron_right),
                  color: _weekOffset < 0 ? textPrimary : textSecondary.withAlpha(80),
                  onPressed: (_loadingWeek || _weekOffset >= 0)
                      ? null
                      : () => _changeWeek(_weekOffset + 1),
                  tooltip: 'Semana siguiente',
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loadingWeek)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              // Days badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _weekly.days
                    .map((d) => _buildDayBadge(d, isDark, textPrimary, textSecondary))
                    .toList(),
              ),
              const SizedBox(height: 32),

              // Resumen semanal title
              Text(
                'Resumen de la semana',
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
                      icon: TablerIcons.walk,
                      iconColor: const Color(0xFF1877F2),
                      value: _weekly.totalSteps.toString().replaceAllMapped(
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
                      icon: TablerIcons.map,
                      iconColor: const Color(0xFF20D4A4),
                      value: _weekly.totalDistanceKm.toStringAsFixed(1),
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
                      icon: TablerIcons.flame,
                      iconColor: const Color(0xFFFF6B00),
                      value: _weekly.totalCaloriesKcal != null
                          ? _weekly.totalCaloriesKcal!.toStringAsFixed(0).replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (m) => '${m[1]}.')
                          : '0',
                      unit: 'kcal\nCalorías',
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: TablerIcons.circle_check,
                      iconColor: const Color(0xFF00C2FF),
                      value: '${_weekly.exerciseDaysCompleted}',
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
            ],

            // Profile hint
            if (_weekly.needsProfileData)
              Container(
                margin: const EdgeInsets.only(bottom: 32),
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
                        child: Icon(TablerIcons.user, size: 18, color: Color(0xFF7A4A00)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _weekly.profileHint ??
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

            // ════════════════════════════════════════════════════════════════
            // HISTORIAL COMPLETO DE POR VIDA (ALL-TIME HISTORY)
            // ════════════════════════════════════════════════════════════════
            const Divider(height: 40),
            Row(
              children: [
                const Icon(TablerIcons.chart_bar, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Estadísticas Históricas',
                  style: GoogleFonts.montserrat(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_history != null) ...[
              // Banner de Totales Acumulados
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHistoryMetric(
                          icon: TablerIcons.walk,
                          label: 'Pasos De Por Vida',
                          value: _history!.totalSteps.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (m) => '${m[1]}.'),
                        ),
                        _buildHistoryMetric(
                          icon: TablerIcons.map_pin,
                          label: 'Km Recorridos',
                          value: '${_history!.totalDistanceKm.toStringAsFixed(1)} km',
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHistoryMetric(
                          icon: TablerIcons.calendar_check,
                          label: 'Días Caminados',
                          value: '${_history!.totalDaysActive} días',
                        ),
                        _buildHistoryMetric(
                          icon: TablerIcons.chart_line,
                          label: 'Promedio Diario',
                          value: '${_history!.avgDailySteps} pasos',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Récord Histórico de Pasos Card
              if (_history!.bestDay != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.shade400.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          TablerIcons.trophy,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Récord Histórico en un Día',
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : Colors.amber.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_history!.bestDay!.steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} pasos',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Conseguido el ${_formatShortDate(_history!.bestDay!.date)}',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Desglose Mensual
              if (_history!.monthly.isNotEmpty) ...[
                Text(
                  'Historial por mes',
                  style: GoogleFonts.montserrat(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._history!.monthly.map(
                  (m) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(TablerIcons.calendar, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              m.month,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${m.totalSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} pasos',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${m.distanceKm.toStringAsFixed(1)} km · ${m.activeDays} días activos',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4FC3F7), size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
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
    final progress = (day.steps / (_weekly.exerciseThresholdSteps > 0 ? _weekly.exerciseThresholdSteps : 5000)).clamp(0.0, 1.0);

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
                  child: const Icon(TablerIcons.check, color: Colors.white, size: 18),
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
    double maxCal = 1000;
    for (var day in _weekly.days) {
      if (day.caloriesKcal != null && day.caloriesKcal! > maxCal) {
        maxCal = day.caloriesKcal!;
      }
    }
    maxCal = ((maxCal / 500).ceil() * 500).toDouble();

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(maxCal / 1000).toStringAsFixed(0)}K', style: TextStyle(color: textSecondary, fontSize: 10)),
              Text((maxCal / 2).toStringAsFixed(0), style: TextStyle(color: textSecondary, fontSize: 10)),
              Text('0', style: TextStyle(color: textSecondary, fontSize: 10)),
              const SizedBox(height: 24),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weekly.days.map((day) {
                final val = day.caloriesKcal ?? 0.0;
                final pct = (val / maxCal).clamp(0.0, 1.0);
                final isCurrent = day == _weekly.days.last;
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
