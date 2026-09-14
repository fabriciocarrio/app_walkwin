import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/expedition_service.dart';

/// Widget de Overlay flotante para control e indicadores en tiempo real
/// durante una expedición GPS en Exploria.
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
    return ListenableBuilder(
      listenable: expeditionService,
      builder: (context, _) {
        final bool isIdle = expeditionService.isIdle;
        final bool isRecording = expeditionService.isRecording;
        final bool isPaused = expeditionService.isPaused;

        if (isIdle) {
          return _buildStartButton(context);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Panel compacto de Métricas en Tiempo Real (Overlay Glassmorphism)
            _buildMetricsPanel(context),
            const SizedBox(height: 12),

            // Controles de Acción (Pausar / Reanudar / Finalizar)
            _buildControlButtons(context, isRecording: isRecording, isPaused: isPaused),
          ],
        );
      },
    );
  }

  /// Botón Flotante para Iniciar Expedición
  Widget _buildStartButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            HapticFeedback.mediumImpact();
            final bool started = await expeditionService.startExpedition();
            if (!started && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor habilita los permisos de ubicación GPS para iniciar.'),
                  backgroundColor: Colors.deepOrange,
                ),
              );
            }
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF00897B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Iniciar Expedición',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Panel Compacto de Métricas en Tiempo Real (Tiempo, Distancia, PE)
  Widget _buildMetricsPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xEC121824), // Dark Navy Glassmorphism
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: expeditionService.isRecording
              ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
              : Colors.amber.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Cronómetro
          _buildMetricColumn(
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF00E5FF),
            label: 'TIEMPO',
            value: expeditionService.formattedTime,
          ),
          Container(width: 1, height: 36, color: Colors.white24),

          // Distancia Recorrida
          _buildMetricColumn(
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFF76FF03),
            label: 'DISTANCIA',
            value: expeditionService.totalDistanceKm >= 1.0
                ? '${expeditionService.totalDistanceKm.toStringAsFixed(2)} km'
                : '${expeditionService.totalDistanceMeters.round()} m',
          ),
          Container(width: 1, height: 36, color: Colors.white24),

          // Puntos Exploria Ganados (PE)
          _buildMetricColumn(
            icon: Icons.monetization_on_outlined,
            iconColor: const Color(0xFFFFD700),
            label: 'GANANCIA',
            value: '+${expeditionService.estimatedPe} PE',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Botones de Control (Pausar/Reanudar y Finalizar)
  Widget _buildControlButtons(BuildContext context, {required bool isRecording, required bool isPaused}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón Pausar / Reanudar
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (isRecording) {
                expeditionService.pauseExpedition();
              } else {
                expeditionService.resumeExpedition();
              }
            },
            icon: Icon(
              isRecording ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black87,
            ),
            label: Text(
              isRecording ? 'Pausar' : 'Reanudar',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecording ? const Color(0xFFFFB300) : const Color(0xFF76FF03),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
          ),
          const SizedBox(width: 16),

          // Botón Finalizar Expedición
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onFinishRequested();
            },
            icon: const Icon(Icons.stop_rounded, color: Colors.white),
            label: Text(
              'Finalizar',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}
