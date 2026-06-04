import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'collection_screen.dart';
import 'map_screen.dart';
import 'tasks_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/websocket_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  int _mapVersion = 0;
  Business? _mapInitialBusiness;

  @override
  void initState() {
    super.initState();
    WebSocketService.instance.initForAuthenticatedUser();
  }

  @override
  void dispose() {
    WebSocketService.instance.disconnect();
    super.dispose();
  }

  void _goToPremios() {
    setState(() => _currentIndex = 4);
  }

  void _goToMap(Business business) {
    setState(() {
      _currentIndex = 1;
      _mapVersion++;
      _mapInitialBusiness = business;
    });
  }

  void _openSettings() {
    setState(() => _currentIndex = 5);
  }

  List<Widget> get _pages => [
    DashboardScreen(
      onNavigateToPremios: _goToPremios,
      onNavigateToMap: _goToMap,
      onOpenSettings: _openSettings,
    ),
    MapScreen(
      key: ValueKey('map_$_mapVersion'),
      initialBusiness: _mapInitialBusiness,
    ),
    const TasksScreen(),
    const CollectionScreen(),
    const RewardsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 20),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  top: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NavItem(
                          icon: Icons.home_rounded,
                          label: 'Inicio',
                          selected: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                          selectedColor: cs.primary,
                        ),
                        _NavItem(
                          icon: Icons.assignment_rounded,
                          label: 'Misiones',
                          selected: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                          selectedColor: cs.primary,
                        ),
                        _NavItem(
                          icon: Icons.auto_awesome_motion_rounded,
                          label: 'Tarjetas',
                          selected: _currentIndex == 3,
                          onTap: () => setState(() => _currentIndex = 3),
                          selectedColor: cs.primary,
                        ),
                        _NavItem(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Recompensas',
                          selected: _currentIndex == 4,
                          onTap: () => setState(() => _currentIndex = 4),
                          selectedColor: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -35,
                  child: _MapNavButton(
                    selected: _currentIndex == 1,
                    selectedColor: cs.primary,
                    onTap: () => setState(() {
                      _currentIndex = 1;
                      _mapVersion++;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapNavButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _MapNavButton({
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [selectedColor, selectedColor.withOpacity(0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: selectedColor.withAlpha(90),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withAlpha(selected ? 220 : 160),
            width: 3,
          ),
        ),
        child: const Icon(Icons.map_sharp, size: 32, color: Colors.white),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselected = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: selected ? selectedColor : unselected),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? selectedColor : unselected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
