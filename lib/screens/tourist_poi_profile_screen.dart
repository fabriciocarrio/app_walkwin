import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class TouristPoiProfileScreen extends StatelessWidget {
  final ExplorationPoi poi;

  const TouristPoiProfileScreen({super.key, required this.poi});

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

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: (poi.imageUrl != null && poi.imageUrl!.isNotEmpty)
                  ? Image.network(
                      poi.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder(),
                    )
                  : _heroPlaceholder(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        icon: Icons.location_on_rounded,
                        text: poi.department ?? poi.province ?? 'San Juan',
                        bg: AppColors.primary.withAlpha(20),
                        fg: AppColors.primary,
                      ),
                      _chip(
                        icon: Icons.near_me_rounded,
                        text: poi.distanceM == 0
                            ? 'Muy cerca'
                            : '${poi.distanceM}m',
                        bg: textSecondary.withAlpha(18),
                        fg: textSecondary,
                      ),
                      _chip(
                        icon: Icons.eco_rounded,
                        text: '+${poi.rewardCoins} Puntos Exploria',
                        bg: const Color(0xFF4A9955).withAlpha(16),
                        fg: const Color(0xFF4A9955),
                      ),
                      _chip(
                        icon: Icons.bolt_rounded,
                        text: '+${poi.rewardXp} XP',
                        bg: const Color(0xFF2563EB).withAlpha(16),
                        fg: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: textSecondary.withAlpha(28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información del punto turístico',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (poi.description ?? '').trim().isEmpty
                              ? 'Este punto turístico todavía no tiene una descripción cargada.'
                              : poi.description!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      color: AppColors.primary.withAlpha(18),
      child: const Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 72,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
