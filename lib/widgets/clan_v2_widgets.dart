import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';

/// Role Selector Dialog / Widget for Clan v2
class ClanRoleSelectorWidget extends StatelessWidget {
  final String currentRole;
  final Function(String newRole) onRoleSelected;

  const ClanRoleSelectorWidget({
    super.key,
    required this.currentRole,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final roles = [
      {'key': 'explorer', 'name': 'Explorador', 'desc': '+20% Percepción en POIs de tu depto', 'icon': TablerIcons.compass, 'color': Colors.indigo},
      {'key': 'collector', 'name': 'Recaudador', 'desc': '+15% PE en comercios adheridos', 'icon': TablerIcons.coin, 'color': Colors.amber.shade700},
      {'key': 'guardian', 'name': 'Guardián', 'desc': '+20 Resiliencia colectiva para el clan', 'icon': TablerIcons.shield, 'color': Colors.teal},
      {'key': 'mentor', 'name': 'Mentor', 'desc': '+10% XP para miembros de menor nivel', 'icon': TablerIcons.school, 'color': Colors.blue},
      {'key': 'ambassador', 'name': 'Embajador', 'desc': '+15 Carisma para intercambios y clan', 'icon': TablerIcons.users, 'color': Colors.pink},
      {'key': 'captain', 'name': 'Capitán', 'desc': 'Inicia operaciones y compra mejoras', 'icon': TablerIcons.crown, 'color': Colors.purple},
      {'key': 'member', 'name': 'Miembro', 'desc': 'Aporta influencia sin rol específico', 'icon': TablerIcons.user, 'color': Colors.grey},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona tu Rol Jugable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Cambiar de rol cuesta 100 PE y tiene un cooldown de 7 días.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roles.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final r = roles[index];
              final String key = r['key'] as String;
              final bool isCurrent = (currentRole.toLowerCase() == key);
              final Color color = r['color'] as Color;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCurrent ? AppColors.primary : Colors.grey.shade200,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                tileColor: isCurrent ? AppColors.primary.withOpacity(0.05) : Colors.grey.shade50,
                leading: Icon(r['icon'] as IconData, color: color),
                title: Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(r['desc'] as String, style: const TextStyle(fontSize: 11)),
                trailing: isCurrent
                    ? const Icon(TablerIcons.circle_check, color: AppColors.primary)
                    : OutlinedButton(
                        onPressed: () => onRoleSelected(key),
                        child: const Text('Elegir'),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Active Clan Operation Progress Card
class ClanOperationCardWidget extends StatelessWidget {
  final Map<String, dynamic>? activeOperation;
  final VoidCallback? onStartOperationTap;

  const ClanOperationCardWidget({
    super.key,
    this.activeOperation,
    this.onStartOperationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (activeOperation == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            const Icon(TablerIcons.swords, size: 36, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Sin Operación Semanal Activa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'El líder o capitanes pueden iniciar una operación de clan.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onStartOperationTap,
              icon: const Icon(TablerIcons.play, size: 18),
              label: const Text('Iniciar Operación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final type = (activeOperation!['operation_type'] ?? 'expedition').toString().toUpperCase();
    final progress = activeOperation!['progress'] ?? 0;
    final target = activeOperation!['target'] ?? 100;
    final double pct = (target > 0) ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(TablerIcons.swords, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Operación Semanal: $type',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('ACTIVA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progreso del Clan: $progress / $target', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clan Improvements Tree Widget
class ClanImprovementTreeWidget extends StatelessWidget {
  final List<dynamic> improvements;
  final int historicalInfluence;
  final Function(String improvementKey)? onBuyImprovement;

  const ClanImprovementTreeWidget({
    super.key,
    required this.improvements,
    required this.historicalInfluence,
    this.onBuyImprovement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏗️ Mejoras del Clan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Influencia: $historicalInfluence',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: improvements.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final item = improvements[index];
            final String key = (item['key'] ?? '').toString();
            final String name = (item['name'] ?? '').toString();
            final String desc = (item['description'] ?? '').toString();
            final int cost = item['cost'] ?? 0;
            final bool unlocked = item['unlocked'] == true;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: unlocked ? Colors.green.shade50 : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unlocked ? Colors.green.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    unlocked ? TablerIcons.circle_check_filled : TablerIcons.lock,
                    color: unlocked ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  if (!unlocked)
                    ElevatedButton(
                      onPressed: (historicalInfluence >= cost) ? () => onBuyImprovement?.call(key) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('${cost ~/ 1000}k'),
                    )
                  else
                    const Text('ACTIVADA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Clan Internal Trade Market & PE Gift Widget
class ClanTradeMarketWidget extends StatelessWidget {
  final List<dynamic> trades;
  final VoidCallback? onCreateTradeTap;
  final Function(int tradeId)? onAcceptTradeTap;
  final VoidCallback? onGiftPeTap;

  const ClanTradeMarketWidget({
    super.key,
    required this.trades,
    this.onCreateTradeTap,
    this.onAcceptTradeTap,
    this.onGiftPeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(TablerIcons.arrows_exchange, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Mercado Interno & Regalos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.gift, color: Colors.orange, size: 20),
                    tooltip: 'Regalar PE',
                    onPressed: onGiftPeTap,
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.plus, color: AppColors.primary, size: 20),
                    tooltip: 'Oferta de Trueque',
                    onPressed: onCreateTradeTap,
                  ),
                ],
              ),
            ],
          ),
          if (trades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay ofertas de trueque activas en el clan.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trades.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 6),
              itemBuilder: (ctx, index) {
                final t = trades[index];
                final int tradeId = t['id'] ?? 0;
                final senderName = t['sender_name'] ?? 'Miembro';
                final String status = t['status'] ?? 'pending';

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(TablerIcons.cards, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trueque de $senderName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Estado: ${status.toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      if (status == 'pending')
                        ElevatedButton(
                          onPressed: () => onAcceptTradeTap?.call(tradeId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Aceptar'),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

