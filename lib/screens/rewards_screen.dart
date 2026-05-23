import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Datos de usuario
  int _coins = 0;
  int _pepitas = 0;
  int _streak = 0;

  // Tab "Mis QRs" + "Historial"
  List<Redemption> _redemptions = [];

  // Tab "Ofertas" â€” comercios con oferta activa
  List<Business> _offers = [];

  bool _loading = true;
  String? _error;

  // QuÃ© comercio estÃ¡ procesando compra de cupÃ³n
  final Set<String> _purchasing = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getStats(),
        ApiService.getRedemptions(),
        ApiService.getNearbyBusinesses(0, 0),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final redemptionList = results[1] as List<dynamic>;
      final businessList = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          _coins = stats['coins'] ?? 0;
          _pepitas = stats['pepitas_balance'] ?? _pepitas;
          _streak = stats['streak'] ?? 0;
          _redemptions = redemptionList
              .map((r) => Redemption.fromJson(r))
              .toList();
          _offers = businessList
              .map((b) => Business.fromJson(b))
              .where((b) => b.offer != null && b.offerCost > 0 && b.isActive)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Redemption> get _pending =>
      _redemptions.where((r) => r.status == 'pending').toList();
  List<Redemption> get _history =>
      _redemptions.where((r) => r.status != 'pending').toList();

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? _buildError(textPrimary, textSecondary)
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: Column(
                  children: [
                    _buildHeader(isDark),
                    _buildTabBar(card, textSecondary),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Ofertas disponibles
                          _buildOffersTab(
                            isDark,
                            card,
                            textPrimary,
                            textSecondary,
                          ),
                          // Tab 2: Mis QRs activos
                          _buildRedemptionList(
                            _pending,
                            isDark,
                            card,
                            textPrimary,
                            textSecondary,
                            isPending: true,
                          ),
                          // Tab 3: Historial
                          _buildRedemptionList(
                            _history,
                            isDark,
                            card,
                            textPrimary,
                            textSecondary,
                            isPending: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // â”€â”€ Error â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildError(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'VerificÃ¡ tu conexiÃ³n e intentÃ¡ de nuevo.',
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Header con saldo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF5E471A), Color(0xFF7A5A20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFD88A), Color(0xFFF7B94A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(isDark ? 35 : 120)),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFE19A2F)).withAlpha(
              isDark ? 40 : 70,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(170),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.diamond_rounded,
                  size: 20,
                  color: Color(0xFF7A4A00),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_pepitas',
                style: const TextStyle(
                  color: Color(0xFF3A2600),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pepitas',
                    style: TextStyle(
                      color: Color(0xFF6A4300),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_coins monedas',
                    style: const TextStyle(
                      color: Color(0xFF7A5A20),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFF6A4300),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_streak dÃ­as de racha',
                  style: const TextStyle(
                    color: Color(0xFF5C3600),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Tab bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTabBar(Color card, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            const Tab(text: 'Ofertas'),
            Tab(text: 'Mis QRs (${_pending.length})'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 1 â€” Ofertas disponibles
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildOffersTab(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_offers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_rounded,
                size: 64,
                color: textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin ofertas disponibles',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los comercios participantes\naparecerÃ¡n acÃ¡.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: _offers.length,
      itemBuilder: (_, i) =>
          _buildOfferCard(_offers[i], isDark, card, textPrimary, textSecondary),
    );
  }

  Widget _buildOfferCard(
    Business business,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final canAfford = _pepitas >= business.offerCost;
    final isPurchasing = _purchasing.contains(business.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Imagen del local â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (business.imageUrl != null)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(
                  business.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: AppColors.primary.withAlpha(15),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    height: 130,
                    color: AppColors.primary.withAlpha(15),
                    child: const Center(
                      child: Icon(
                        Icons.store_mall_directory_rounded,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 80,
                width: double.infinity,
                color: AppColors.primary.withAlpha(12),
                child: const Center(
                  child: Icon(
                    Icons.store_mall_directory_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              ),

            // â”€â”€ Contenido â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Oferta
                  Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        color: AppColors.primary,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          business.offer!,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Costo en monedas
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                            color: canAfford
                              ? const Color(0xFFF5D06F).withAlpha(35)
                              : Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.diamond_rounded,
                              color: canAfford
                                  ? AppColors.primaryLight
                                  : Colors.red.shade400,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${business.offerCost} pepitas',
                              style: TextStyle(
                                color: canAfford
                                    ? AppColors.primaryLight
                                    : Colors.red.shade400,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // BotÃ³n canjear
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: (canAfford && !isPurchasing)
                              ? () => _purchaseCoupon(business)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isPurchasing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  canAfford ? 'Canjear' : 'Sin pepitas',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

  Future<void> _purchaseCoupon(Business business) async {
    setState(() => _purchasing.add(business.id));
    try {
      final result = await ApiService.purchaseCoupon(
        business.id,
        currency: 'pepitas',
      );
      if (!mounted) return;

      if (result['id'] != null) {
        // Ã‰xito
        final newBalance =
            result['new_balance'] ?? (_pepitas - business.offerCost);
        setState(() {
          _pepitas = newBalance;
          // Agregar a redemptions localmente para que aparezca en "Mis QRs"
          _redemptions.insert(
            0,
            Redemption.fromJson({...result, 'status': 'pending'}),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Â¡CupÃ³n obtenido! MostrÃ¡ el QR en ${business.name}.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Ir al tab "Mis QRs"
        _tabController.animateTo(1);
      } else {
        final msg = result['error'] ?? 'Error al canjear.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error de conexiÃ³n.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing.remove(business.id));
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TABS 2 & 3 â€” Lista de Redemptions
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildRedemptionList(
    List<Redemption> items,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary, {
    required bool isPending,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPending ? Icons.qr_code_2_rounded : Icons.history_rounded,
                size: 64,
                color: textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                isPending ? 'No tenÃ©s QRs activos' : 'Sin historial todavÃ­a',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPending
                    ? 'CanjeÃ¡ una oferta en la pestaÃ±a\n"Ofertas" para obtener tu QR.'
                    : 'Los canjes validados o expirados\naparecerÃ¡n acÃ¡.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildRedemptionCard(
        items[i],
        isDark,
        card,
        textPrimary,
        textSecondary,
      ),
    );
  }

  Widget _buildRedemptionCard(
    Redemption r,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isPending = r.status == 'pending';
    final isValidated = r.status == 'validated';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (isPending) {
      statusColor = AppColors.primary;
      statusLabel = 'Activo';
      statusIcon = Icons.qr_code_2_rounded;
    } else if (isValidated) {
      statusColor = const Color(0xFF4A9955);
      statusLabel = 'Validado';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Expirado';
      statusIcon = Icons.timer_off_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
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
                // Imagen pequeÃ±a o Ã­cono
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: r.businessImage != null
                      ? Image.network(
                          r.businessImage!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _storeIcon(),
                        )
                      : _storeIcon(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.businessName,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (r.offerTitle != null)
                        Text(
                          r.offerTitle!,
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  color: AppColors.primaryLight,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  r.pepitasSpent > 0
                      ? '${r.pepitasSpent} pepitas'
                      : '${r.coinsSpent} monedas',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const Spacer(),
                if (r.redeemedAt != null)
                  Text(
                    _formatDate(r.redeemedAt!),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _showQrSheet(
                  context,
                  r,
                  isDark,
                  textPrimary,
                  textSecondary,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDark : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: r.qrCodeHash,
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: Colors.transparent,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'TocÃ¡ para ampliar Â· Mostralo en el comercio',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _storeIcon() {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.primary.withAlpha(20),
      child: const Icon(
        Icons.store_mall_directory_rounded,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  void _showQrSheet(
    BuildContext context,
    Redemption r,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: r.qrCodeHash,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.transparent,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              r.businessName,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (r.offerTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                r.offerTitle!,
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'MostrÃ¡ este QR en el comercio para canjear el premio',
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
