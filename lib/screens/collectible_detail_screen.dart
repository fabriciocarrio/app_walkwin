import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class CollectibleDetailScreen extends StatefulWidget {
  final int collectibleId;
  final CollectibleSpawnDto item;

  const CollectibleDetailScreen({
    super.key,
    required this.collectibleId,
    required this.item,
  });

  @override
  State<CollectibleDetailScreen> createState() =>
      _CollectibleDetailScreenState();
}

class _CollectibleDetailScreenState extends State<CollectibleDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _crafting = false;
  late int _quantity;
  late String _rarity;
  List<CollectibleSpawnDto> _craftCandidates = [];

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
    _rarity = widget.item.collectibleRarity;
    _loadDetail();
    _loadCraftCandidates();
  }

  Future<void> _loadCraftCandidates() async {
    try {
      final result = await ApiService.getCollectibleInventory();
      final list = result['data'] as List? ?? [];
      final sameRarity = list
          .whereType<Map<String, dynamic>>()
          .map((c) => CollectibleSpawnDto.fromJson(c))
          .where((c) =>
              c.collectibleId != widget.item.collectibleId &&
              c.quantity >= 1 &&
              c.collectibleRarity.toLowerCase() == _rarity.toLowerCase())
          .toList();
      if (mounted) setState(() => _craftCandidates = sameRarity);
    } catch (_) {}
  }

  Future<void> _loadDetail() async {
    try {
      final result = await ApiService.getCollectibleDetail(widget.collectibleId);
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _detail = result['data'] as Map<String, dynamic>;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCraft() async {
    if (_craftCandidates.isEmpty && _quantity < 3) return;

    final selected = await showModalBottomSheet<List<CollectibleSpawnDto>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CraftSelectorSheet(
        currentCard: widget.item,
        candidates: _craftCandidates,
      ),
    );

    if (selected == null || selected.length != 2) return;

    setState(() => _crafting = true);

    try {
      final result = await ApiService.craftCollectibles(
        collectibleIds: [
          int.tryParse(widget.item.collectibleId) ?? 0,
          int.tryParse(selected[0].collectibleId) ?? 0,
          int.tryParse(selected[1].collectibleId) ?? 0,
        ],
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final crafted = data['crafted'] as Map<String, dynamic>? ?? {};
        final craftedName = crafted['collectible_name']?.toString() ?? 'Nueva tarjeta';
        final craftedRarity = crafted['collectible_rarity']?.toString() ?? 'common';
        final craftedImage = crafted['collectible_image_url']?.toString();

        setState(() {
          _crafting = false;
          _quantity = _quantity > 0 ? _quantity - 1 : 0;
        });

        await _showCraftResult(craftedName, craftedRarity, craftedImage);

        if (!mounted) return;

        if (_quantity <= 0) {
          Navigator.of(context).pop(true);
        } else {
          await _loadCraftCandidates();
        }
      } else {
        setState(() => _crafting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error al combinar tarjetas'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _crafting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showCraftResult(String name, String rarity, String? imageUrl) async {
    final rarityColor = _rarityColor(rarity);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.sparkles, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('¡Tarjeta Fusionada!', textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: rarityColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 150,
                  height: 195,
                  color: rarityColor.withOpacity(0.15),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Icon(TablerIcons.sparkles, color: rarityColor, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: rarityColor.withOpacity(0.4), blurRadius: 8),
                ],
              ),
              child: Text(
                rarity.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: rarityColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('¡Excelente!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return const Color(0xFFF59E0B);
      case 'epic':
      case 'épica':
      case 'epica':
        return const Color(0xFF8B5CF6);
      case 'rare':
      case 'rara':
        return const Color(0xFF207AF5);
      default:
        return const Color(0xFF10B981);
    }
  }

  LinearGradient _rarityGradient(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'epic':
      case 'épica':
      case 'epica':
        return const LinearGradient(
          colors: [Color(0xFFA855F7), Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'rare':
      case 'rara':
        return const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF207AF5), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final rarityColor = _rarityColor(_rarity);
    final rarityGradient = _rarityGradient(_rarity);
    final attributes = _detail?['attributes'] as List<dynamic>? ?? [];
    final setData = _detail?['set'] as Map<String, dynamic>?;

    // Calculate total cards available of this rarity
    final candidatesCount = _craftCandidates.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalCardsOfRarity = _quantity + candidatesCount;
    const int requiredForFusion = 3;
    final double fusionProgress = (totalCardsOfRarity / requiredForFusion).clamp(0.0, 1.0);
    final bool canFuse = totalCardsOfRarity >= requiredForFusion;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: bg,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(TablerIcons.arrow_left, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Volver',
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Card Header Preview Container with Glowing Border matching gamification_cards.png
                  Padding(
                    padding: const EdgeInsets.only(top: 72, left: 16, right: 16, bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: rarityColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: rarityColor.withOpacity(0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.item.collectibleImageUrl != null &&
                                widget.item.collectibleImageUrl!.isNotEmpty)
                              Image.network(
                                widget.item.collectibleImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: rarityColor.withOpacity(0.2),
                                  child: Icon(TablerIcons.photo, size: 80, color: rarityColor),
                                ),
                              )
                            else
                              Container(
                                color: rarityColor.withOpacity(0.2),
                                child: Icon(TablerIcons.photo, size: 80, color: rarityColor),
                              ),

                            // Overlay Gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),

                            // Holographic Rarity Badge (Top Left)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: rarityGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: rarityColor.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(TablerIcons.sparkles, color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      _rarity.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Card Name & Category Badge (Bottom Left)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.item.collectibleName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                  if (widget.item.collectibleCategory != null &&
                                      widget.item.collectibleCategory!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          widget.item.collectibleCategory!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
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
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── DYNAMIC FUSION PROGRESS BAR / BUTTON (User Requested Feature) ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: canFuse ? rarityColor : rarityColor.withOpacity(0.25),
                        width: canFuse ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: canFuse
                              ? rarityColor.withOpacity(0.25)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          spreadRadius: canFuse ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: rarityColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(TablerIcons.wand, color: rarityColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fusión de Tarjetas',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Acumuladas: $totalCardsOfRarity / $requiredForFusion',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: canFuse
                                            ? rarityColor
                                            : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: rarityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Poseés x$_quantity',
                                style: TextStyle(
                                  color: rarityColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // IF CAN FUSE -> Transforms into Glowing Action Button
                        if (canFuse) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _crafting ? null : _onCraft,
                              icon: _crafting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Icon(TablerIcons.sparkles, size: 20),
                              label: Text(
                                _crafting ? 'Fusionando...' : 'FUSIONAR TARJETAS',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: rarityColor,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: rarityColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ]
                        // IF NOT ENOUGH CARDS -> Show Progress Bar filling up
                        else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: fusionProgress,
                              minHeight: 12,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(TablerIcons.info_circle, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Juntá ${requiredForFusion - totalCardsOfRarity} tarjeta(s) más de rareza ${_rarity.toUpperCase()} para habilitar la Fusión.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── CARD DETAILS & METADATA ───
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalles de la Tarjeta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (widget.item.collectibleCategory != null)
                          _infoRow('Categoría', widget.item.collectibleCategory!, TablerIcons.category),
                        if (widget.item.province != null && widget.item.province!.isNotEmpty)
                          _infoRow('Provincia', widget.item.province!, TablerIcons.map_pin),
                        if (widget.item.department != null && widget.item.department!.isNotEmpty)
                          _infoRow('Departamento', widget.item.department!, TablerIcons.building_community),
                        if (setData != null)
                          _infoRow('Colección', setData['name'] ?? '', TablerIcons.cards),
                      ],
                    ),
                  ),

                  // Description
                  if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descripción',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.item.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Attributes list (Datos Curiosos)
                  if (attributes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Datos curiosos',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...attributes.map((attr) {
                      final map = attr as Map<String, dynamic>;
                      final label = map['label']?.toString() ?? map['name']?.toString() ?? '';
                      final value = map['value']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: rarityColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: rarityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(TablerIcons.bulb, color: rarityColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CraftSelectorSheet extends StatefulWidget {
  final CollectibleSpawnDto currentCard;
  final List<CollectibleSpawnDto> candidates;

  const _CraftSelectorSheet({
    required this.currentCard,
    required this.candidates,
  });

  @override
  State<_CraftSelectorSheet> createState() => _CraftSelectorSheetState();
}

class _CraftSelectorSheetState extends State<_CraftSelectorSheet> {
  final List<CollectibleSpawnDto> _selected = [];

  String _nextRarityLabel(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 'RARA';
      case 'rare':
      case 'rara':
        return 'ÉPICA';
      case 'epic':
      case 'épica':
      case 'epica':
        return 'LEGENDARIA';
      default:
        return 'de mayor rareza';
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
      case 'legendaria':
        return const Color(0xFFF59E0B);
      case 'epic':
      case 'épica':
      case 'epica':
        return const Color(0xFF8B5CF6);
      case 'rare':
      case 'rara':
        return const Color(0xFF207AF5);
      default:
        return const Color(0xFF10B981);
    }
  }

  void _toggle(CollectibleSpawnDto card) {
    setState(() {
      if (_selected.any((c) => c.collectibleId == card.collectibleId)) {
        _selected.removeWhere((c) => c.collectibleId == card.collectibleId);
      } else if (_selected.length < 2) {
        _selected.add(card);
      }
    });
  }

  Widget _cardTile(CollectibleSpawnDto card, bool isDark, {bool preselected = false, bool enabled = true}) {
    final selected = preselected || _selected.any((c) => c.collectibleId == card.collectibleId);
    final rarityColor = _rarityColor(card.collectibleRarity);

    return GestureDetector(
      onTap: enabled ? () => _toggle(card) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? rarityColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: rarityColor.withOpacity(0.4), blurRadius: 8)]
              : [],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            card.collectibleImageUrl != null && card.collectibleImageUrl!.isNotEmpty
                ? Image.network(card.collectibleImageUrl!, fit: BoxFit.cover)
                : Container(color: rarityColor.withOpacity(0.2)),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: rarityColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.quantity > 1 ? 'x${card.quantity}' : 'x1',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: rarityColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(TablerIcons.check, color: Colors.white, size: 14),
                ),
              ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  card.collectibleName,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : Colors.white;
    final canConfirm = _selected.length == 2;
    final rarityColor = _rarityColor(widget.currentCard.collectibleRarity);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(TablerIcons.wand, color: rarityColor, size: 22),
                    const SizedBox(width: 8),
                    const Text('Seleccionar tarjetas para Fusión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Combiná 3 tarjetas de esta rareza para obtener una tarjeta ${_nextRarityLabel(widget.currentCard.collectibleRarity)} superior.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: canConfirm ? rarityColor.withOpacity(0.15) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selected.length + 1}/3 tarjetas listas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: canConfirm ? rarityColor : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.64,
              children: [
                _cardTile(widget.currentCard, isDark, preselected: true, enabled: false),
                ...widget.candidates.map((c) => _cardTile(c, isDark)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canConfirm ? () => Navigator.of(context).pop(_selected) : null,
                icon: const Icon(TablerIcons.sparkles, size: 20),
                label: const Text('FUSIONAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rarityColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: canConfirm ? 4 : 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
