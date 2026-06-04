import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Pantalla de scanner QR para check-in en comercios.
/// Retorna el payload escaneado si coincide con el comercio.
class QrScannerScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final int coinsReward;

  const QrScannerScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.coinsReward,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processed = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQrDetected(String value) {
    if (_processed) return;

    // Aceptar: el QR del comercio debe contener el ID del negocio.
    // Formatos soportados:
    //   "walkwin://checkin/{id}"   ← recomendado
    //   "{id}"                     ← simple
    //   contiene el ID             ← flexible
    final id = widget.businessId;
    final isValid =
        value == id ||
        value == 'walkwin://checkin/$id' ||
        value == 'WALKWIN:CHECKIN:$id' ||
        value.contains(id);

    if (isValid) {
      setState(() => _processed = true);
      Navigator.pop(context, value);
    } else {
      setState(
        () => _errorMsg = 'QR incorrecto. Escaneá el código del comercio.',
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _errorMsg = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Cámara ─────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_processed) return;
              final barcode = capture.barcodes.firstOrNull;
              final value = barcode?.rawValue;
              if (value != null) _onQrDetected(value);
            },
          ),

          // ── Overlay con recuadro de escaneo ─────────────────
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // ── Barra superior ──────────────────────────────────
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, null),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Escaneá el QR del comercio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(
                    Icons.flashlight_on_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          // ── Info inferior ───────────────────────────────────
          Positioned(
            bottom: 80,
            left: 32,
            right: 32,
            child: Column(
              children: [
                Text(
                  widget.businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(180),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${widget.coinsReward} puntos Exploria al escanear',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay oscuro con recuadro transparente en el centro y esquinas coloreadas.
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutoutSize = 260.0;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
      const Radius.circular(20),
    );

    // Oscurecer todo menos el recuadro
    final bgPaint = Paint()..color = Colors.black.withAlpha(160);
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(fullPath, bgPaint);

    // Borde del recuadro
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(cutoutRect, borderPaint);

    // Esquinas coloreadas
    const cornerLen = 26.0;
    const cornerStroke = 3.5;
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerStroke
      ..strokeCap = StrokeCap.round;

    final l = cutoutLeft;
    final t = cutoutTop;
    final r = cutoutLeft + cutoutSize;
    final b = cutoutTop + cutoutSize;

    // TL
    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cornerLen, t), cornerPaint);
    // TR
    canvas.drawLine(Offset(r - cornerLen, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerLen), cornerPaint);
    // BL
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cornerLen, b), cornerPaint);
    // BR
    canvas.drawLine(Offset(r - cornerLen, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
