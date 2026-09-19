import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';

class EquippedCardsBar extends StatelessWidget {
  final int maxSlots;
  final List<dynamic> equippedCards;
  final VoidCallback? onSlotTap;
  final Function(dynamic card)? onCardTap;

  const EquippedCardsBar({
    super.key,
    required this.maxSlots,
    required this.equippedCards,
    this.onSlotTap,
    this.onCardTap,
  });

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.amber.shade600;
      case 'epic':
        return Colors.purple.shade400;
      case 'rare':
        return Colors.blue.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(TablerIcons.cards, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tarjetas Equipadas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${equippedCards.length}/$maxSlots',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(maxSlots, (index) {
              final slotNumber = index + 1;
              final equipped = equippedCards.firstWhere(
                (c) => c['slot'] == slotNumber,
                orElse: () => null,
              );

              if (equipped != null) {
                final rarity = (equipped['rarity'] ?? 'common').toString();
                final name = (equipped['name'] ?? 'Tarjeta').toString();
                final level = equipped['level'] ?? 1;
                final color = _getRarityColor(rarity);

                return GestureDetector(
                  onTap: () => onCardTap?.call(equipped),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 72,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                TablerIcons.square_asterisk,
                                color: color,
                                size: 28,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'N$level',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 58,
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GestureDetector(
                onTap: onSlotTap,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: const Center(
                        child: Icon(
                          TablerIcons.plus,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Slot $slotNumber',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
