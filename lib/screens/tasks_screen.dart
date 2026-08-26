import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  static const typeMeta = {
    'steps': {
      'icon': TablerIcons.walk,
      'label': 'Pasos',
      'desc': 'Caminá y acumulá pasos para completar objetivos',
      'color': Color(0xFF207AF5),
    },
    'exploration': {
      'icon': TablerIcons.compass,
      'label': 'Exploración',
      'desc': 'Visitá lugares y descubrí la ciudad',
      'color': Color(0xFF20D4A4),
    },
    'collectible': {
      'icon': TablerIcons.book_2,
      'label': 'Coleccionables',
      'desc': 'Encontrá y coleccioná objetos especiales',
      'color': Color(0xFFFF6B00),
    },
  };

  static const typeOrder = ['steps', 'exploration', 'collectible'];

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<GeoMissionDto> _missions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('TasksScreen');
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await ApiService.getGeoMissions();
      final missionItems = data['data'] is List<dynamic>
          ? data['data'] as List<dynamic>
          : (data['missions'] as List<dynamic>? ?? []);

      if (mounted) {
        setState(() {
          _missions = missionItems
              .map((m) => GeoMissionDto.fromJson(m as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
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
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final completedCount = _missions.where((m) => m.isCompleted).length;
    final grouped = _groupByType();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? _buildError(textPrimary, textSecondary)
            : RefreshIndicator(
                onRefresh: _loadMissions,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Misiones',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress card
                      if (_missions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                TablerIcons.flag,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Progreso',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount/${_missions.length} completadas',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 60,
                                  height: 8,
                                  child: LinearProgressIndicator(
                                    value: _missions.isEmpty
                                        ? 0
                                        : completedCount / _missions.length,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Grouped by type
                      if (_missions.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TablerIcons.checklist,
                                size: 56,
                                color: textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No hay tareas disponibles',
                                style: TextStyle(color: textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
                        ...TasksScreen.typeOrder.where((t) => grouped.containsKey(t)).map(
                          (type) {
                            final meta = TasksScreen.typeMeta[type]!;
                            final typeMissions = grouped[type]!;
                            final typeCompleted = typeMissions.where((m) => m.isCompleted).length;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24),
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
                                        cardColor: card,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildError(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              TablerIcons.cloud_off,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verificá tu conexión e intentá de nuevo.',
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadMissions,
              child: const Text('Reintentar'),
            ),
          ],
        ),
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

class _MissionCard extends StatelessWidget {
  final GeoMissionDto mission;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardColor;

  const _MissionCard({
    required this.mission,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardColor,
  });

  Color get _typeColor {
    final meta = TasksScreen.typeMeta[mission.missionType];
    return meta?['color'] as Color? ?? AppColors.primary;
  }

  IconData get _typeIcon {
    final meta = TasksScreen.typeMeta[mission.missionType];
    return meta?['icon'] as IconData? ?? TablerIcons.checklist;
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor;
    final progress = mission.targetCount > 0
        ? (mission.currentProgress / mission.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mission.isCompleted
              ? typeColor.withAlpha(100)
              : isDark
                  ? AppColors.dividerDark
                  : AppColors.dividerLight.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mission.isCompleted
                      ? TablerIcons.check
                      : _typeIcon,
                  color: typeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: mission.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (mission.description != null &&
                        mission.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          mission.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              if (mission.isCompleted)
                Icon(TablerIcons.circle_check, color: typeColor, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Row(
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
                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${mission.currentProgress}/${mission.targetCount}',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (mission.rewardCoins > 0 || mission.rewardXp > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        TablerIcons.coin,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${mission.rewardCoins}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(TablerIcons.star_filled, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${mission.rewardXp} XP',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
