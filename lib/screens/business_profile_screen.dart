import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class BusinessProfileScreen extends StatefulWidget {
  final Business business;

  const BusinessProfileScreen({super.key, required this.business});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  int _peBalance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('BusinessProfileScreen');
    AnalyticsService.instance.trackEvent('business_profile_viewed', properties: {
      'business_id': widget.business.id,
      'name': widget.business.name,
    });
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final stats = await ApiService.getStats();
      if (mounted) {
        setState(() {
          _peBalance = stats['pe_balance'] ?? 0;
          _loadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  void _showRedeemSheet(BusinessOffer offer) {
    final business = widget.business;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Canjeá tu premio',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresá el código de 5 dígitos\nque te dio ${business.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: codeController,
                      maxLength: 5,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '0 0 0 0 0',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade300,
                          letterSpacing: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length != 5) {
                          return 'Ingresá el código completo';
                        }
                        if (!RegExp(r'^\d{5}$').hasMatch(v)) {
                          return 'Solo números';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() {});
                          try {
                            final result = await ApiService.redeemWithCode(
                              business.id,
                              codeController.text.trim(),
                              offerId: offer.id,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            setState(() {
                              _peBalance =
                                  (result['new_balance'] as num?)?.toInt() ??
                                      _peBalance;
                            });
                            _showResultDialog(
                              success: true,
                              message:
                                  '¡Cupón canjeado en ${business.name}!',
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A67F8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Canjear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
              success ? TablerIcons.circle_check : TablerIcons.alert_circle,
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
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final b = widget.business;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  TablerIcons.arrow_back,
                  color: Colors.white,
                ),
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

                  if (b.businessHours.isNotEmpty) ...[
                    _buildInfoCard(
                      icon: TablerIcons.clock,
                      title: 'Horarios',
                      value: b.hoursSummary,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 12),
                  ],

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          TablerIcons.leaf,
                          color: AppColors.primary,
                          size: 28,
                        ),
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
                                '+${b.checkinRewardCoins} PE',
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
                                color: textSecondary,
                                fontSize: 11,
                              ),
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

                  Text(
                    'Cupones disponibles',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Builder(
                    builder: (context) {
                      final allOffers = [...b.offers];
                      // Fallback para comercio legacy sin offers array
                      if (allOffers.isEmpty && b.offer != null && b.offerCost > 0) {
                        allOffers.add(BusinessOffer(
                          id: 'legacy_${b.id}',
                          title: b.offer!,
                          peCost: b.offerCost,
                          limitPeriod: 'none',
                          isActive: b.isActive,
                        ));
                      }

                      if (allOffers.isEmpty) {
                        return _emptyOffers(textSecondary, card);
                      }

                      return Column(
                        children: allOffers.map((offer) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildOfferCard(
                            offer: offer,
                            card: card,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        )).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
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
              TablerIcons.diamond,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            _loadingBalance
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    '$_peBalance PE',
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard({
    required BusinessOffer offer,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final canRedeem = _peBalance >= offer.peCost && !offer.isSoldOut;

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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
                      ? Image.network(
                          offer.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              TablerIcons.tag,
                              color: Color(0xFFE8A020),
                              size: 20,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            TablerIcons.tag,
                            color: Color(0xFFE8A020),
                            size: 20,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (offer.description != null && offer.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.description!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE8A020).withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        TablerIcons.diamond,
                        color: Color(0xFFE8A020),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${offer.peCost} PE',
                        style: const TextStyle(
                          color: Color(0xFFE8A020),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (offer.hasStockLimit) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: offer.isSoldOut
                          ? Colors.red.withAlpha(15)
                          : Colors.blue.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      offer.isSoldOut
                          ? 'Agotado'
                          : 'Stock: ${offer.remainingStock}/${offer.totalStock}',
                      style: TextStyle(
                        color: offer.isSoldOut
                            ? Colors.red.shade600
                            : Colors.blue.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: canRedeem ? () => _showRedeemSheet(offer) : null,
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
                    child: Text(
                      offer.isSoldOut
                          ? 'Sin stock'
                          : canRedeem
                              ? 'Canjear'
                              : 'PE insuficientes',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
          Icon(TablerIcons.tag, color: textSecondary, size: 36),
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
          TablerIcons.building_store,
          color: AppColors.primary,
          size: 60,
        ),
      ),
    );
  }
}
