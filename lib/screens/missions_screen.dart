import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MissionsScreen extends StatefulWidget {
  final List<GeoMissionDto> missions;

  const MissionsScreen({super.key, required this.missions});

  static const typeMeta = {
    'steps': {
      'icon': Icons.directions_walk_rounded,
      'label': 'Pasos',
      'desc': 'Caminá y acumulá pasos para completar objetivos',
      'color': Color(0xFF207AF5),
    },
    'exploration': {
      'icon': Icons.explore_rounded,
      'label': 'Exploración',
      'desc': 'Visitá lugares y descubrí la ciudad',
      'color': Color(0xFF20D4A4),
    },
    'collectible': {
      'icon': Icons.collections_bookmark_rounded,
      'label': 'Coleccionables',
      'desc': 'Encontrá y coleccioná objetos especiales',
      'color': Color(0xFFFF6B00),
    },
  };

  static const typeOrder = ['steps', 'exploration', 'collectible'];

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  late List<GeoMissionDto> _missions;
  String? _claimingMissionId;

  @override
  void initState() {
    super.initState();
    _missions = List.from(widget.missions);
  }

  Future<void> _claimReward(GeoMissionDto mission) async {
    setState(() => _claimingMissionId = mission.id);
    try {
      final result = await ApiService.claimMissionReward(missionId: mission.id);

      if (result['success'] == true && mounted) {
        setState(() {
          final idx = _missions.indexWhere((m) => m.id == mission.id);
          if (idx != -1) {
            _missions[idx] = GeoMissionDto(
              id: _missions[idx].id,
              title: _missions[idx].title,
              description: _missions[idx].description,
              missionType: _missions[idx].missionType,
              targetCount: _missions[idx].targetCount,
              currentProgress: _missions[idx].currentProgress,
              progressPercent: _missions[idx].progressPercent,
              rewardCoins: _missions[idx].rewardCoins,
              rewardXp: _missions[idx].rewardXp,
              isCompleted: _missions[idx].isCompleted,
              isClaimed: true,
              criteria: _missions[idx].criteria,
              criteriaDescription: _missions[idx].criteriaDescription,
            );
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recompensa reclamada con éxito'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error al reclamar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claimingMissionId = null);
      }
    }
  }

  Map<String, List<GeoMissionDto>> _groupByType() {
    final grouped = <String, List<GeoMissionDto>>{};
    for (final m in _missions) {
      grouped.putIfAbsent(m.missionType, () => []).add(m);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final completedCount = _missions.where((m) => m.isCompleted).length;
    final grouped = _groupByType();

    return Scaffold(
      appBar: AppBar(title: const Text('Misiones')),
      body: SafeArea(
        child: _missions.isEmpty
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
                      border: Border.all(
                        color: AppColors.primary.withAlpha(70),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$completedCount/${_missions.length} misiones realizadas',
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
                  const SizedBox(height: 20),
                  ...MissionsScreen.typeOrder
                      .where((t) => grouped.containsKey(t))
                      .map((type) {
                        final meta = MissionsScreen.typeMeta[type]!;
                        final typeMissions = grouped[type]!;
                        final typeCompleted = typeMissions
                            .where((m) => m.isCompleted)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TypeHeader(
                                icon: meta['icon'] as IconData,
                                label: meta['label'] as String,
                                description: meta['desc'] as String,
                                color: meta['color'] as Color,
                                completed: typeCompleted,
                                total: typeMissions.length,
                                isDark: isDark,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                              const SizedBox(height: 12),
                              ...typeMissions.map(
                                (mission) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MissionCard(
                                    mission: mission,
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                    card: card,
                                    bg: bg,
                                    isClaiming:
                                        _claimingMissionId == mission.id,
                                    onClaim:
                                        mission.isCompleted &&
                                            !mission.isClaimed
                                        ? () => _claimReward(mission)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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
  final Color bg;
  final bool isClaiming;
  final VoidCallback? onClaim;

  const _MissionCard({
    required this.mission,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.card,
    required this.bg,
    this.isClaiming = false,
    this.onClaim,
  });

  Color get _typeColor {
    final meta = MissionsScreen.typeMeta[mission.missionType];
    return meta?['color'] as Color? ?? AppColors.primary;
  }

  IconData get _typeIcon {
    final meta = MissionsScreen.typeMeta[mission.missionType];
    return meta?['icon'] as IconData? ?? Icons.assignment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final progress = mission.targetCount > 0
        ? (mission.currentProgress / mission.targetCount).clamp(0.0, 1.0)
        : 0.0;
    final typeColor = _typeColor;

    final borderColor = mission.isClaimed
        ? typeColor
        : (mission.isCompleted
              ? AppColors.primary.withAlpha(180)
              : Colors.transparent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: mission.isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon, color: typeColor, size: 16),
              ),
              const SizedBox(width: 10),
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
              if (mission.isClaimed)
                Icon(Icons.check_circle_rounded, color: typeColor)
              else if (mission.isCompleted)
                const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.primary,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${mission.rewardCoins}🪙 · ${mission.rewardXp} XP',
                    style: TextStyle(
                      color: typeColor,
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
          if (mission.criteriaDescription != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.filter_list, size: 12, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    mission.criteriaDescription!,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _ProgressRow(
            progress: progress,
            detail: '${mission.currentProgress}/${mission.targetCount}',
            typeColor: typeColor,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            showClaimButton: onClaim != null,
          ),
          if (onClaim != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isClaiming ? null : onClaim,
                icon: isClaiming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.monetization_on, size: 18),
                label: Text(
                  isClaiming
                      ? 'Reclamando...'
                      : 'Reclamar ${mission.rewardCoins}🪙 · ${mission.rewardXp} XP',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final int completed;
  final int total;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _TypeHeader({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.completed,
    required this.total,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$completed/$total',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final double progress;
  final String detail;
  final Color typeColor;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final bool showClaimButton;

  const _ProgressRow({
    required this.progress,
    required this.detail,
    required this.typeColor,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    this.showClaimButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: isDark
                  ? AppColors.cardAltDark
                  : const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                showClaimButton ? Colors.orange : typeColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          detail,
          style: TextStyle(
            color: textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
