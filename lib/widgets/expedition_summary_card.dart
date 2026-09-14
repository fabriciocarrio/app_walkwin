import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../services/expedition_service.dart';
import '../theme/app_theme.dart';

/// Modal Diálogo que presenta la Tarjeta de Resumen Visual de una Expedición
/// permitiendo exportarla como imagen PNG y compartirla en historias/redes sociales.
class ExpeditionSummaryCardDialog extends StatefulWidget {
  final ExpeditionResult result;

  const ExpeditionSummaryCardDialog({
    super.key,
    required this.result,
  });

  @override
  State<ExpeditionSummaryCardDialog> createState() => _ExpeditionSummaryCardDialogState();
}

class _ExpeditionSummaryCardDialogState extends State<ExpeditionSummaryCardDialog> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  /// Convierte el widget envuelto en [RepaintBoundary] en una imagen PNG y abre el diálogo nativo de compartir
  Future<void> _shareCardImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      HapticFeedback.mediumImpact();

      // Pequeña espera para asegurar que la vista esté completamente renderizada
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary? boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('No se pudo obtener el contexto de renderizado de la tarjeta.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Fallo al convertir la imagen a formato PNG.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final XFile xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'expedicion_exploria_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await Share.shareXFiles(
        [xFile],
        text: '¡Completé una expedición en Exploria! 👟 GPS: ${widget.result.distanceKm.toStringAsFixed(2)} km en ${widget.result.elapsedSeconds ~/ 60} min (+${widget.result.estimatedPe} PE)',
        subject: 'Mi Expedición Exploria',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir tarjeta: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tarjeta Renderizable mediante RepaintBoundary
          RepaintBoundary(
            key: _cardKey,
            child: _buildVisualCard(context),
          ),
          const SizedBox(height: 16),

          // Botones de Acción (Compartir e Aceptar)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareCardImage,
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(TablerIcons.share, color: Colors.white, size: 18),
                label: Text(
                  _isSharing ? 'Generando...' : 'Compartir Tarjeta',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  TablerIcons.x,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.15),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construcción visual estética de la Tarjeta Resumen con estilo de la app
  Widget _buildVisualCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final String dateStr =
        '${widget.result.startTime.day}/${widget.result.startTime.month}/${widget.result.startTime.year}';

    return Container(
      width: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: card,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Branding Exploria + Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    const Color(0xFF4F46E5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(
                      TablerIcons.map_2,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPEDICIÓN EXPLORIA',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.sora(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          TablerIcons.circle_check,
                          color: Color(0xFF76FF03),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPLETADO',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF76FF03),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Visualizador Gráfico de la Ruta Trazada (CustomPaint Vectorial de la Trayectoria)
            Container(
              height: 150,
              width: double.infinity,
              color: isDark ? const Color(0xFF0D1321) : const Color(0xFFF1F5F9),
              child: CustomPaint(
                painter: _RoutePathPainter(
                  routePoints: widget.result.routePoints,
                  isDark: isDark,
                ),
              ),
            ),

            // Grid de Métricas Finales
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'DISTANCIA TOTAL',
                          value: '${widget.result.distanceKm.toStringAsFixed(2)} km',
                          icon: TablerIcons.walk,
                          accentColor: const Color(0xFF4CAF50),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'TIEMPO TOTAL',
                          value: _formatSeconds(widget.result.elapsedSeconds),
                          icon: TablerIcons.clock,
                          accentColor: AppColors.primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'PASOS ESTIMADOS',
                          value: '${widget.result.estimatedSteps}',
                          icon: TablerIcons.run,
                          accentColor: const Color(0xFF9C27B0),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'PE GANADOS',
                          value: '+${widget.result.estimatedPe}',
                          icon: TablerIcons.coin,
                          accentColor: AppColors.coinGoldDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        TablerIcons.circle_check,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Exploria • Camina, Descubre y Gana',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int totalSecs) {
    final int m = totalSecs ~/ 60;
    final int s = totalSecs % 60;
    if (m >= 60) {
      final int h = m ~/ 60;
      final int remM = m % 60;
      return '${h}h ${remM}m';
    }
    return '${m}m ${s}s';
  }
}

/// CustomPainter para dibujar de forma proporcional la Polyline de la expedición
/// con marcadores de Inicio (Verde) y Fin (Rojo).
class _RoutePathPainter extends CustomPainter {
  final List<LatLng> routePoints;
  final bool isDark;

  _RoutePathPainter({required this.routePoints, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.isEmpty) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: 'Sin trayecto GPS grabado',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    // Dibujar rejilla decorativa de mapa
    final Paint gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1))
          .withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (routePoints.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF4CAF50));
      return;
    }

    // Calcular límites geográficos de la ruta para normalizar la escala
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (var pt in routePoints) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final double latRange = (maxLat - minLat).abs() == 0 ? 0.0001 : (maxLat - minLat).abs();
    final double lngRange = (maxLng - minLng).abs() == 0 ? 0.0001 : (maxLng - minLng).abs();

    const double padding = 24.0;
    final double drawWidth = size.width - (padding * 2);
    final double drawHeight = size.height - (padding * 2);

    Offset project(LatLng pt) {
      final double normX = (pt.longitude - minLng) / lngRange;
      final double normY = 1.0 - ((pt.latitude - minLat) / latRange); // Invertir Y para coordenadas de pantalla
      return Offset(padding + normX * drawWidth, padding + normY * drawHeight);
    }

    final Path path = Path();
    final firstPoint = project(routePoints.first);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < routePoints.length; i++) {
      final pt = project(routePoints[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    // Resplandor Exterior (Glow)
    final Paint glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);

    // Núcleo Interior (Core)
    final Paint corePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, corePaint);

    // Marcador de Inicio (Verde)
    final startPt = project(routePoints.first);
    canvas.drawCircle(startPt, 6, Paint()..color = const Color(0xFF4CAF50));
    canvas.drawCircle(startPt, 3, Paint()..color = Colors.white);

    // Marcador de Fin (Rojo)
    final endPt = project(routePoints.last);
    canvas.drawCircle(endPt, 6, Paint()..color = const Color(0xFFFF5252));
    canvas.drawCircle(endPt, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePathPainter oldDelegate) {
    return oldDelegate.routePoints.length != routePoints.length ||
        oldDelegate.isDark != isDark;
  }
}