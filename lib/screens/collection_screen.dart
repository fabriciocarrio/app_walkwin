import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: isDark ? Colors.white : Colors.black,
          tabs: const [
            Tab(text: 'Colecciones'),
            Tab(text: 'Logros'),
          ],
        ),
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
                      Icons.error_outline,
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCollectionTab(isDark),
                _buildAchievementsTab(isDark),
              ],
            ),
    );
  }

  Widget _buildCollectionTab(bool isDark) {
    final inventoryByCollectibleId = {
      for (final item in _myCollectibles) item.collectibleId: item,
    };

    final albumItems = _catalogCollectibles.map((catalogCard) {
      final unlocked = inventoryByCollectibleId[catalogCard.collectibleId];
      if (unlocked != null) {
        return unlocked;
      }

      return CollectibleSpawnDto(
        id: catalogCard.id,
        collectibleId: catalogCard.collectibleId,
        collectibleName: catalogCard.collectibleName,
        collectibleImageUrl: catalogCard.collectibleImageUrl,
        collectibleRarity: catalogCard.collectibleRarity,
        collectibleCategory: catalogCard.collectibleCategory,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orderedCategories.length,
      itemBuilder: (context, index) {
        final category = orderedCategories[index];
        final cards = album[category] ?? <CollectibleSpawnDto>[];
        cards.sort((a, b) {
          final depA = (a.department ?? '').toLowerCase();
          final depB = (b.department ?? '').toLowerCase();
          if (depA != depB) return depA.compareTo(depB);
          return a.collectibleName.toLowerCase().compareTo(
            b.collectibleName.toLowerCase(),
          );
        });
        final totalCards = cards.length;
        final unlockedCards = cards
            .where((c) => c.quantity > 0 || c.claimed)
            .length;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryCollectionDetailScreen(
                  categoryName: category,
                  cards: cards,
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unlockedCards/$totalCards',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Desliza para ver tarjetas. Toca para abrir colección completa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 255,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, cIndex) {
                        return SizedBox(
                          width: 170,
                          child: _buildCollectibleCard(cards[cIndex], isDark),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollectibleCard(CollectibleSpawnDto item, bool isDark) {
    final isUnlocked = item.quantity > 0 || item.claimed;
    final rarityColor = _getRarityColor(item.collectibleRarity);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final lockedTone = isDark ? Colors.grey.shade700 : Colors.grey.shade500;
    final frameColor = isUnlocked ? rarityColor : lockedTone;
    final labelColor = isUnlocked ? rarityColor : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [frameColor.withOpacity(0.85), frameColor.withOpacity(0.45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: frameColor.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        item.collectibleImageUrl != null &&
                            item.collectibleImageUrl!.isNotEmpty
                        ? Image.network(
                            item.collectibleImageUrl!,
                            fit: BoxFit.cover,
                            color: isUnlocked ? null : Colors.grey,
                            colorBlendMode: isUnlocked
                                ? null
                                : BlendMode.saturation,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.map_rounded,
                                size: 50,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.map_rounded,
                              size: 50,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isUnlocked ? 'x${item.quantity}' : 'Bloq',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(Icons.lock, color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.collectibleName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.collectibleCategory ??
                        item.collectibleSet ??
                        'Sin Categoría',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [item.department, item.province]
                        .whereType<String>()
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: frameColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.collectibleRarity.toUpperCase(),
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildAchievementsTab(bool isDark) {
    final deptAchievements = _achievements
        .where(
          (a) =>
              a.criteria != null &&
              a.criteria!.containsKey('department_completion'),
        )
        .toList();
    final otherAchievements = _achievements
        .where(
          (a) =>
              a.criteria == null ||
              !a.criteria!.containsKey('department_completion'),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (deptAchievements.isNotEmpty) ...[
          const Text(
            'Logros por Departamento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...deptAchievements.map((a) => _buildAchievementTile(a, isDark)),
          const SizedBox(height: 24),
        ],
        const Text(
          'Otros Logros',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...otherAchievements.map((a) => _buildAchievementTile(a, isDark)),
      ],
    );
  }

  Widget _buildAchievementTile(Achievement a, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: a.isUnlocked
              ? AppColors.primary
              : Colors.grey.withOpacity(0.3),
          child: Icon(
            a.isUnlocked ? Icons.emoji_events : Icons.lock,
            color: a.isUnlocked ? Colors.white : Colors.grey,
          ),
        ),
        title: Text(
          a.name,
          style: TextStyle(
            fontWeight: a.isUnlocked ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(a.description ?? ''),
        trailing: a.isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }
}

class CategoryCollectionDetailScreen extends StatelessWidget {
  final String categoryName;
  final List<CollectibleSpawnDto> cards;

  const CategoryCollectionDetailScreen({
    super.key,
    required this.categoryName,
    required this.cards,
  });

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

  Widget _buildCard(BuildContext context, CollectibleSpawnDto item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlocked = item.quantity > 0 || item.claimed;
    final rarityColor = _getRarityColor(item.collectibleRarity);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final lockedTone = isDark ? Colors.grey.shade700 : Colors.grey.shade500;
    final frameColor = isUnlocked ? rarityColor : lockedTone;
    final labelColor = isUnlocked ? rarityColor : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [frameColor.withOpacity(0.85), frameColor.withOpacity(0.45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: frameColor.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        item.collectibleImageUrl != null &&
                            item.collectibleImageUrl!.isNotEmpty
                        ? Image.network(
                            item.collectibleImageUrl!,
                            fit: BoxFit.cover,
                            color: isUnlocked ? null : Colors.grey,
                            colorBlendMode: isUnlocked
                                ? null
                                : BlendMode.saturation,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.map_rounded,
                                size: 50,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.map_rounded,
                              size: 50,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isUnlocked ? 'x${item.quantity}' : 'Bloq',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(Icons.lock, color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.collectibleName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [item.department, item.province]
                        .whereType<String>()
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: frameColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.collectibleRarity.toUpperCase(),
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = cards.where((c) => c.quantity > 0 || c.claimed).length;
    final total = cards.length;
    final ratio = total == 0 ? 0.0 : unlocked / total;

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Obtenidas: $unlocked/$total',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 10,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                itemCount: cards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) =>
                    _buildCard(context, cards[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
