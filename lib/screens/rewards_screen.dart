import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'business_profile_screen.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class OfferItem {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int peCost;
  final Business business;
  final bool isFeatured;
  final String? offerId;

  OfferItem({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.peCost,
    required this.business,
    this.isFeatured = false,
    this.offerId,
  });
}

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

  // Tab "Ofertas" — ofertas individuales de los comercios
  List<OfferItem> _offerItems = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('RewardsScreen');
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
        final List<OfferItem> items = [];
        for (final b in businessList) {
          final business = Business.fromJson(b);
          if (!business.isActive) continue;

          if (business.offers.isNotEmpty) {
            for (final offer in business.offers) {
              if (offer.isActive && offer.peCost > 0) {
                items.add(OfferItem(
                  id: '${business.id}_${offer.id}',
                  title: offer.title,
                  description: offer.description,
                  imageUrl: offer.imageUrl ?? business.imageUrl,
                  peCost: offer.peCost,
                  business: business,
                  isFeatured: business.isFeatured,
                  offerId: offer.id,
                ));
              }
            }
          } else if (business.offer != null && business.offerCost > 0) {
            items.add(OfferItem(
              id: business.id,
              title: business.offer!,
              description: null,
              imageUrl: business.imageUrl,
              peCost: business.offerCost,
              business: business,
              isFeatured: business.isFeatured,
              offerId: null,
            ));
          }
        }

        setState(() {
          _peBalance = stats['pe_balance'] ?? stats['coins'] ?? 0;
          _streak = stats['streak'] ?? 0;
          _redemptions = redemptionList
              .map((r) => Redemption.fromJson(r))
              .toList();
          _offerItems = items;
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

  List<Redemption> get _history =>
      _redemptions.where((r) => r.status != 'pending').toList();

  String _formatDistance(int distanceM) {
    if (distanceM <= 0) return 'San Juan';
    if (distanceM < 2000) {
      return '${distanceM.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}m';
    }
    final km = distanceM / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

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
              TablerIcons.cloud_off,
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

  // ── Header con saldo minimalista ──────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Canjeá tus Puntos Exploria',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
              Icon(TablerIcons.help_circle, color: textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF1A67F8), const Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A67F8).withAlpha(isDark ? 30 : 50),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        TablerIcons.trophy,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'PE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Puntos Exploria',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        TablerIcons.flame,
                        color: Color(0xFFFF9800),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_streak días',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                  Icon(TablerIcons.tag, size: 14),
                  SizedBox(width: 4),
                  Text('Ofertas'),
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(TablerIcons.history, size: 14),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 1 — Ofertas disponibles (Item-Centric / Centrado en Premios)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOffersTab(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_offerItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                TablerIcons.tag,
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
                'Los premios y promociones\naparecerán acá.',
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

    final featured = _offerItems.where((o) => o.isFeatured).toList();
    final regular = _offerItems.where((o) => !o.isFeatured).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        if (featured.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Premios destacados',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Ver todos >',
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
            (o) => _buildOfferCard(o, isDark, card, textPrimary, textSecondary),
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
                              color: Color(0xFF1E293B),
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
          (o) => _buildOfferCard(o, isDark, card, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _buildOfferCard(
    OfferItem item,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final business = item.business;
    final canAfford = _peBalance >= item.peCost;
    final cardImage = item.imageUrl ?? business.imageUrl;

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
          // Col 1: Foto + Badges + Avatar Comercio
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
                  child: cardImage != null
                      ? Image.network(cardImage, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.primary.withAlpha(30),
                          child: const Icon(
                            TablerIcons.gift,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                ),
                // Avatar del Comercio en esquina inferior
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BusinessProfileScreen(business: business),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: business.imageUrl != null
                            ? Image.network(business.imageUrl!, fit: BoxFit.cover)
                            : const Icon(
                                TablerIcons.building_store,
                                color: Colors.grey,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ),
                // Badge de Costo PE (Verde/Azul si alcanza, Gris si no alcanza)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: canAfford
                          ? const Color(0xFF1A67F8)
                          : Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TablerIcons.trophy,
                          color: canAfford
                              ? const Color(0xFFFFD700)
                              : Colors.grey.shade400,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.peCost} PE',
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.grey.shade300,
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

          // Col 2: Información de la Oferta + Comercio + Botón Canjear
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del Comercio (Clickable)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BusinessProfileScreen(business: business),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.building_store,
                                size: 12,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  business.name,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Título Destacado de la Oferta (Hero)
                        Text(
                          item.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.description!,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Botón Canjear / Saldo Insuficiente
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.map_pin,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDistance(business.distanceM),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: canAfford
                                ? () => _showRedeemSheet(business)
                                : null,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: canAfford
                                    ? const Color(0xFF1A67F8).withValues(alpha: 0.3)
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                              foregroundColor: canAfford
                                  ? const Color(0xFF1A67F8)
                                  : Colors.grey,
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
                isPending ? TablerIcons.qrcode : TablerIcons.history,
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
      statusIcon = TablerIcons.qrcode;
    } else if (isValidated) {
      statusColor = const Color(0xFF4A9955);
      statusLabel = 'Validado';
      statusIcon = TablerIcons.circle_check;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Expirado';
      statusIcon = TablerIcons.clock_off;
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
                  TablerIcons.trophy,
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
        TablerIcons.building_store,
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

  void _showRedeemSheet(Business business, {OfferItem? offer}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final offerTitle = offer?.title ?? business.offer ?? 'Premio';

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
                      'Canjear: $offerTitle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresá el código de 5 dígitos\nque te dio ${business.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
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
                              offerId: offer?.offerId,
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
