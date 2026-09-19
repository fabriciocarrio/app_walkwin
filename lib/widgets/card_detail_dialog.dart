import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';

class CardDetailDialog extends StatelessWidget {
  final Map<String, dynamic> userCard;
  final VoidCallback? onEquip;
  final VoidCallback? onUnequip;
  final VoidCallback? onLevelUp;
  final VoidCallback? onFuse;

  const CardDetailDialog({
    super.key,
    required this.userCard,
    this.onEquip,
    this.onUnequip,
    this.onLevelUp,
    this.onFuse,
  });

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.amber.shade600;
      case 'epic':
        return Colors.purple.shade500;
      case 'rare':
        return Colors.blue.shade500;
      default:
        return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (userCard['name'] ?? 'Tarjeta').toString();
    final rarity = (userCard['rarity'] ?? 'common').toString();
    final category = (userCard['category'] ?? 'General').toString();
    final level = userCard['level'] ?? 1;
    final maxLevel = userCard['max_level'] ?? 10;
    final duplicates = userCard['duplicates'] ?? 0;
    final isEquipped = (userCard['equipped'] == true);
    final slot = userCard['slot'];
    final effects = (userCard['effects'] is List) ? (userCard['effects'] as List) : [];
    final color = _getRarityColor(rarity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(TablerIcons.square_asterisk, color: color, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            rarity.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: color,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Categoría: $category',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Level Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nivel $level / $maxLevel',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Duplicados: $duplicates',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: level / maxLevel,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 16),

              // Effects List
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '⚡ Efectos Activos:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              if (effects.isEmpty)
                Text('Sin efectos pasivos', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              else
                Column(
                  children: effects.map((eff) {
                    final desc = (eff['description'] ?? 'Efecto pasivo').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(TablerIcons.sparkles, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!isEquipped)
                    ElevatedButton.icon(
                      onPressed: onEquip,
                      icon: const Icon(TablerIcons.cards, size: 18),
                      label: const Text('Equipar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onUnequip,
                      icon: const Icon(TablerIcons.x, size: 18),
                      label: Text('Desequipar (Slot $slot)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  if (duplicates >= 1 && level < maxLevel)
                    ElevatedButton.icon(
                      onPressed: onLevelUp,
                      icon: const Icon(TablerIcons.arrow_up_circle, size: 18),
                      label: const Text('Subir Nivel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  if (duplicates >= 3 && rarity.toLowerCase() != 'legendary')
                    ElevatedButton.icon(
                      onPressed: onFuse,
                      icon: const Icon(TablerIcons.flame, size: 18),
                      label: const Text('Fusionar 3'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
