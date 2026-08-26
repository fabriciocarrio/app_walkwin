import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Pantalla de pruebas de mapas vectoriales interactivos con MapLibre GL
class MapLibreTestScreen extends StatefulWidget {
  const MapLibreTestScreen({super.key});

  @override
  State<MapLibreTestScreen> createState() => _MapLibreTestScreenState();
}

class _MapLibreTestScreenState extends State<MapLibreTestScreen> {
  MapLibreMapController? _mapController;

  static const Map<String, String> _styles = {
    'Positron (Gris Claro Minimalista)':
        'https://tiles.openfreemap.org/styles/positron',
    'Liberty (Detallado con relieve)':
        'https://tiles.openfreemap.org/styles/liberty',
    'Bright (Vívido y claro)': 'https://tiles.openfreemap.org/styles/bright',
    'MapLibre Demo (Básico)': 'https://demotiles.maplibre.org/style.json',
  };

  String _currentStyleName = 'Positron (Gris Claro Minimalista)';
  String _currentStyleUrl = 'https://tiles.openfreemap.org/styles/positron';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('MapLibreTestScreen');
  }

  void _changeStyle(String name, String url) {
    setState(() {
      _currentStyleName = name;
      _currentStyleUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Prueba MapLibre GL (Vectores)'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MapLibreMap(
            key: ValueKey(_currentStyleUrl),
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-31.5375, -68.5364), // San Juan, Argentina
              zoom: 14.0,
            ),
            styleString: _currentStyleUrl,
            trackCameraPosition: true,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.map, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentStyleName,
                        isExpanded: true,
                        icon: const Icon(TablerIcons.chevron_down),
                        items: _styles.keys.map((String styleName) {
                          return DropdownMenuItem<String>(
                            value: styleName,
                            child: Text(
                              styleName,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? selected) {
                          if (selected != null &&
                              _styles.containsKey(selected)) {
                            _changeStyle(selected, _styles[selected]!);
                          }
                        },
                      ),
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
}
