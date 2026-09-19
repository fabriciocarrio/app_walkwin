import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';

class AttributesViewWidget extends StatelessWidget {
  final Map<String, dynamic> attributes;
  final int unassignedPoints;
  final Function(String attribute)? onAssignPoint;

  const AttributesViewWidget({
    super.key,
    required this.attributes,
    required this.unassignedPoints,
    this.onAssignPoint,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'key': 'pe',
        'name': 'Puntos Exploria (PE)',
        'val': '${attributes['pe'] ?? 0}',
        'icon': TablerIcons.coin,
        'color': AppColors.coinGold,
        'canAssign': false,
      },
      {
        'key': 'xp',
        'name': 'Experiencia (XP)',
        'val': '${attributes['xp'] ?? 0}',
        'icon': TablerIcons.trending_up,
        'color': AppColors.primary,
        'canAssign': false,
      },
      {
        'key': 'energia',
        'name': 'Energía',
        'val': '${attributes['energia'] ?? 20}/${attributes['energia_max'] ?? 20}',
        'icon': TablerIcons.bolt,
        'color': Colors.amber.shade700,
        'canAssign': true,
      },
      {
        'key': 'suerte',
        'name': 'Suerte',
        'val': '${((attributes['suerte'] ?? 0.0) * 100).toStringAsFixed(1)}%',
        'icon': TablerIcons.clover,
        'color': Colors.green.shade600,
        'canAssign': false,
      },
      {
        'key': 'percepcion',
        'name': 'Percepción',
        'val': '${attributes['percepcion'] ?? 500}m',
        'icon': TablerIcons.radar_2,
        'color': Colors.indigo.shade500,
        'canAssign': false,
      },
      {
        'key': 'movilidad',
        'name': 'Movilidad',
        'val': '${(attributes['movilidad'] ?? 1.0).toStringAsFixed(1)}x',
        'icon': TablerIcons.run,
        'color': Colors.cyan.shade600,
        'canAssign': false,
      },
      {
        'key': 'resiliencia',
        'name': 'Resiliencia',
        'val': '${attributes['resiliencia'] ?? 0}',
        'icon': TablerIcons.shield,
        'color': Colors.teal.shade600,
        'canAssign': false,
      },
      {
        'key': 'carisma',
        'name': 'Carisma',
        'val': '${attributes['carisma'] ?? 0}',
        'icon': TablerIcons.users,
        'color': Colors.pink.shade400,
        'canAssign': true,
      },
      {
        'key': 'conocimiento',
        'name': 'Conocimiento',
        'val': '${attributes['conocimiento'] ?? 0}',
        'icon': TablerIcons.book,
        'color': Colors.purple.shade500,
        'canAssign': true,
      },
      {
        'key': 'momentum',
        'name': 'Momentum (Sesión)',
        'val': '${(attributes['momentum'] ?? 1.0).toStringAsFixed(2)}x',
        'icon': TablerIcons.flame,
        'color': Colors.deepOrange.shade600,
        'canAssign': false,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unassignedPoints > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(TablerIcons.sparkles, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Tienes $unassignedPoints punto(s) de atributo para asignar!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final item = items[index];
            final IconData icon = item['icon'] as IconData;
            final Color color = item['color'] as Color;
            final bool canAssign = item['canAssign'] as bool;
            final String key = item['key'] as String;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    item['val'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (canAssign && unassignedPoints > 0) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(TablerIcons.circle_plus, color: AppColors.primary, size: 24),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () => onAssignPoint?.call(key),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
