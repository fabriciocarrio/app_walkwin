import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/expedition_service.dart';
import '../theme/app_theme.dart';

/// Widget de Overlay flotante para control e indicadores en tiempo real
/// durante una expedición GPS en Exploria.
///
/// Barra vertical minimalista, anclada al lado izquierdo de la pantalla
/// con el estilo visual del resto de la app.
class ExpeditionOverlayWidget extends StatelessWidget {
  final ExpeditionService expeditionService;
  final VoidCallback onFinishRequested;

  const ExpeditionOverlayWidget({
    super.key,
    required this.expeditionService,
    required this.onFinishRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return ListenableBuilder(
      listenable: expeditionService,
      builder: (context, _) {
        final bool isIdle = expeditionService.isIdle;
        final bool isRecording = expeditionService.isRecording;

        if (isIdle) {
          return const SizedBox.shrink();
        }

        final accent = isRecording ? AppColors.primary : AppColors.warning;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: card.withAlpha(isDark ? 230 : 240),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: accent.withAlpha(isDark ? 120 : 80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 70 : 25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetric(
                icon: Icons.timer_outlined,
                iconColor: AppColors.primary,
                value: expeditionService.formattedTime,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 12),
              Container(width: 24, height: 1, color: accent.withAlpha(60)),
              const SizedBox(height: 12),
              _buildMetric(
                icon: Icons.directions_walk_rounded,
                iconColor: const Color(0xFF4CAF50),
                value: expeditionService.totalDistanceKm >= 1.0
                    ? '${expeditionService.totalDistanceKm.toStringAsFixed(2)}k'
                    : '${expeditionService.totalDistanceMeters.round()}m',
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 12),
              Container(width: 24, height: 1, color: accent.withAlpha(60)),
              const SizedBox(height: 12),
              _buildMetric(
                icon: Icons.monetization_on_outlined,
                iconColor: AppColors.coinGoldDark,
                value: '+${expeditionService.estimatedPe}',
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16),
              Container(width: 24, height: 1, color: accent.withAlpha(60)),
              const SizedBox(height: 12),
              // Botón Pausar / Reanudar
              _buildIconButton(
                icon: isRecording
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: isRecording
                    ? Colors.orange.shade600
                    : AppColors.primary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isRecording) {
                    expeditionService.pauseExpedition();
                  } else {
                    expeditionService.resumeExpedition();
                  }
                },
              ),
              const SizedBox(height: 8),
              // Botón Finalizar Expedición
              _buildIconButton(
                icon: Icons.stop_rounded,
                color: AppColors.danger,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onFinishRequested();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color textSecondary,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Hanken Grotesk',
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}