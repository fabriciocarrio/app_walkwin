import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../services/expedition_service.dart';

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
                    : const Icon(Icons.share_rounded, color: Colors.black87),
                label: Text(
                  _isSharing ? 'Generando...' : 'Compartir Tarjeta',
                  style: GoogleFonts.outfit(
                    color: Colors.black87,
                    fontWeight: FontWeight.extrabold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construcción visual estética de la Tarjeta Resumen estilo cromo/historia
  Widget _buildVisualCard(BuildContext context) {
    final String dateStr =
        '${widget.result.startTime.day}/${widget.result.startTime.month}/${widget.result.startTime.year}';

    return Container(
      width: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B101D),
            Color(0xFF162032),
            Color(0xFF0D1424),
          ],
        ),
        border: Border.all(color: const Color(0xFF00E5FF), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00897B)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPEDICIÓN EXPLORIA',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.black,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Text(
                      'COMPLETADO',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF76FF03),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Visualizador Gráfico de la Ruta Trazada (CustomPaint Vectorial de la Trayectoria)
            Container(
              height: 150,
              width: double.infinity,
              color: const Color(0xFF050913),
              child: CustomPaint(
                painter: _RoutePathPainter(routePoints: widget.result.routePoints),
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
                          icon: Icons.directions_walk_rounded,
                          accentColor: const Color(0xFF76FF03),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'TIEMPO TOTAL',
                          value: _formatSeconds(widget.result.elapsedSeconds),
                          icon: Icons.timer_outlined,
                          accentColor: const Color(0xFF00E5FF),
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
                          icon: Icons.directions_run_rounded,
                          accentColor: const Color(0xFFEA80FC),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryMetricItem(
                          label: 'PE GANADOS',
                          value: '+${widget.result.estimatedPe} PE',
                          icon: Icons.monetization_on_outlined,
                          accentColor: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Exploria • Camina, Descubre y Gana',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
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
                  style: GoogleFonts.orbitron(
                    color: Colors.white54,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.extrabold,
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

  _RoutePathPainter({required this.routePoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.isEmpty) {
      final Paint textPaint = TextPainter(
        text: TextSpan(
          text: 'Sin trayecto GPS grabado',
          style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPaint.paint(canvas, Offset((size.width - textPaint.width) / 2, (size.height - textPaint.height) / 2));
      return;
    }

    // Dibujar rejilla decorativa de mapa
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (routePoints.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF76FF03));
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

    // Resplandor Neón Exterior (Glow)
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);

    // Núcleo Neón Neón Interior (Core)
    final Paint corePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, corePaint);

    // Marcador de Inicio (Verde)
    final startPt = project(routePoints.first);
    canvas.drawCircle(startPt, 6, Paint()..color = const Color(0xFF76FF03));
    canvas.drawCircle(startPt, 3, Paint()..color = Colors.white);

    // Marcador de Fin (Rojo)
    final endPt = project(routePoints.last);
    canvas.drawCircle(endPt, 6, Paint()..color = const Color(0xFFFF5252));
    canvas.drawCircle(endPt, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePathPainter oldDelegate) {
    return oldDelegate.routePoints.length != routePoints.length;
  }
}
