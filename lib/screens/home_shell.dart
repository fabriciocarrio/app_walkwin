import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'collection_screen.dart';
import 'map_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/websocket_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

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
    setState(() => _currentIndex = 3);
  }

  void _goToMap(Business? business) {
    setState(() {
      _currentIndex = 2;
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
    const CollectionScreen(),
    MapScreen(
      key: ValueKey('map_$_mapVersion'),
      initialBusiness: _mapInitialBusiness,
      isActive: _currentIndex == 2,
    ),
    const RewardsScreen(),
    const ProfileScreen(),
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
          color: isDark ? AppColors.cardDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: TablerIcons.home,
                            label: 'Inicio',
                            selected: _currentIndex == 0,
                            onTap: () => setState(() => _currentIndex = 0),
                            selectedColor: cs.primary,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: TablerIcons.backpack,
                            label: 'Colección',
                            selected: _currentIndex == 1,
                            onTap: () => setState(() => _currentIndex = 1),
                            selectedColor: cs.primary,
                          ),
                        ),
                        // Espacio central para el botón flotante del mapa
                        const SizedBox(width: 72),
                        Expanded(
                          child: _NavItem(
                            icon: TablerIcons.gift,
                            label: 'Premios',
                            selected: _currentIndex == 3,
                            onTap: () => setState(() => _currentIndex = 3),
                            selectedColor: cs.primary,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: TablerIcons.user,
                            label: 'Perfil',
                            selected: _currentIndex == 4,
                            onTap: () => setState(() => _currentIndex = 4),
                            selectedColor: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  child: _MapNavButton(
                    selected: _currentIndex == 2,
                    selectedColor: Color(0xFF207AF5),
                    onTap: () => setState(() {
                      _currentIndex = 2;
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selectedColor,
          boxShadow: [
            BoxShadow(
              color: selectedColor.withAlpha(60),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          TablerIcons.map_pin,
          size: 35,
          color: Colors.white,
        ),
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
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : const Color.fromARGB(255, 129, 137, 146);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Contenedor circular para el ícono (estilo de la imagen de referencia)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 46,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? selectedColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? selectedColor : unselectedColor,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? selectedColor : unselectedColor,
              letterSpacing: selected ? 0.1 : 0,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
