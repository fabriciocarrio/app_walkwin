import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BusinessProfileScreen extends StatefulWidget {
  final Business business;

  const BusinessProfileScreen({super.key, required this.business});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  int _coins = 0;
  int _pepitas = 0;
  bool _loadingCoins = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    try {
      final stats = await ApiService.getStats();
      if (mounted) {
        setState(() {
          _coins = stats['coins'] ?? 0;
          _pepitas = stats['pepitas_balance'] ?? 0;
          _loadingCoins = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCoins = false);
    }
  }

  Future<void> _purchaseCoupon() async {
    setState(() => _purchasing = true);
    try {
      final result = await ApiService.purchaseCoupon(
        widget.business.id,
        currency: 'pepitas',
      );
      if (!mounted) return;

      if (result['qr_code_hash'] != null || result['id'] != null) {
        // Éxito — actualizar saldo local
        setState(() {
          _pepitas =
              result['new_balance'] ?? _pepitas - widget.business.offerCost;
          _purchasing = false;
        });
        _showResultDialog(
          success: true,
          message: '¡Cupón canjeado! Mostrá el QR en el comercio.',
        );
      } else {
        setState(() => _purchasing = false);
        _showResultDialog(
          success: false,
          message: result['error'] ?? 'No se pudo canjear el cupón.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchasing = false);
        _showResultDialog(
          success: false,
          message: 'Error de conexión.',
        );
      }
    }
  }

  void _showResultDialog({required bool success, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? AppColors.primary : Colors.orange.shade600,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final b = widget.business;
    final hasOffer = b.offer != null && b.offerCost > 0;
    final canRedeem = _pepitas >= b.offerCost;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar con imagen ──────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.cardDark : AppColors.primary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: b.imageUrl != null
                  ? Image.network(
                      b.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder(),
                    )
                  : _heroPlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nombre + descripción ──────────────────
                  Text(
                    b.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (b.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      b.description!,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Info check-in ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco_rounded,
                            color: AppColors.primary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check-in en este comercio',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '+${b.checkinRewardCoins} monedas',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Radio',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 11),
                            ),
                            Text(
                              '${b.checkinRadiusMeters}m',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Cupones disponibles ─────────────────────
                  Text(
                    'Cupones disponibles',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!hasOffer)
                    _emptyOffers(textSecondary, card)
                  else
                    _buildCouponCard(
                      b, card, textPrimary, textSecondary, canRedeem),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Barra inferior con saldo ────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 20),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.diamond_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            _loadingCoins
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Text(
                    '$_pepitas pepitas',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
            const Spacer(),
            Text(
              'Saldo para canjear',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(
    Business b,
    Color card,
    Color textPrimary,
    Color textSecondary,
    bool canRedeem,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded,
                      color: Color(0xFFE8A020), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.offer!,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Costo + botón canjear
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE8A020).withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_rounded,
                          color: Color(0xFFE8A020), size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '${b.offerCost} pepitas',
                        style: const TextStyle(
                          color: Color(0xFFE8A020),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: (canRedeem && !_purchasing)
                        ? _purchaseCoupon
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canRedeem
                          ? const Color(0xFFE8A020)
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _purchasing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                          canRedeem ? 'Canjear' : 'Sin pepitas',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyOffers(Color textSecondary, Color card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.local_offer_outlined,
              color: textSecondary, size: 36),
          const SizedBox(height: 10),
          Text(
            'No hay cupones disponibles\nen este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      color: AppColors.primary.withAlpha(25),
      child: const Center(
        child: Icon(
          Icons.store_mall_directory_rounded,
          color: AppColors.primary,
          size: 60,
        ),
      ),
    );
  }
}
