import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import 'collectible_detail_screen.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;

  List<CollectibleSpawnDto> _catalogCollectibles = [];
  List<CollectibleSpawnDto> _myCollectibles = [];
  List<Achievement> _achievements = [];
  Map<String, Map<String, dynamic>> _progressMap = {};
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('CollectionScreen');
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _listenAchievementUnlocks();
  }

  void _listenAchievementUnlocks() {
    _wsSub = WebSocketService.instance.eventStream.listen((event) {
      if (event['event'] == 'achievement_unlocked') {
        final payload = event['payload'] as Map<String, dynamic>? ?? {};
        final achievementName = payload['achievement_name']?.toString() ?? 'Logro';
        final rewardCoins = payload['reward_coins'] ?? 0;
        final rewardXp = payload['reward_xp'] ?? 0;
        if (mounted) _showAchievementPopup(achievementName, rewardCoins, rewardXp);
        _loadData();
      }
    });
  }

  void _showAchievementPopup(String name, dynamic rewardCoins, dynamic rewardXp) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.trophy, color: AppColors.primary, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¡Logro Desbloqueado!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if ((rewardCoins is int && rewardCoins > 0) || (rewardXp is int && rewardXp > 0)) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rewardCoins is int && rewardCoins > 0) ...[
                    const Icon(TablerIcons.coin, color: AppColors.coinGold, size: 20),
                    const SizedBox(width: 4),
                    Text('+$rewardCoins',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 16),
                  ],
                  if (rewardXp is int && rewardXp > 0) ...[
                    const Icon(TablerIcons.trending_up, color: AppColors.primary, size: 20),
                    const SizedBox(width: 4),
                    Text('+${rewardXp}XP',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('¡Genial!', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getCollectibleCatalog(),
        ApiService.getCollectibleInventory(),
        ApiService.getUserAchievements(),
        ApiService.getAchievementProgress(),
      ]);

      if (mounted) {
        setState(() {
          final catalogData = results[0] as Map<String, dynamic>;
          final catalogList = catalogData['data'] ?? [];
          _catalogCollectibles = (catalogList as List)
              .map((c) => CollectibleSpawnDto.fromJson(c))
              .toList();

          final collectiblesData = results[1] as Map<String, dynamic>;
          final list = collectiblesData['data'] ?? [];
          _myCollectibles = (list as List)
              .map((c) => CollectibleSpawnDto.fromJson(c))
              .toList();

          _achievements = (results[2] as List)
              .map((a) => Achievement.fromJson(a))
              .toList();

          final progressList = results[3] as List;
          _progressMap = {};
          for (final p in progressList) {
            if (p is Map<String, dynamic> && p['slug'] != null) {
              _progressMap[p['slug'] as String] = p;
            }
          }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Mi Colección',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      TablerIcons.alert_circle,
                      color: Colors.redAccent,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    const Text('No se pudo cargar la colección.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _buildCollectionTab(isDark),
    );
  }

  Widget _buildCollectionTab(bool isDark) {
    final inventoryByCollectibleId = {
      for (final item in _myCollectibles) item.collectibleId: item,
    };

    final albumItems = _catalogCollectibles.map((catalogCard) {
      final unlocked = inventoryByCollectibleId[catalogCard.collectibleId];
      if (unlocked != null) {
        if (unlocked.categoryImageUrl == null || unlocked.categoryImageUrl!.isEmpty) {
          return CollectibleSpawnDto(
            id: unlocked.id,
            collectibleId: unlocked.collectibleId,
            collectibleName: unlocked.collectibleName,
            collectibleImageUrl: unlocked.collectibleImageUrl,
            collectibleRarity: unlocked.collectibleRarity,
            collectibleCategory: unlocked.collectibleCategory,
            categoryImageUrl: catalogCard.categoryImageUrl,
            collectibleSet: unlocked.collectibleSet,
            lat: unlocked.lat,
            lng: unlocked.lng,
            distanceM: unlocked.distanceM,
            interactionRadiusMeters: unlocked.interactionRadiusMeters,
            rewardCoins: unlocked.rewardCoins,
            province: unlocked.province,
            department: unlocked.department,
            claimed: unlocked.claimed,
            quantity: unlocked.quantity,
            rarityTier: unlocked.rarityTier,
          );
        }
        return unlocked;
      }

      return CollectibleSpawnDto(
        id: catalogCard.id,
        collectibleId: catalogCard.collectibleId,
        collectibleName: catalogCard.collectibleName,
        collectibleImageUrl: catalogCard.collectibleImageUrl,
        collectibleRarity: catalogCard.collectibleRarity,
        collectibleCategory: catalogCard.collectibleCategory,
        categoryImageUrl: catalogCard.categoryImageUrl,
        collectibleSet: catalogCard.collectibleSet,
        lat: 0,
        lng: 0,
        distanceM: 0,
        interactionRadiusMeters: 0,
        rewardCoins: catalogCard.rewardCoins,
        province: catalogCard.province,
        department: catalogCard.department,
        claimed: false,
        quantity: 0,
      );
    }).toList();

    if (albumItems.isEmpty) {
      return const Center(child: Text('Aún no tienes coleccionables.'));
    }

    final album = <String, List<CollectibleSpawnDto>>{};
    for (final collectible in albumItems) {
      final rawCategory =
          (collectible.collectibleCategory ?? collectible.collectibleSet ?? '')
              .trim();
      final category = rawCategory.isNotEmpty ? rawCategory : 'Sin categoría';
      album.putIfAbsent(category, () => <CollectibleSpawnDto>[]);
      album[category]!.add(collectible);
    }

    final orderedCategories = album.keys.toList()..sort();

    int totalCards = albumItems.length;
    int unlockedCardsOverall = albumItems.where((c) => c.quantity > 0 || c.claimed).length;
    double overallPct = totalCards > 0 ? (unlockedCardsOverall / totalCards) : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Summary Card
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.book_2, color: Colors.blue, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Has descubierto',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(text: '$unlockedCardsOverall ', style: const TextStyle(color: Colors.blue)),
                          const TextSpan(text: 'de ', style: TextStyle(fontSize: 16)),
                          TextSpan(text: '$totalCards ', style: const TextStyle(fontSize: 18)),
                          const TextSpan(text: 'tarjetas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: overallPct,
                              minHeight: 6,
                              backgroundColor: Colors.white,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(overallPct * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Collection List
        ...orderedCategories.map((category) {
          final cards = album[category] ?? <CollectibleSpawnDto>[];
          final totalCatCards = cards.length;
          final unlockedCatCards = cards.where((c) => c.quantity > 0 || c.claimed).length;
          final catPct = totalCatCards > 0 ? (unlockedCatCards / totalCatCards) : 0.0;
          final color = _getCategoryHeaderColor(category);

          final categoryCardWithSpecificImage = cards.cast<CollectibleSpawnDto?>().firstWhere(
            (c) => c != null && c.categoryImageUrl != null && c.categoryImageUrl!.isNotEmpty,
            orElse: () => null,
          );
          final categoryCardWithCollectibleImage = cards.cast<CollectibleSpawnDto?>().firstWhere(
            (c) => c != null && c.collectibleImageUrl != null && c.collectibleImageUrl!.isNotEmpty,
            orElse: () => null,
          );
          final categoryImageUrl = categoryCardWithSpecificImage?.categoryImageUrl ??
              categoryCardWithCollectibleImage?.collectibleImageUrl;

          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryCollectionDetailScreen(
                    categoryName: category,
                    cards: cards,
                  ),
                ),
              );
              if (mounted) _loadData();
            },
            child: Container(
              height: 210,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 20),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (categoryImageUrl != null && categoryImageUrl.isNotEmpty)
                    Image.network(
                      categoryImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.5), color],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.5), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(TablerIcons.leaf, color: Colors.white, size: 20),
                        ),
                        const Spacer(),
                        Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$unlockedCatCards / $totalCatCards',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: catPct,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  color: color, // The primary color of the category
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(catPct * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(TablerIcons.chevron_right, color: Colors.white, size: 24),
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
        }).toList(),
      ],
    );
  }

  Color _getCategoryHeaderColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ciencia') || lower.contains('cielo')) return const Color(0xFF0D47A1);
    if (lower.contains('fenómeno') || lower.contains('natural')) return const Color(0xFFC69A27);
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFFC62828),
      const Color(0xFFEF6C00),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
    ];
    return colors[category.hashCode.abs() % colors.length];
  }

  Widget _buildSimplifiedCollectibleCard(CollectibleSpawnDto item) {
    final isUnlocked = item.quantity > 0 || item.claimed;
    const w = 90.0;

    return Container(
      width: w,
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.transparent : Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withAlpha(isUnlocked ? 80 : 30),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isUnlocked
          ? Stack(
              fit: StackFit.expand,
              children: [
                if (item.collectibleImageUrl != null && item.collectibleImageUrl!.isNotEmpty)
                  Image.network(
                    item.collectibleImageUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  Container(color: AppColors.primary),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    item.collectibleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (item.collectibleRarity.toLowerCase() == 'legendary' || item.collectibleRarity.toLowerCase() == 'epic')
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(TablerIcons.key, color: Color(0xFFFFD700), size: 14),
                  ),
                if (item.quantity > 1)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white38, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(TablerIcons.copy, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'x${item.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: Icon(TablerIcons.lock, color: Colors.white70, size: 28),
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static const _categoryLabels = {
    'walker': 'Pasos & Meta Diaria',
    'streak': 'Racha',
    'social': 'Comercios & Check-ins',
    'explorer': 'Exploración',
    'collector': 'Coleccionables',
    'mission': 'Misiones',
    'special': 'Especiales',
    'milestone': 'Hitos',
    'general': 'Generales',
  };

  static const _categoryIcons = {
    'walker': TablerIcons.walk,
    'streak': TablerIcons.flame,
    'social': TablerIcons.building_store,
    'explorer': TablerIcons.map,
    'collector': TablerIcons.book_2,
    'mission': TablerIcons.flag,
    'special': TablerIcons.star_filled,
    'milestone': TablerIcons.military_award,
    'general': TablerIcons.trophy,
  };

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAchievementsTab(bool isDark) {
    final grouped = <String, List<Achievement>>{};
    for (final a in _achievements) {
      grouped.putIfAbsent(a.category, () => []);
      grouped[a.category]!.add(a);
    }

    final categoryOrder = ['walker', 'streak', 'social', 'explorer', 'collector', 'mission', 'special', 'milestone', 'general'];
    final sortedCategories = categoryOrder.where((c) => grouped.containsKey(c)).toList();

    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    final totalCount = _achievements.length;
    final overallProgress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Overall progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withAlpha(30),
                AppColors.primary.withAlpha(10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progreso Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$unlockedCount / $totalCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  color: overallProgress >= 1.0
                      ? const Color(0xFF10B981)
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final cat in sortedCategories) ...[
          _buildCategoryHeader(cat, grouped[cat]!, isDark),
          const SizedBox(height: 8),
          for (final a in grouped[cat]!) _buildAchievementTile(a, isDark),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCategoryHeader(String cat, List<Achievement> items, bool isDark) {
    final unlocked = items.where((a) => a.isUnlocked).length;
    final total = items.length;
    final icon = _categoryIcons[cat] ?? TablerIcons.trophy;
    final label = _categoryLabels[cat] ?? cat;

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$unlocked/$total',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementTile(Achievement a, bool isDark) {
    final rarityColor = _rarityColor(a.rarity);
    final progress = _progressMap[a.slug];

    int current = 0;
    int target = 0;
    double pct = a.isUnlocked ? 1.0 : 0.0;
    if (progress != null) {
      current = progress['current'] ?? 0;
      target = progress['target'] ?? 0;
      pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    } else if (a.isUnlocked) {
      pct = 1.0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: a.isUnlocked
            ? Border.all(color: rarityColor.withAlpha(80), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: a.isUnlocked
                      ? rarityColor.withAlpha(30)
                      : (isDark ? AppColors.cardAltDark : Colors.grey.withAlpha(20)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  a.isUnlocked ? TablerIcons.trophy : TablerIcons.lock,
                  color: a.isUnlocked ? rarityColor : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: rarityColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.rarity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: rarityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (a.description != null && a.description!.isNotEmpty)
                      Text(
                        a.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.rewardCoins > 0) ...[
                        const Icon(TablerIcons.coin, size: 14, color: AppColors.coinGold),
                        const SizedBox(width: 2),
                        Text('${a.rewardCoins}',
                          style: TextStyle(fontSize: 11, color: AppColors.coinGold, fontWeight: FontWeight.w600)),
                      ],
                      if (a.rewardXp > 0 && a.rewardCoins > 0) const SizedBox(width: 6),
                      if (a.rewardXp > 0) ...[
                        Text('${a.rewardXp}',
                          style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        const Text('XP',
                          style: TextStyle(fontSize: 9, color: AppColors.primary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (a.isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.circle_check, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 3),
                          Text('Completado',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!a.isUnlocked && target > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                color: rarityColor,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$current / $target',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CategoryCollectionDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<CollectibleSpawnDto> cards;

  const CategoryCollectionDetailScreen({
    super.key,
    required this.categoryName,
    required this.cards,
  });

  @override
  State<CategoryCollectionDetailScreen> createState() =>
      _CategoryCollectionDetailScreenState();
}

class _CategoryCollectionDetailScreenState
    extends State<CategoryCollectionDetailScreen> {
  String _selectedFilter = 'Todas';

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return Colors.orange;
      case 'epic':
      case 'épica':
      case 'epica':
        return Colors.purple;
      case 'rare':
      case 'rara':
        return Colors.blue;
      default:
        return Colors.green; // Common / Común
    }
  }

  int _getRarityStars(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return 5;
      case 'epic':
      case 'épica':
      case 'epica':
        return 4;
      case 'rare':
      case 'rara':
        return 3;
      default:
        return 2; // Common
    }
  }

  String _getTranslatedRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return 'LEGENDARIA';
      case 'epic':
        return 'ÉPICA';
      case 'rare':
        return 'RARA';
      default:
        return 'COMÚN';
    }
  }

  Color _getCategoryHeaderColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ciencia') || lower.contains('cielo')) return const Color(0xFF0D47A1);
    if (lower.contains('fenómeno') || lower.contains('natural')) return const Color(0xFFC69A27);
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFFC62828),
      const Color(0xFFEF6C00),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
    ];
    return colors[category.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.cards.length;
    final unlockedCount = widget.cards.where((c) => c.quantity > 0 || c.claimed).length;
    final ratio = total == 0 ? 0.0 : unlockedCount / total;
    final headerColor = _getCategoryHeaderColor(widget.categoryName);

    final bannerCardWithSpecificImage = widget.cards.cast<CollectibleSpawnDto?>().firstWhere(
      (c) => c != null && c.categoryImageUrl != null && c.categoryImageUrl!.isNotEmpty,
      orElse: () => null,
    );
    final bannerCardWithCollectibleImage = widget.cards.cast<CollectibleSpawnDto?>().firstWhere(
      (c) => c != null && c.collectibleImageUrl != null && c.collectibleImageUrl!.isNotEmpty,
      orElse: () => null,
    );
    final bannerImageUrl = bannerCardWithSpecificImage?.categoryImageUrl ??
        bannerCardWithCollectibleImage?.collectibleImageUrl;

    // Apply filters
    List<CollectibleSpawnDto> filteredCards = widget.cards.where((c) {
      final isUnlocked = c.quantity > 0 || c.claimed;
      if (_selectedFilter == 'Obtenidas') return isUnlocked;
      if (_selectedFilter == 'Faltantes') return !isUnlocked;
      if (_selectedFilter == 'Legendarias') return c.collectibleRarity.toLowerCase() == 'legendary' || c.collectibleRarity.toLowerCase() == 'legendaria';
      return true; // 'Todas'
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF7F9FC),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(TablerIcons.star_filled, color: Colors.blue.shade300),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Card
                Container(
                  height: 230,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (bannerImageUrl != null && bannerImageUrl.isNotEmpty)
                        Image.network(
                          bannerImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [headerColor.withOpacity(0.5), headerColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [headerColor.withOpacity(0.5), headerColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(TablerIcons.compass, color: Colors.white, size: 24),
                            ),
                            const Spacer(),
                            Text(
                              widget.categoryName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                children: [
                                  TextSpan(text: '$unlockedCount', style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                  TextSpan(text: ' / $total tarjetas'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withOpacity(0.3),
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(ratio * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
                
                // Description
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Text(
                    'Descubre maravillas de esta colección y completa tu álbum.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),

                // Filters
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('Todas', isDark),
                      _buildFilterChip('Obtenidas', isDark),
                      _buildFilterChip('Faltantes', isDark),
                      _buildFilterChip('Legendarias', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCard(context, filteredCards[index]),
                childCount: filteredCards.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : (isDark ? AppColors.cardDark : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, CollectibleSpawnDto item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlocked = item.quantity > 0 || item.claimed;
    final rarityColor = _getRarityColor(item.collectibleRarity);
    final rarityLabel = _getTranslatedRarity(item.collectibleRarity);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final starsCount = _getRarityStars(item.collectibleRarity);

    if (!isUnlocked) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.collectibleImageUrl != null && item.collectibleImageUrl!.isNotEmpty)
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.65), BlendMode.darken),
                      child: Image.network(
                        item.collectibleImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade400),
                      ),
                    )
                  else
                    Container(color: Colors.grey.shade300),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.lock, color: Colors.white, size: 28),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '???',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Aún no descubierta',
                      style: TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        3,
                        (index) => const Icon(TablerIcons.star_filled, color: Colors.grey, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CollectibleDetailScreen(
              collectibleId: int.tryParse(item.collectibleId) ?? 0,
              item: item,
            ),
          ),
        );
        if (changed == true && context.mounted) Navigator.of(context).pop(true);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.collectibleImageUrl != null && item.collectibleImageUrl!.isNotEmpty
                      ? Image.network(
                          item.collectibleImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: rarityColor.withOpacity(0.3)),
                        )
                      : Container(color: rarityColor.withOpacity(0.3)),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(TablerIcons.star_filled, color: Colors.white, size: 8),
                          const SizedBox(width: 2),
                          Text(
                            rarityLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.collectibleName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.department ?? item.province ?? 'Ubicación Desconocida',
                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        starsCount,
                        (index) => Icon(TablerIcons.star_filled, color: rarityColor, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
