import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

enum MapTileType { rasterSingle, rasterDual, vector }

class MapStyleOption {
  final String name;
  final String category;
  final MapTileType type;
  final String? urlTemplate;
  final String? secondaryUrlTemplate;
  final List<String>? subdomains;
  final String? vectorStyleUrl;

  const MapStyleOption({
    required this.name,
    required this.category,
    required this.type,
    this.urlTemplate,
    this.secondaryUrlTemplate,
    this.subdomains,
    this.vectorStyleUrl,
  });
}

/// Catálogo interactivo de mapas gratuitos (Raster, Dual, Modo Oscuro y Vectoriales)
class MapLibreTestScreen extends StatefulWidget {
  const MapLibreTestScreen({super.key});

  @override
  State<MapLibreTestScreen> createState() => _MapLibreTestScreenState();
}

class _MapLibreTestScreenState extends State<MapLibreTestScreen> {
  final MapController _mapController = MapController();

  static const List<MapStyleOption> _catalog = [
    // MINIMALISTAS (LIGHT)
    MapStyleOption(
      name: 'Esri Light Gray (Minimalista Claro)',
      category: 'Minimalistas',
      type: MapTileType.rasterDual,
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
      secondaryUrlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
    ),
    MapStyleOption(
      name: 'OpenFreeMap Positron (Vectorial Claro)',
      category: 'Minimalistas',
      type: MapTileType.vector,
      vectorStyleUrl: 'https://tiles.openfreemap.org/styles/positron',
    ),
    MapStyleOption(
      name: 'OSM HOT (Tonos Pastel Suaves)',
      category: 'Minimalistas',
      type: MapTileType.rasterSingle,
      urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      subdomains: ['a', 'b'],
    ),

    // MODO OSCURO (DARK MODES)
    MapStyleOption(
      name: 'Esri Dark Gray (Modo Oscuro Minimalista)',
      category: 'Modo Oscuro',
      type: MapTileType.rasterDual,
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
      secondaryUrlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
    ),

    // SATÉLITE
    MapStyleOption(
      name: 'Esri World Imagery (Satélite Puro)',
      category: 'Satélite',
      type: MapTileType.rasterSingle,
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    ),
    MapStyleOption(
      name: 'Esri Satélite + Calles y Nombres',
      category: 'Satélite',
      type: MapTileType.rasterDual,
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      secondaryUrlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
    ),

    // ESTÁNDAR Y TOPOGRÁFICO
    MapStyleOption(
      name: 'OpenStreetMap Standard',
      category: 'Estándar',
      type: MapTileType.rasterSingle,
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MapStyleOption(
      name: 'OSM Francia (Calles Nítidas)',
      category: 'Estándar',
      type: MapTileType.rasterSingle,
      urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
    ),
    MapStyleOption(
      name: 'Esri World Topo Map (Topográfico)',
      category: 'Estándar',
      type: MapTileType.rasterSingle,
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    ),
    MapStyleOption(
      name: 'OpenFreeMap Liberty (Vectorial Detallado)',
      category: 'Estándar',
      type: MapTileType.vector,
      vectorStyleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    ),
    MapStyleOption(
      name: 'OpenFreeMap Bright (Vectorial Vívido)',
      category: 'Estándar',
      type: MapTileType.vector,
      vectorStyleUrl: 'https://tiles.openfreemap.org/styles/bright',
    ),
  ];

  late MapStyleOption _selectedOption;
  Style? _vectorStyle;
  bool _loadingVectorStyle = false;
  String? _vectorStyleError;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('MapLibreTestScreen');
    _selectedOption = _catalog.first;
  }

  Future<void> _selectOption(MapStyleOption option) async {
    setState(() {
      _selectedOption = option;
      _vectorStyle = null;
      _vectorStyleError = null;
    });

    if (option.type == MapTileType.vector && option.vectorStyleUrl != null) {
      setState(() => _loadingVectorStyle = true);
      try {
        final style = await StyleReader(uri: option.vectorStyleUrl!).read();
        if (mounted) {
          setState(() {
            _vectorStyle = style;
            _loadingVectorStyle = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _vectorStyleError = 'Error al cargar estilo vectorial: $e';
            _loadingVectorStyle = false;
          });
        }
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
        title: const Text('Explorador de Mapas Gratuitos'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // MAPA FLUTTER_MAP
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-31.5375, -68.5364), // San Juan, Argentina
              initialZoom: 14.0,
            ),
            children: [
              if (_selectedOption.type == MapTileType.rasterSingle &&
                  _selectedOption.urlTemplate != null)
                TileLayer(
                  urlTemplate: _selectedOption.urlTemplate!,
                  subdomains: _selectedOption.subdomains ?? const [],
                  userAgentPackageName: 'com.walkwin.app',
                )
              else if (_selectedOption.type == MapTileType.rasterDual &&
                  _selectedOption.urlTemplate != null) ...[
                TileLayer(
                  urlTemplate: _selectedOption.urlTemplate!,
                  userAgentPackageName: 'com.walkwin.app',
                ),
                if (_selectedOption.secondaryUrlTemplate != null)
                  TileLayer(
                    urlTemplate: _selectedOption.secondaryUrlTemplate!,
                    userAgentPackageName: 'com.walkwin.app',
                  ),
              ] else if (_selectedOption.type == MapTileType.vector &&
                  _vectorStyle != null)
                VectorTileLayer(
                  theme: _vectorStyle!.theme,
                  sprites: _vectorStyle!.sprites,
                  tileProviders: _vectorStyle!.providers,
                ),
            ],
          ),

          // OVERLAY CARGANDO VECTOR
          if (_loadingVectorStyle)
            Container(
              color: Colors.black.withAlpha(120),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text(
                      'Cargando estilo vectorial...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_vectorStyleError != null)
            Positioned(
              center: 0,
              top: 100,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red,
                child: Text(
                  _vectorStyleError!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          // SELECTOR DE ESTILOS INFERIOR / BOTTOM SHEET TRIGGER
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: GestureDetector(
              onTap: _showStylePickerModal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        TablerIcons.map_pin,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedOption.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedOption.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Cambiar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            TablerIcons.chevron_up,
                            color: Colors.white,
                            size: 16,
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
    );
  }

  void _showStylePickerModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final categories =
            _catalog.map((e) => e.category).toSet().toList();

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seleccionar mapa base gratuito',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mapas 100% libres de API keys',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, catIdx) {
                    final cat = categories[catIdx];
                    final stylesInCat =
                        _catalog.where((s) => s.category == cat).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Text(
                            cat.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ...stylesInCat.map((opt) {
                          final isSelected = opt.name == _selectedOption.name;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withAlpha(25)
                                  : (isDark
                                      ? AppColors.cardAltDark
                                      : Colors.grey.withAlpha(20)),
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? Border.all(
                                      color: AppColors.primary, width: 1.5)
                                  : null,
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                opt.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(TablerIcons.check,
                                      color: AppColors.primary)
                                  : const Icon(TablerIcons.chevron_right,
                                      size: 18),
                              onTap: () {
                                Navigator.pop(ctx);
                                _selectOption(opt);
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
