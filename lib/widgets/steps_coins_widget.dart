import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class StepsCoinsWidget extends StatefulWidget {
  final int steps;
  final int coins;
  final VoidCallback? onCoinsChanged;
  final bool isCompact;

  const StepsCoinsWidget({
    super.key,
    required this.steps,
    required this.coins,
    this.onCoinsChanged,
    this.isCompact = false,
  });

  @override
  State<StepsCoinsWidget> createState() => _StepsCoinsWidgetState();
}

class _StepsCoinsWidgetState extends State<StepsCoinsWidget>
    with TickerProviderStateMixin {
  late AnimationController _coinsAnimationController;
  late Animation<double> _coinsScaleAnimation;
  late Animation<double> _coinsOpacityAnimation;
  late AnimationController _stepsAnimationController;
  late Animation<Offset> _stepsOffsetAnimation;
  int _previousCoins = 0;
  int _previousSteps = 0;

  @override
  void initState() {
    super.initState();
    _previousCoins = widget.coins;
    _previousSteps = widget.steps;
    _setupAnimations();
  }

  void _setupAnimations() {
    _coinsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _coinsScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _coinsAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _coinsOpacityAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _coinsAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Animación de caminata para los pasos
    _stepsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _stepsOffsetAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.08, -0.08),
        ).animate(
          CurvedAnimation(
            parent: _stepsAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void didUpdateWidget(StepsCoinsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animación para pasos
    if (oldWidget.steps != widget.steps && widget.steps > _previousSteps) {
      _previousSteps = widget.steps;
      _stepsAnimationController.forward().then((_) {
        _stepsAnimationController.reverse();
      });
    }

    // Animación para monedas
    if (oldWidget.coins != widget.coins && widget.coins > _previousCoins) {
      _previousCoins = widget.coins;
      _coinsAnimationController.forward().then((_) {
        _coinsAnimationController.reverse();
      });
      widget.onCoinsChanged?.call();
    }
  }

  @override
  void dispose() {
    _coinsAnimationController.dispose();
    _stepsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Colors.grey[900]?.withOpacity(0.8)
        : Colors.white.withOpacity(0.95);
    final textColor = isDark ? Colors.white : Colors.grey[900];
    final accentColor = const Color(0xFF6366F1);

    if (widget.isCompact) {
      return _buildCompactWidget(backgroundColor, textColor, accentColor);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Steps section
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SlideTransition(
                  position: _stepsOffsetAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                      CurvedAnimation(
                        parent: _stepsAnimationController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        TablerIcons.walk,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.steps}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pasos',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 60,
              child: VerticalDivider(color: Colors.grey[300], thickness: 1),
            ),
          ),
          // Coins section with animation
          Expanded(
            child: ScaleTransition(
              scale: _coinsScaleAnimation,
              child: FadeTransition(
                opacity: _coinsOpacityAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFD700).withOpacity(0.2),
                            const Color(0xFFFFA500).withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        TablerIcons.coin,
                        color: Color(0xFFFFD700),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.coins}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Puntos Exploria',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactWidget(
    Color? backgroundColor,
    Color? textColor,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Steps
          SlideTransition(
            position: _stepsOffsetAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                CurvedAnimation(
                  parent: _stepsAnimationController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(TablerIcons.walk, color: accentColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.steps}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Divider
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 16),
          // Coins
          ScaleTransition(
            scale: _coinsScaleAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  TablerIcons.coin,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.coins}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
