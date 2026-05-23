import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MissionsScreen extends StatelessWidget {
  final List<GeoMissionDto> missions;

  const MissionsScreen({
    super.key,
    required this.missions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final completedCount = missions.where((m) => m.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Misiones'),
      ),
      body: SafeArea(
        child: missions.isEmpty
            ? Center(
                child: Text(
                  'No hay misiones disponibles',
                  style: TextStyle(color: textSecondary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withAlpha(70)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$completedCount/${missions.length} misiones realizadas',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...missions.map(
                    (mission) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MissionCard(
                        mission: mission,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        card: card,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final GeoMissionDto mission;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color card;

  const _MissionCard({
    required this.mission,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final stepProgress = mission.targetSteps > 0
        ? (mission.progressSteps / mission.targetSteps).clamp(0.0, 1.0)
        : 0.0;
    final businessProgress = mission.nearbyBusinessesRequired > 0
        ? (mission.progressBusinesses / mission.nearbyBusinessesRequired).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mission.isCompleted ? AppColors.primary : Colors.transparent,
          width: mission.isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (mission.isCompleted)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${mission.rewardCoins}🪙 · ${mission.rewardXp} XP',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (mission.description != null) ...[
            const SizedBox(height: 6),
            Text(
              mission.description!,
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          _ProgressRow(
            label: 'Pasos',
            progress: stepProgress,
            detail: '${mission.progressSteps}/${mission.targetSteps}',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 8),
          _ProgressRow(
            label: 'Comercios',
            progress: businessProgress,
            detail: '${mission.progressBusinesses}/${mission.nearbyBusinessesRequired}',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;
  final String detail;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _ProgressRow({
    required this.label,
    required this.progress,
    required this.detail,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: isDark ? AppColors.cardAltDark : const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          detail,
          style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
