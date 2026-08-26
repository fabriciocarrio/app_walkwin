import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Pantalla de pruebas de mapas vectoriales interactivos (MapLibre/OpenFreeMap)
class MapLibreTestScreen extends StatefulWidget {
  const MapLibreTestScreen({super.key});

  @override
  State<MapLibreTestScreen> createState() => _MapLibreTestScreenState();
}

class _MapLibreTestScreenState extends State<MapLibreTestScreen> {
  final MapController _mapController = MapController();

  static const Map<String, String> _styles = {
    'Positron (Gris Claro Vectorial)':
        'https://tiles.openfreemap.org/styles/positron',
    'Liberty (Detallado Vectorial)':
        'https://tiles.openfreemap.org/styles/liberty',
    'Bright (Vívido Vectorial)':
        'https://tiles.openfreemap.org/styles/bright',
  };

  String _currentStyleName = 'Positron (Gris Claro Vectorial)';
  String _currentStyleUrl = 'https://tiles.openfreemap.org/styles/positron';

  Style? _style;
  bool _loadingStyle = true;
  String? _styleError;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('MapLibreTestScreen');
    _loadStyle(_currentStyleUrl);
  }

  Future<void> _loadStyle(String url) async {
    if (!mounted) return;
    setState(() {
      _loadingStyle = true;
      _styleError = null;
    });
    try {
      final style = await StyleReader(
        uri: url,
      ).read();
      if (mounted) {
        setState(() {
          _style = style;
          _loadingStyle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _styleError = 'Error al cargar estilo vectorial: $e';
          _loadingStyle = false;
        });
      }
    }
  }

  void _changeStyle(String name, String url) {
    setState(() {
      _currentStyleName = name;
      _currentStyleUrl = url;
    });
    _loadStyle(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Mapas Vectoriales (OpenFreeMap)'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_loadingStyle)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Cargando estilo vectorial MapLibre...'),
                ],
              ),
            )
          else if (_styleError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _styleError!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_style != null)
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-31.5375, -68.5364), // San Juan, Argentina
                initialZoom: 14.0,
              ),
              children: [
                VectorTileLayer(
                  theme: _style!.theme,
                  sprites: _style!.sprites,
                  tileProviders: _style!.providers,
                ),
              ],
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
