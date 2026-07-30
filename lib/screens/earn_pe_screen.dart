import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'referrals_screen.dart';
import 'minigames_screen.dart';

class EarnPeScreen extends StatelessWidget {
  const EarnPeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Ganar + PE'),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sumá más Puntos Exploria',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Descubrí nuevas formas de ganar PE',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section: Gana con referidos
            Text(
              'Formas de ganar',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionCard(
              context: context,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
              icon: Icons.group_add_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Gana con referidos',
              subtitle: 'Tenés tu código único — compartilo y ganan PE vos y tu amigo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReferralsScreen()),
              ),
            ),
            const SizedBox(height: 14),

            _buildSectionCard(
              context: context,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
              icon: Icons.casino_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Gana probando suerte',
              subtitle: 'Ruleta diaria y raspaditas para ganar PE extra',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MinigamesScreen()),
              ),
            ),
            const SizedBox(height: 14),

            _buildSectionCard(
              context: context,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
              icon: Icons.directions_walk_rounded,
              iconColor: const Color(0xFF4A9BFF),
              title: 'Caminando siempre',
              subtitle: 'Cada paso cuenta — seguí sumando con tu actividad diaria',
              onTap: null,
              locked: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool locked = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_rounded, color: textSecondary.withAlpha(120), size: 20)
              else
                Icon(Icons.chevron_right_rounded, color: textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
