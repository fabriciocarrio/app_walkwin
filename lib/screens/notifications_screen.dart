import 'package:flutter/material.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _store = NotificationStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'achievement':
        return TablerIcons.trophy;
      case 'rank':
        return TablerIcons.trending_up;
      case 'collectible':
        return TablerIcons.layout_grid;
      case 'mission':
        return TablerIcons.compass;
      case 'streak':
        return TablerIcons.flame;
      case 'goal':
        return TablerIcons.flag;
      case 'progress':
        return TablerIcons.walk;
      default:
        return TablerIcons.bell;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final items = _store.items;
    final unread = _store.unreadCount;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _store.markAllAsRead(),
              child: const Text('Marcar todo leído'),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(TablerIcons.bell, size: 64, color: textSecondary.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('Sin notificaciones', style: TextStyle(color: textSecondary, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final n = items[index];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(TablerIcons.trash, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    if (n.id != null) _store.delete(n.id!);
                  },
                  child: InkWell(
                    onTap: () {
                      if (n.id != null && !n.read) {
                        _store.markAsRead(n.id!);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: n.read
                              ? (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                              : AppColors.primary.withAlpha(80),
                          width: n.read ? 0.5 : 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: n.read
                                  ? (isDark ? AppColors.cardAltDark : const Color(0xFFF0F0F0))
                                  : AppColors.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconForType(n.type),
                              size: 22,
                              color: n.read ? textSecondary : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(n.createdAt),
                                  style: TextStyle(
                                    color: textSecondary.withAlpha(150),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!n.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
