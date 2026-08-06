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
    if (_craftCandidates.length < 2) return;

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
          _quantity = _quantity - 1;
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
        title: const Text('¡Tarjeta creada!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 140,
                height: 180,
                color: rarityColor.withOpacity(0.15),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Icon(TablerIcons.sparkles, color: rarityColor, size: 40),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('¡Genial!'),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final rarityColor = _rarityColor(_rarity);
    final attributes = _detail?['attributes'] as List<dynamic>? ?? [];
    final setData = _detail?['set'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: rarityColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _rarity.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.collectibleName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.item.description != null &&
                            widget.item.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.item.description!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity + fusion
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: rarityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(TablerIcons.book_2, size: 18),
                            const SizedBox(width: 6),
                              Text(
                                'x$_quantity',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_craftCandidates.length >= 2 &&
                            _rarity.toLowerCase() != 'legendary' &&
                            _rarity.toLowerCase() != 'legendaria') ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _crafting ? null : _onCraft,
                          icon: _crafting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(TablerIcons.wand, size: 18),
                          label: const Text('Combinar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Info cards
                  if (widget.item.collectibleCategory != null)
                    _infoRow('Categoría', widget.item.collectibleCategory!),
                  if (widget.item.province != null && widget.item.province!.isNotEmpty)
                    _infoRow('Provincia', widget.item.province!),
                  if (widget.item.department != null && widget.item.department!.isNotEmpty)
                    _infoRow('Departamento', widget.item.department!),
                  if (setData != null)
                    _infoRow('Colección', setData['name'] ?? ''),

                  if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],

                  // Attributes section
                  if (attributes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Datos curiosos',
                      style: TextStyle(
                        fontSize: 18,
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: rarityColor.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(TablerIcons.bulb, color: rarityColor, size: 20),
                            const SizedBox(width: 12),
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
                                      color: isDark ? Colors.white54 : Colors.black54,
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

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
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
        return 'ÉPICA';
      case 'epic':
        return 'LEGENDARIA';
      default:
        return 'de mayor rareza';
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      default:
        return Colors.green;
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
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? rarityColor : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            card.collectibleImageUrl != null && card.collectibleImageUrl!.isNotEmpty
                ? Image.network(card.collectibleImageUrl!, fit: BoxFit.cover)
                : Container(color: rarityColor.withOpacity(0.2)),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: rarityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card.quantity > 1 ? 'x${card.quantity}' : 'x1',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: rarityColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(TablerIcons.check, color: Colors.white, size: 16),
                ),
              ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.collectibleName,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
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

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Combinar tarjetas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Combiná 3 tarjetas de esta rareza y obtené una tarjeta ${_nextRarityLabel(widget.currentCard.collectibleRarity)} al azar.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_selected.length}/2 seleccionadas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canConfirm ? Colors.deepPurple : (isDark ? Colors.white60 : Colors.black54),
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
              childAspectRatio: 0.62,
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
                icon: const Icon(TablerIcons.wand, size: 18),
                label: const Text('Combinar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
