import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
  bool _fusing = false;
  late int _quantity;
  late int _rarityTier;
  late String _rarity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
    _rarityTier = widget.item.rarityTier;
    _rarity = widget.item.collectibleRarity;
    _loadDetail();
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

  Future<void> _onFuse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Fusionar tarjeta'),
        content: Text(
          'Vas a fusionar 5 copias de "${widget.item.collectibleName}" para subir su rareza. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('¡Fusionar!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _fusing = true);

    try {
      final result = await ApiService.fuseCollectibles(
        collectibleId: widget.item.collectibleId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final newRarity = data['rarity'] as String? ?? widget.item.collectibleRarity;
        final newQuantity = (data['quantity'] as num?)?.toInt() ?? widget.item.quantity;
        final newTier = (data['rarity_tier'] as num?)?.toInt() ?? widget.item.rarityTier;

        setState(() {
          _fusing = false;
          _quantity = newQuantity;
          _rarityTier = newTier;
          _rarity = newRarity;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Fusión exitosa! Rareza: $newRarity'),
              backgroundColor: Colors.deepPurple,
            ),
          );
        }
      } else {
        setState(() => _fusing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error al fusionar'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _fusing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red: $e'), backgroundColor: Colors.redAccent),
        );
      }
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
                        child: Icon(Icons.image, size: 80, color: rarityColor),
                      ),
                    )
                  else
                    Container(
                      color: rarityColor.withOpacity(0.2),
                      child: Icon(Icons.image, size: 80, color: rarityColor),
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
                            const Icon(Icons.collections_bookmark_rounded, size: 18),
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
                        if (_quantity >= 5 && _rarityTier < 3) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _fusing ? null : _onFuse,
                          icon: _fusing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Fusionar'),
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
                            Icon(Icons.lightbulb_outline, color: rarityColor, size: 20),
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
