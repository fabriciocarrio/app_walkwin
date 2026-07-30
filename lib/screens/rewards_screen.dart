import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'business_profile_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _peBalance = 0;
  int _streak = 0;

  // Tab "Mis QRs" + "Historial"
  List<Redemption> _redemptions = [];

  // Tab "Ofertas" â€” comercios con oferta activa
  List<Business> _offers = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          _peBalance = stats['pe_balance'] ?? stats['coins'] ?? 0;
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
                          // Tab 2: Historial
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
              'Verificá tu conexión e intentá de nuevo.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premios',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                  const Text(
                    'Canjeá tus Puntos Exploria',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
              const Icon(Icons.help_outline, color: Color(0xFF0D1B2A)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: AssetImage('assets/premios-hero.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFEAA610),
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_peBalance',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'PE',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Puntos Exploria',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAA610).withAlpha(120),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFF5C3600),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_streak días de racha  >',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5C3600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Tab bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTabBar(Color card, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF1A67F8),
            borderRadius: BorderRadius.circular(25),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_offer_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Ofertas'),
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Historial'),
                ],
              ),
            ),
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
                'Los comercios participantes\naparecerán acá.',
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

    final featured = _offers.where((b) => b.isFeatured).toList();
    final regular = _offers.where((b) => !b.isFeatured).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        if (featured.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ofertas destacadas',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Ver todas >',
                style: TextStyle(
                  color: Color(0xFF1A67F8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...featured.map(
            (b) => _buildOfferCard(b, isDark, card, textPrimary, textSecondary),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.asset(
                  'assets/premios-banner.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 110,
                  alignment: Alignment.centerRight,
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¡Nuevas ofertas cada semana!',
                            style: TextStyle(
                              color: Color(0xFF1E293B), // Dark slate blue color
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Seguí explorando y sumando\nPuntos Exploria para canjear.',
                            style: TextStyle(
                              color: const Color(0xFF1E293B).withAlpha(200),
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        ...regular.map(
          (b) => _buildOfferCard(b, isDark, card, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _buildOfferCard(
    Business business,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final canAfford = _peBalance >= business.offerCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Col 1: Foto
          SizedBox(
            width: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: business.imageUrl != null
                      ? Image.network(business.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: business.imageUrl != null
                          ? Image.network(business.imageUrl!, fit: BoxFit.cover)
                          : const Icon(
                              Icons.store,
                              color: Colors.grey,
                              size: 20,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF4CAF50),
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${business.offerCost} PE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Col 2: Info + Botón
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Info
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BusinessProfileScreen(business: business),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.local_offer,
                                  size: 13,
                                  color: Colors.blue.shade400,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    business.offer ?? 'Oferta especial',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 13,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'San Juan',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 11,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Válido hasta 30/06/2025',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Fila 2: Botón Canjear
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: canAfford
                              ? () => _showRedeemSheet(business)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? const Color(0xFF1A67F8)
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            canAfford ? 'Canjear' : 'PE inf.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                isPending ? 'No tenés QRs activos' : 'Sin historial todavía',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPending
                    ? 'Canjeá una oferta en la pestaña\n"Ofertas" para obtener tu QR.'
                    : 'Los canjes validados o expirados\naparecerán acá.',
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
                // Imagen pequeña o ícono
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
                  Icons.emoji_events_rounded,
                  color: AppColors.primaryLight,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  '${r.peSpent} PE',
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
                  'Tocá para ampliar · Mostralo en el comercio',
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
              'Mostrá este QR en el comercio para canjear el premio',
              style: TextStyle(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showRedeemSheet(Business business) {
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
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            _handleRedeemSuccess(result, business);
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

  void _handleRedeemSuccess(Map<String, dynamic> result, Business business) {
    final newBalance = result['new_balance'] ?? _peBalance;
    setState(() {
      _peBalance = newBalance is int ? newBalance : _peBalance;
      _redemptions.insert(0, Redemption.fromJson(result));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Premio canjeado en ${business.name}!'),
        backgroundColor: const Color(0xFF4A9955),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _tabController.animateTo(1);
  }
}
