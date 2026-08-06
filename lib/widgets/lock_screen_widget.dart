import 'package:flutter/material.dart';
import 'package:walkwin_app/widgets/steps_coins_widget.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Widget para pantalla de bloqueo (lock screen widget)
/// Versión minimalista y compacta diseñada específicamente para lock screen
class LockScreenStepsCoinsWidget extends StatelessWidget {
  final int steps;
  final int coins;
  final DateTime? lastUpdate;

  const LockScreenStepsCoinsWidget({
    super.key,
    required this.steps,
    required this.coins,
    this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]?.withOpacity(0.95)
            : Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]?.withOpacity(0.3) ?? Colors.transparent,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                TablerIcons.walk,
                size: 18,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                'WalkWin',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (lastUpdate != null)
                Text(
                  _formatTime(lastUpdate!),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats
          Row(
            children: [
              // Steps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${steps}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                    ),
                    Text(
                      'pasos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Coins
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${coins}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700),
                              ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          TablerIcons.coin,
                          color: Color(0xFFFFD700),
                          size: 20,
                        ),
                      ],
                    ),
                    Text(
                      'puntos Exploria',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }
}
