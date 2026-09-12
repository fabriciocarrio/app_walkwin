import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Widget de Tarjeta Coleccionable Interactivo en 3D
/// Simula el efecto cromo holográfico (Holo Foil) con giroscopio, gestos táctiles,
/// profundidad parallax en 3 capas y respuesta háptica.
class HolographicCardWidget extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String rarity; // 'common', 'rare', 'epic', 'legendary'
  final bool isHolographic;
  final String? province;
  final String? category;
  final String? description;
  final int? requiredLevel;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const HolographicCardWidget({
    super.key,
    this.imageUrl,
    required this.title,
    this.rarity = 'common',
    this.isHolographic = true,
    this.province,
    this.category,
    this.description,
    this.requiredLevel,
    this.width = 280,
    this.height = 420,
    this.onTap,
  });

  @override
  State<HolographicCardWidget> createState() => _HolographicCardWidgetState();
}

class _HolographicCardWidgetState extends State<HolographicCardWidget>
    with SingleTickerProviderStateMixin {
  // Rotación en los ejes (en radianes, máximo +/- 0.45)
  double _rotX = 0.0;
  double _rotY = 0.0;

  // Suscripción al giroscopio nativo
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Controlador para animación de retorno a la posición neutra
  late AnimationController _resetController;
  late Animation<double> _animX;
  late Animation<double> _animY;

  // Estado háptico para evitar vibraciones excesivas
  bool _hasTriggeredHapticMax = false;

  // Umbral máximo de inclinación
  static const double _maxTilt = 0.40; // ~23 grados

  @override
  void initState() {
    super.initState();

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _resetController.addListener(() {
      setState(() {
        _rotX = _animX.value;
        _rotY = _animY.value;
      });
    });

    if (widget.isHolographic) {
      _initSensors();
    }
  }

  void _initSensors() {
    try {
      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          if (!mounted) return;
          // Si el usuario está interactuando con el dedo, se prioriza el gesto
          if (_resetController.isAnimating) return;

          setState(() {
            // Inclinación eje X (cabeceo) e Y (alabeo) con suavizado (dampening)
            _rotX = (_rotX + event.x * 0.045).clamp(-_maxTilt, _maxTilt);
            _rotY = (_rotY + event.y * 0.045).clamp(-_maxTilt, _maxTilt);

            _checkHapticEdge();
          });
        },
        onError: (_) {
          // Ignorar errores en dispositivos sin giroscopio (usarán fallback táctil)
        },
        cancelOnError: false,
      );
    } catch (_) {
      // Fallback seguro
    }
  }

  void _checkHapticEdge() {
    final bool atEdge = _rotX.abs() >= _maxTilt - 0.02 || _rotY.abs() >= _maxTilt - 0.02;
    if (atEdge && !_hasTriggeredHapticMax) {
      HapticFeedback.lightImpact();
      _hasTriggeredHapticMax = true;
    } else if (!atEdge) {
      _hasTriggeredHapticMax = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _resetController.stop();
    setState(() {
      // Mapear arrastre del dedo a rotación 3D
      _rotY = (_rotY + details.delta.dx * 0.005).clamp(-_maxTilt, _maxTilt);
      _rotX = (_rotX - details.delta.dy * 0.005).clamp(-_maxTilt, _maxTilt);
      _checkHapticEdge();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Retorno suave a la posición inicial
    _animX = Tween<double>(begin: _rotX, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _animY = Tween<double>(begin: _rotY, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _resetController.dispose();
    super.dispose();
  }

  // Estilos y paletas según la rareza
  _RarityTheme _getRarityTheme() {
    switch (widget.rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return _RarityTheme(
          name: 'LEGENDARIA',
          borderColor: const Color(0xFFFFD700),
          gradientColors: [const Color(0xFFFFF176), const Color(0xFFFFB300), const Color(0xFFFF6F00)],
          glowColor: Colors.amberAccent.withValues(alpha: 0.6),
          badgeBg: Colors.amber.shade900,
        );
      case 'epic':
      case 'épica':
      case 'epica':
        return _RarityTheme(
          name: 'ÉPICA',
          borderColor: const Color(0xFFD500F9),
          gradientColors: [const Color(0xFFEA80FC), const Color(0xFFAA00FF), const Color(0xFF4A148C)],
          glowColor: Colors.purpleAccent.withValues(alpha: 0.6),
          badgeBg: Colors.purple.shade900,
        );
      case 'rare':
      case 'rara':
        return _RarityTheme(
          name: 'RARA',
          borderColor: const Color(0xFF00E5FF),
          gradientColors: [const Color(0xFF80D8FF), const Color(0xFF00B0FF), const Color(0xFF01579B)],
          glowColor: Colors.cyanAccent.withValues(alpha: 0.6),
          badgeBg: Colors.cyan.shade900,
        );
      case 'common':
      case 'común':
      case 'comun':
      default:
        return _RarityTheme(
          name: 'COMÚN',
          borderColor: const Color(0xFFCFD8DC),
          gradientColors: [const Color(0xFFECEFF1), const Color(0xFF90A4AE), const Color(0xFF37474F)],
          glowColor: Colors.blueGrey.withValues(alpha: 0.3),
          badgeBg: Colors.blueGrey.shade800,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getRarityTheme();

    // Matriz de transformación 3D con perspectiva en el eje Z
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // Perspectiva 3D suave
      ..rotateX(_rotX)
      ..rotateY(_rotY);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.glowColor,
                blurRadius: widget.isHolographic ? 25 : 12,
                spreadRadius: widget.isHolographic ? 4 : 1,
                offset: Offset(_rotY * 20, _rotX * 20),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: Offset(_rotY * 15 + 5, _rotX * 15 + 5),
              ),
            ],
          ),
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // ==========================================
                  // CAPA 1: FONDO / ILUSTRACIÓN BASE (PARALLAX)
                  // ==========================================
                  Positioned.fill(
                    child: Transform.translate(
                      // Traslación opuesta para dar profundidad al fondo
                      offset: Offset(_rotY * -15, _rotX * -15),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: theme.gradientColors,
                          ),
                        ),
                        child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                            ? Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderBackground(theme),
                              )
                            : _buildPlaceholderBackground(theme),
                      ),
                    ),
                  ),

                  // Gradiante de viñeta oscura para mejor contraste del texto
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ==========================================
                  // CAPA 2: MARCO Y DETALLES PRINCIPALES
                  // ==========================================
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.borderColor,
                          width: 3.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Badges (Rareza + Holográfica)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.badgeBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.borderColor.withValues(alpha: 0.8)),
                                  ),
                                  child: Text(
                                    theme.name,
                                    style: GoogleFonts.orbitron(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                if (widget.isHolographic)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.4),
                                      border: Border.all(color: Colors.white70),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.amberAccent,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),

                            const Spacer(),

                            // Información de Provincia y Categoría (Parallax intermedio)
                            Transform.translate(
                              offset: Offset(_rotY * 5, _rotX * 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.province != null && widget.province!.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.white70, size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          widget.province!.toUpperCase(),
                                          style: GoogleFonts.robotoCondensed(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 2),

                                  // Título Principal de la Tarjeta
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      shadows: [
                                        const Shadow(
                                          blurRadius: 8,
                                          color: Colors.black,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (widget.description != null && widget.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ==========================================
                  // CAPA 3: CAPA OVERLAY HOLOGRÁFICA (HOLO FOIL)
                  // ==========================================
                  if (widget.isHolographic)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _HolographicFoilPainter(
                            rotX: _rotX,
                            rotY: _rotY,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBackground(_RarityTheme theme) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style,
              size: 64,
              color: theme.borderColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Exploria Card',
              style: GoogleFonts.orbitron(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tema visual interno según la rareza de la tarjeta
class _RarityTheme {
  final String name;
  final Color borderColor;
  final List<Color> gradientColors;
  final Color glowColor;
  final Color badgeBg;

  _RarityTheme({
    required this.name,
    required this.borderColor,
    required this.gradientColors,
    required this.glowColor,
    required this.badgeBg,
  });
}

/// CustomPainter para dibujar el brillo y reflector tornasolado holográfico dinámico
class _HolographicFoilPainter extends CustomPainter {
  final double rotX;
  final double rotY;

  _HolographicFoilPainter({
    required this.rotX,
    required this.rotY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Calcular la posición del rayo de luz reflectante según el ángulo de inclinación
    final double angle = math.atan2(rotX, rotY);
    final double distance = math.sqrt(rotX * rotX + rotY * rotY);
    final double normalizedShift = (distance / 0.40).clamp(0.0, 1.0);

    // Gradiente holográfico dinámico tipo prisma tornasolado (Cian, Magenta, Amarillo, Blanco)
    final holoGradient = LinearGradient(
      begin: Alignment(
        math.cos(angle) * (1.5 + normalizedShift),
        math.sin(angle) * (1.5 + normalizedShift),
      ),
      end: Alignment(
        -math.cos(angle) * (1.5 + normalizedShift),
        -math.sin(angle) * (1.5 + normalizedShift),
      ),
      colors: [
        Colors.transparent,
        const Color(0x6600FFFF), // Cian tornasolado
        const Color(0x66FF00FF), // Magenta tornasolado
        const Color(0x77FFFF00), // Amarillo prisma
        const Color(0x99FFFFFF), // Destello blanco reflectante
        const Color(0x6600FFFF),
        Colors.transparent,
      ],
      stops: const [0.0, 0.2, 0.4, 0.55, 0.7, 0.85, 1.0],
    );

    final Paint holoPaint = Paint()
      ..shader = holoGradient.createShader(rect)
      ..blendMode = BlendMode.colorDodge; // Excelente para simulaciones de lámina de foil metálico

    canvas.drawRect(rect, holoPaint);

    // Destello secundario diagonal (Glint de brillo)
    final glintGradient = LinearGradient(
      begin: Alignment(-2.0 + rotY * 4, -2.0 + rotX * 4),
      end: Alignment(2.0 + rotY * 4, 2.0 + rotX * 4),
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.15 + (normalizedShift * 0.2)),
        Colors.transparent,
      ],
      stops: const [0.35, 0.5, 0.65],
    );

    final Paint glintPaint = Paint()
      ..shader = glintGradient.createShader(rect)
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(rect, glintPaint);
  }

  @override
  bool shouldRepaint(covariant _HolographicFoilPainter oldDelegate) {
    return oldDelegate.rotX != rotX || oldDelegate.rotY != rotY;
  }
}
