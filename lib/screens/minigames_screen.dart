import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

// ═══════════════════════════════════════════════════════════════
// SHARED CELEBRATION OVERLAY
// ═══════════════════════════════════════════════════════════════

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final x = p.startX + p.velocityX * t * size.width;
      final y = p.startY + p.velocityY * t * size.height + (t * t * 200);
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final rotation = t * p.rotationSpeed;

      if (y > size.height + 20 || opacity <= 0) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _ConfettiParticle {
  final double startX, startY;
  final double velocityX, velocityY;
  final Color color;
  final double size;
  final bool isCircle;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
    required this.isCircle,
    required this.rotationSpeed,
  });
}

class CelebrationOverlay extends StatefulWidget {
  final int particleCount;
  final VoidCallback? onComplete;

  const CelebrationOverlay({
    super.key,
    this.particleCount = 60,
    this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.particleCount, (_) {
      final colors = [
        const Color(0xFFF5C535),
        const Color(0xFF20D4A4),
        const Color(0xFF4A9BFF),
        const Color(0xFFFF6B00),
        const Color(0xFFE91E63),
        const Color(0xFF9C27B0),
        const Color(0xFF10B981),
      ];
      return _ConfettiParticle(
        startX: 0.3 + rng.nextDouble() * 0.4,
        startY: -0.05,
        velocityX: (rng.nextDouble() - 0.5) * 1.2,
        velocityY: 0.3 + rng.nextDouble() * 0.6,
        color: colors[rng.nextInt(colors.length)],
        size: 3 + rng.nextDouble() * 5,
        isCircle: rng.nextBool(),
        rotationSpeed: (rng.nextDouble() - 0.5) * 12,
      );
    });

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..forward().then((_) {
        widget.onComplete?.call();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MINIGAMES LIST
// ═══════════════════════════════════════════════════════════════

class MinigamesScreen extends StatefulWidget {
  const MinigamesScreen({super.key});

  @override
  State<MinigamesScreen> createState() => _MinigamesScreenState();
}

class _MinigamesScreenState extends State<MinigamesScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('MinigamesScreen');
  }

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
        title: const Text('Gana probando suerte'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minijuegos',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Probá tu suerte y ganá PE extra (máx. 2 jugadas diarias)',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildGameCard(
              context: context,
              card: card,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: TablerIcons.dice_6,
              iconColor: const Color(0xFFF59E0B),
              title: 'Ruleta de la fortuna',
              subtitle: 'Girá la ruleta (hasta 2 giros diarios) y ganá PE',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WheelGameScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _buildGameCard(
              context: context,
              card: card,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: TablerIcons.palette,
              iconColor: const Color(0xFF9C27B0),
              title: 'Raspaditas',
              subtitle: 'Rascá y descubrí tu premio (hasta 2 raspadas diarias)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScratchCardScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required Color card,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
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
              Icon(TablerIcons.chevron_right, color: textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RULETA DE LA FORTUNA (Máx 2 giros por día)
// ═══════════════════════════════════════════════════════════════

class WheelGameScreen extends StatefulWidget {
  const WheelGameScreen({super.key});

  @override
  State<WheelGameScreen> createState() => _WheelGameScreenState();
}

class _WheelGameScreenState extends State<WheelGameScreen>
    with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  late AnimationController _resultController;
  late Animation<double> _resultScale;
  late Animation<double> _resultGlow;
  final Random _random = Random();

  bool _spinning = false;
  bool _canSpin = true;
  int _spinsToday = 0;
  bool _loadingStorage = true;
  int _result = 0;
  bool _showResult = false;
  bool _showConfetti = false;

  static const _segments = [
    _WheelSegment(label: '5 PE', color: Color(0xFF20D4A4), pe: 5),
    _WheelSegment(label: 'Sin suerte', color: Color(0xFF64748B), pe: 0),
    _WheelSegment(label: '20 PE', color: Color(0xFFF59E0B), pe: 20),
    _WheelSegment(label: '1 PE', color: Color(0xFF4A9BFF), pe: 1),
    _WheelSegment(label: 'Intenta de nuevo', color: Color(0xFF475569), pe: 0),
    _WheelSegment(label: '50 PE', color: Color(0xFFFF6B00), pe: 50),
    _WheelSegment(label: '10 PE', color: Color(0xFF10B981), pe: 10),
    _WheelSegment(label: 'Sin premio', color: Color(0xFF334155), pe: 0),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    _resultGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.easeIn),
    );

    _loadSpinCount();
  }

  Future<void> _loadSpinCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: 'wheel_date');
    final savedSpins = int.tryParse(await _storage.read(key: 'wheel_spins') ?? '0') ?? 0;

    if (savedDate == today) {
      _spinsToday = savedSpins;
    } else {
      _spinsToday = 0;
      await _storage.write(key: 'wheel_date', value: today);
      await _storage.write(key: 'wheel_spins', value: '0');
    }

    if (mounted) {
      setState(() {
        _canSpin = _spinsToday < 2;
        _loadingStorage = false;
      });
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;

    _spinsToday++;
    _canSpin = _spinsToday < 2;
    await _storage.write(key: 'wheel_spins', value: '$_spinsToday');

    setState(() {
      _spinning = true;
      _showResult = false;
      _showConfetti = false;
    });

    final targetIndex = _random.nextInt(_segments.length);
    final segmentAngle = 2 * pi / _segments.length;
    final targetAngle = targetIndex * segmentAngle;
    final spins = 5 + _random.nextInt(3);
    final totalAngle = spins * 2 * pi + targetAngle;

    _spinController.reset();
    _spinAnimation = Tween<double>(begin: 0, end: totalAngle).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    _spinController.forward().then((_) {
      final peWon = _segments[targetIndex].pe;
      setState(() {
        _result = peWon;
        _showResult = true;
        _spinning = false;
        _showConfetti = peWon > 0;
      });
      _resultController.forward(from: 0);
    });
  }

  void _tryAgain() {
    setState(() {
      _showResult = false;
      _showConfetti = false;
      _resultController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Ruleta de la fortuna'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: _loadingStorage
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chip con contador de intentos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _canSpin
                                ? const Color(0xFFF59E0B).withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _canSpin
                                  ? const Color(0xFFF59E0B).withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _canSpin ? TablerIcons.stars : TablerIcons.lock,
                                size: 16,
                                color: _canSpin ? const Color(0xFFF59E0B) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Giros hoy: $_spinsToday / 2',
                                style: TextStyle(
                                  color: _canSpin ? const Color(0xFFF59E0B) : Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Wheel
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: AnimatedBuilder(
                            animation: _spinAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _WheelPainter(
                                  rotation: _spinAnimation.value,
                                  segments: _segments,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black26, blurRadius: 8),
                                      ],
                                    ),
                                    child: const Icon(TablerIcons.player_play, size: 36, color: Color(0xFF112A46)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(TablerIcons.caret_up, size: 40, color: Color(0xFFFF6B00)),
                        const SizedBox(height: 20),

                        // Result or Spin button
                        if (_showResult) ...[
                          AnimatedBuilder(
                            animation: _resultController,
                            builder: (context, child) {
                              final isWin = _result > 0;
                              final cardColor = isWin ? const Color(0xFF20D4A4) : const Color(0xFFE53935);
                              return Transform.scale(
                                scale: _resultScale.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: cardColor.withOpacity(0.3 * _resultGlow.value),
                                        blurRadius: 24 * _resultGlow.value,
                                        spreadRadius: 4 * _resultGlow.value,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isWin ? TablerIcons.stars : TablerIcons.circle_x,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isWin ? '¡Ganaste!' : 'Sin suerte esta vez',
                                            style: GoogleFonts.montserrat(
                                              color: Colors.white.withOpacity(0.95),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isWin ? '+$_result PE' : '❌ 0 PE',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          if (_canSpin)
                            ElevatedButton.icon(
                              onPressed: _tryAgain,
                              icon: const Icon(TablerIcons.reload, size: 20),
                              label: Text(
                                'Volver a intentar (Queda 1 giro)',
                                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(TablerIcons.lock, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Límite alcanzado (2/2 giros). ¡Volvé mañana!',
                                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _canSpin ? _spin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              _spinning
                                  ? 'Girando...'
                                  : (_canSpin ? '¡Girar!' : 'Límite alcanzado (2/2)'),
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!_canSpin)
                            Text(
                              'Ya realizaste tus 2 giros de hoy. Volvé mañana.',
                              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Confetti overlay
                if (_showConfetti)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CelebrationOverlay(
                        particleCount: 80,
                        onComplete: () => setState(() => _showConfetti = false),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WheelSegment {
  final String label;
  final Color color;
  final int pe;
  const _WheelSegment({required this.label, required this.color, required this.pe});
}

class _WheelPainter extends CustomPainter {
  final double rotation;
  final List<_WheelSegment> segments;

  _WheelPainter({required this.rotation, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / segments.length;

    for (var i = 0; i < segments.length; i++) {
      final startAngle = rotation + i * segmentAngle;
      final paint = Paint()..color = segments[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final labelAngle = startAngle + segmentAngle / 2;
      final labelRadius = radius * 0.65;
      final labelPos = Offset(
        center.dx + cos(labelAngle) * labelRadius,
        center.dy + sin(labelAngle) * labelRadius,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.rotate(labelAngle + pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.rotation != rotation;
}

// ═══════════════════════════════════════════════════════════════
// RASPAGANA (30% probabilidad de ganar + Máx 2 jugadas al día)
// ═══════════════════════════════════════════════════════════════

class ScratchCardScreen extends StatefulWidget {
  const ScratchCardScreen({super.key});

  @override
  State<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends State<ScratchCardScreen>
    with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  final Random _random = Random();
  int _prize = 0;
  bool _revealed = false;
  bool _canPlay = true;
  int _scratchesToday = 0;
  bool _loadingStorage = true;
  double _scratchPercent = 0;
  static const _threshold = 0.45;
  final List<Offset> _scratchPoints = [];
  final GlobalKey _scratchKey = GlobalKey();

  late AnimationController _resultController;
  late Animation<double> _resultScale;
  late Animation<double> _resultGlow;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    _resultGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.easeIn),
    );

    _generatePrize();
    _loadScratchCount();
  }

  void _generatePrize() {
    // 30% chance of winning
    final isWin = _random.nextDouble() < 0.30;
    if (isWin) {
      _prize = [5, 10, 15, 20, 25, 50][_random.nextInt(6)];
    } else {
      _prize = 0;
    }
  }

  Future<void> _loadScratchCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: 'scratch_date');
    final savedCount = int.tryParse(await _storage.read(key: 'scratch_count') ?? '0') ?? 0;

    if (savedDate == today) {
      _scratchesToday = savedCount;
    } else {
      _scratchesToday = 0;
      await _storage.write(key: 'scratch_date', value: today);
      await _storage.write(key: 'scratch_count', value: '0');
    }

    if (mounted) {
      setState(() {
        _canPlay = _scratchesToday < 2;
        _loadingStorage = false;
      });
    }
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _checkReveal() async {
    if (!_revealed && _scratchPercent >= _threshold && _canPlay) {
      _scratchesToday++;
      _canPlay = _scratchesToday < 2;
      await _storage.write(key: 'scratch_count', value: '$_scratchesToday');

      setState(() {
        _revealed = true;
        _showConfetti = _prize > 0;
      });
      _resultController.forward(from: 0);
    }
  }

  void _tryAgain() {
    _generatePrize();
    setState(() {
      _scratchPoints.clear();
      _scratchPercent = 0;
      _revealed = false;
      _showConfetti = false;
      _resultController.reset();
    });
  }

  void _calculateScratchPercentage(Offset localPos) {
    _scratchPoints.add(localPos);

    const cellSize = 12.0;
    final cols = (260 / cellSize).ceil();
    final rows = (260 / cellSize).ceil();
    int scratchedCells = 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cellCenter = Offset(
          c * cellSize + cellSize / 2,
          r * cellSize + cellSize / 2,
        );
        final brushRadius = 30.0;
        for (final pt in _scratchPoints) {
          if ((pt - cellCenter).distance < brushRadius) {
            scratchedCells++;
            break;
          }
        }
      }
    }

    final totalCells = cols * rows;
    _scratchPercent = (scratchedCells / totalCells).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Raspaditas'), backgroundColor: bg, elevation: 0),
      body: _loadingStorage
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chip con contador de intentos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _canPlay
                                ? const Color(0xFFFF6B00).withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _canPlay
                                  ? const Color(0xFFFF6B00).withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _canPlay ? TablerIcons.palette : TablerIcons.lock,
                                size: 16,
                                color: _canPlay ? const Color(0xFFFF6B00) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Raspadas hoy: $_scratchesToday / 2',
                                style: TextStyle(
                                  color: _canPlay ? const Color(0xFFFF6B00) : Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          _canPlay || _revealed
                              ? 'Rascá la tarjeta para descubrir tu premio'
                              : 'Límite alcanzado por hoy. ¡Volvé mañana!',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Scratch card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _revealed
                                    ? (_prize > 0
                                        ? const Color(0xFF20D4A4).withAlpha(60)
                                        : const Color(0xFFE53935).withAlpha(60))
                                    : Colors.black.withAlpha(20),
                                blurRadius: _revealed ? 24 : 16,
                                offset: const Offset(0, 6),
                                spreadRadius: _revealed ? 4 : 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                // Fondo con premio o X grande al perder
                                Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _revealed
                                          ? (_prize > 0
                                              ? [const Color(0xFFE8F8F0), const Color(0xFFD1F5E4)]
                                              : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)])
                                          : [card, card],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: _revealed ? 1.2 : 1.0,
                                        duration: const Duration(milliseconds: 400),
                                        child: Icon(
                                          _revealed
                                              ? (_prize > 0 ? TablerIcons.star_filled : TablerIcons.circle_x)
                                              : TablerIcons.help_circle,
                                          color: _revealed
                                              ? (_prize > 0 ? const Color(0xFFF5C535) : const Color(0xFFE53935))
                                              : AppColors.textSecondaryLight.withOpacity(0.3),
                                          size: 68,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _revealed
                                            ? (_prize > 0 ? '+$_prize PE' : '❌ SIN SUERTE')
                                            : '?',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: _revealed
                                              ? (_prize > 0 ? const Color(0xFF20D4A4) : const Color(0xFFE53935))
                                              : AppColors.textSecondaryLight.withOpacity(0.2),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _revealed
                                            ? (_prize > 0 ? '¡Felicidades!' : '¡Seguí intentando!')
                                            : '¿Cuánto ganás?',
                                        style: TextStyle(
                                          color: _revealed
                                              ? (_prize > 0 ? const Color(0xFF20D4A4) : const Color(0xFFE53935))
                                              : AppColors.textSecondaryLight.withOpacity(0.3),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Scratch overlay
                                if (!_revealed && _canPlay)
                                  GestureDetector(
                                    key: _scratchKey,
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _calculateScratchPercentage(details.localPosition);
                                      });
                                      _checkReveal();
                                    },
                                    child: CustomPaint(
                                      painter: _ScratchPainter(
                                        points: _scratchPoints,
                                        color: const Color(0xFFFF6B00),
                                      ),
                                      size: const Size(260, 260),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Progress indicator
                        if (!_revealed && _scratchPoints.isNotEmpty && _canPlay) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(TablerIcons.brush, size: 14, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 120,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _scratchPercent / _threshold,
                                    minHeight: 6,
                                    backgroundColor: AppColors.textSecondaryLight.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(_scratchPercent * 100).round()}%',
                                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Result banner and action buttons
                        if (_revealed) ...[
                          AnimatedBuilder(
                            animation: _resultController,
                            builder: (context, child) {
                              final isWin = _prize > 0;
                              final cardColor = isWin ? const Color(0xFF20D4A4) : const Color(0xFFE53935);
                              return Transform.scale(
                                scale: _resultScale.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: cardColor.withOpacity(0.3 * _resultGlow.value),
                                        blurRadius: 24 * _resultGlow.value,
                                        spreadRadius: 4 * _resultGlow.value,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        isWin ? '¡Ganaste!' : 'Sigue intentando',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isWin ? '+$_prize PE' : '❌ 0 PE',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          if (_canPlay)
                            ElevatedButton.icon(
                              onPressed: _tryAgain,
                              icon: const Icon(TablerIcons.reload, size: 20),
                              label: Text(
                                'Volver a intentar (Queda 1 jugada)',
                                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            )
                          else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(TablerIcons.lock, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Límite alcanzado (2/2 raspadas). ¡Volvé mañana!',
                                    style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Confetti overlay
                if (_showConfetti)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CelebrationOverlay(
                        particleCount: 70,
                        onComplete: () => setState(() => _showConfetti = false),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ScratchPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _ScratchPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Base orange layer
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      paint,
    );

    // Dot pattern
    final dotPaint = Paint()..color = Colors.white.withAlpha(30);
    for (double x = 10; x < size.width; x += 20) {
      for (double y = 10; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 2, dotPaint);
      }
    }

    // Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'RISCÁ AQUÍ',
        style: TextStyle(
          color: Colors.white.withAlpha(180),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );

    // Erase scratched areas with thick brush
    final eraser = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 50
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, eraser);
    }
  }

  @override
  bool shouldRepaint(_ScratchPainter old) => old.points.length != points.length;
}
