import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'business_profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'tourist_poi_profile_screen.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class MapScreen extends StatefulWidget {
  final Business? initialBusiness;
  final bool isActive;

  const MapScreen({super.key, this.initialBusiness, this.isActive = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _spawnClaimDateKey = 'spawn_claim_date';
  static const _spawnClaimCountKey = 'spawn_claim_count';
  static const int _maxDailySpawnClaims = 5;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;
  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];
  bool _loading = true;
  Business? _selectedBusiness;
  ExplorationPoi? _selectedPoi;
  CollectibleSpawnDto? _selectedSpawn;
  bool _showingRoute = false;
  bool _fetchingRoute = false;
  List<LatLng> _routePoints = [];
  List<ExploredTile> _exploredTiles = [];
  List<ExplorationPoi> _nearbyPois = [];
  List<CollectibleSpawnDto> _collectibleSpawns = [];
  List<GeoMissionDto> _missions = [];
  bool _claimingExploration = false;
  DateTime _lastExplorationRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showBusinesses = true;
  bool _showTouristPois = true;
  bool _showDynamicSpawns = true;

  // ── Filtros del buscador ──────────────────────────────────
  double? _filterMaxDistanceM; // null = sin límite
  bool _filterOnlyWithOffer = false;
  bool _filterOnlyNotVisited = false;
  String _filterSortBy = 'distance'; // 'distance' | 'name' | 'reward'

  bool get _hasActiveFilters =>
      _filterMaxDistanceM != null ||
      _filterOnlyWithOffer ||
      _filterOnlyNotVisited ||
      _filterSortBy != 'distance';
  int _todaySpawnClaims = 0;
  bool _spawnLimitReached = false;
  bool _generatingSpawns = false;

  Timer? _midnightSpawnResetTimer;

  // GPS - se sobreescribe con la ubicación real. Fallback: centro de San Juan
  LatLng _currentLocation = const LatLng(-31.5375, -68.5364);
  StreamSubscription<Position>? _positionSubscription;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('MapScreen');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addObserver(this);
    _searchFocus.addListener(() {
      setState(
        () => _searchOpen =
            _searchFocus.hasFocus && _searchController.text.isNotEmpty,
      );
    });
    _initSpawnClaimCount();
    _scheduleMidnightSpawnReset();
    _loadAvatar();
    if (widget.isActive) {
      _initLocation().then((_) => _startLocationUpdates());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _initGps().then((_) => _startLocationUpdates());
    } else if (state == AppLifecycleState.paused) {
      _stopGps();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initGps().then((_) => _startLocationUpdates());
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopGps();
    }
  }

  void _stopGps() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _midnightSpawnResetTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _filterBusinesses(String query) {
    _applyFilters(query: query);
  }

  /// Aplica búsqueda textual + todos los filtros activos a [_businesses]
  /// y actualiza [_filteredBusinesses].
  void _applyFilters({String? query}) {
    final q = (query ?? _searchController.text).toLowerCase();
    setState(() {
      var result = _businesses.where((b) {
        // Búsqueda textual
        if (q.isNotEmpty && !b.name.toLowerCase().contains(q)) return false;
        // Distancia máxima
        if (_filterMaxDistanceM != null) {
          final dist = _distanceTo(b);
          if (!dist.isInfinite && dist > _filterMaxDistanceM!) return false;
        }
        // Solo con oferta activa
        if (_filterOnlyWithOffer && (b.offer == null || b.offer!.isEmpty)) {
          return false;
        }
        // Solo no visitados hoy
        if (_filterOnlyNotVisited && b.checkedInToday) return false;
        return true;
      }).toList();

      // Ordenamiento
      switch (_filterSortBy) {
        case 'name':
          result.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'reward':
          result.sort(
            (a, b) => b.checkinRewardCoins.compareTo(a.checkinRewardCoins),
          );
          break;
        case 'distance':
        default:
          result.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
      }

      _filteredBusinesses = result;
      _searchOpen = q.isNotEmpty && _searchFocus.hasFocus;
    });
  }

  /// Abre el bottom sheet de filtros con diseño premium.
  void _showFilterSheet(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    // Valores temporales que se aplican solo al confirmar
    double? tempMaxDist = _filterMaxDistanceM;
    bool tempOnlyOffer = _filterOnlyWithOffer;
    bool tempOnlyNotVisited = _filterOnlyNotVisited;
    String tempSort = _filterSortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final primary = AppColors.primary;

            Widget sectionLabel(String text) => Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                text,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            );

            Widget distanceChip(String label, double? value) {
              final selected = tempMaxDist == value;
              return GestureDetector(
                onTap: () => setSheetState(() => tempMaxDist = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : (isDark
                              ? Colors.white.withAlpha(12)
                              : Colors.black.withAlpha(6)),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: selected
                          ? primary
                          : (isDark
                                ? Colors.white.withAlpha(30)
                                : Colors.black.withAlpha(20)),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            Widget sortChip(String label, String value, IconData icon) {
              final selected = tempSort == value;
              return GestureDetector(
                onTap: () => setSheetState(() => tempSort = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : (isDark
                              ? Colors.white.withAlpha(12)
                              : Colors.black.withAlpha(6)),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: selected
                          ? primary
                          : (isDark
                                ? Colors.white.withAlpha(30)
                                : Colors.black.withAlpha(20)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: selected ? Colors.white : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget toggleRow(
              String label,
              String subtitle,
              IconData icon,
              Color iconColor,
              bool value,
              ValueChanged<bool> onChanged,
            ) {
              return GestureDetector(
                onTap: () => setSheetState(() => onChanged(!value)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: value
                        ? iconColor.withAlpha(isDark ? 30 : 15)
                        : (isDark
                              ? Colors.white.withAlpha(8)
                              : Colors.black.withAlpha(4)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: value
                          ? iconColor.withAlpha(120)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(isDark ? 40 : 20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 26,
                        decoration: BoxDecoration(
                          color: value
                              ? iconColor
                              : (isDark
                                    ? Colors.white.withAlpha(30)
                                    : Colors.black.withAlpha(20)),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 180),
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle + título
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withAlpha(40)
                            : Colors.black.withAlpha(20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          TablerIcons.adjustments_horizontal,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Filtrar comercios',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      // Botón limpiar
                      TextButton(
                        onPressed: () => setSheetState(() {
                          tempMaxDist = null;
                          tempOnlyOffer = false;
                          tempOnlyNotVisited = false;
                          tempSort = 'distance';
                        }),
                        child: Text(
                          'Limpiar',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Distancia máxima ──────────────────────────
                  sectionLabel('DISTANCIA MÁXIMA'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      distanceChip('Todos', null),
                      distanceChip('< 500m', 500),
                      distanceChip('< 1km', 1000),
                      distanceChip('< 3km', 3000),
                      distanceChip('< 5km', 5000),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Ordenar por ───────────────────────────────
                  sectionLabel('ORDENAR POR'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      sortChip(
                        'Más cercano',
                        'distance',
                        TablerIcons.navigation,
                      ),
                      sortChip(
                        'Nombre A-Z',
                        'name',
                        TablerIcons.sort_a_z,
                      ),
                      sortChip('Mayor recompensa', 'reward', TablerIcons.leaf),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Mostrar solo ──────────────────────────────
                  sectionLabel('MOSTRAR SOLO'),
                  toggleRow(
                    'Con oferta activa',
                    'Comercios que tienen descuentos disponibles',
                    TablerIcons.tag,
                    const Color(0xFF4CAF50),
                    tempOnlyOffer,
                    (v) => tempOnlyOffer = v,
                  ),
                  const SizedBox(height: 10),
                  toggleRow(
                    'Sin visitar hoy',
                    'Lugares donde todavía no hiciste check-in',
                    TablerIcons.circle_check,
                    const Color(0xFF2196F3),
                    tempOnlyNotVisited,
                    (v) => tempOnlyNotVisited = v,
                  ),
                  const SizedBox(height: 24),

                  // ── Botón Aplicar ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _filterMaxDistanceM = tempMaxDist;
                          _filterOnlyWithOffer = tempOnlyOffer;
                          _filterOnlyNotVisited = tempOnlyNotVisited;
                          _filterSortBy = tempSort;
                        });
                        _applyFilters();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Aplicar filtros',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectBusiness(Business b) {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _filteredBusinesses = _businesses;
      _searchOpen = false;
      _selectedBusiness = b;
      _selectedPoi = null;
      _selectedSpawn = null;
      _showingRoute = false;
      _fetchingRoute = false;
      _routePoints = [];
    });
    if (b.latitude != null && b.longitude != null) {
      _mapController.move(LatLng(b.latitude!, b.longitude!), 17);
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final data = await ApiService.getUserProfile();
      if (!mounted) return;
      final avatarId = data['avatar']?.toString();
      if (avatarId != null) {
        final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
        setState(() => _avatarUrl = '$base/img-profile/$avatarId');
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    await _initGps();
    _loadBusinesses();
    _loadExplorationData();
  }

  Future<void> _initGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_currentLocation, 15);
        });
      }
    } catch (_) {}
  }

  Future<void> _startLocationUpdates() async {
    _positionSubscription?.cancel();
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 10,
          ),
        ).listen(
          (pos) {
            if (!mounted) return;
            setState(() {
              _currentLocation = LatLng(pos.latitude, pos.longitude);
            });
          },
          onError: (_) {
            // GPS denegado o error del sensor — se ignora silenciosamente
          },
        );
  }

  String _todayKey() {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _initSpawnClaimCount() async {
    final date = await _storage.read(key: _spawnClaimDateKey);
    final countStr = await _storage.read(key: _spawnClaimCountKey);
    if (date == _todayKey() && countStr != null) {
      _todaySpawnClaims = int.tryParse(countStr) ?? 0;
    } else {
      _todaySpawnClaims = 0;
      await _storage.write(key: _spawnClaimDateKey, value: _todayKey());
      await _storage.write(key: _spawnClaimCountKey, value: '0');
    }
    if (_todaySpawnClaims >= _maxDailySpawnClaims) {
      _spawnLimitReached = true;
    }
  }

  Future<void> _incrementSpawnCount() async {
    _todaySpawnClaims++;
    await _storage.write(
      key: _spawnClaimCountKey,
      value: _todaySpawnClaims.toString(),
    );
    if (_todaySpawnClaims >= _maxDailySpawnClaims) {
      setState(() {
        _spawnLimitReached = true;
        _collectibleSpawns = [];
        _selectedSpawn = null;
      });
    }
  }

  void _scheduleMidnightSpawnReset() {
    _midnightSpawnResetTimer?.cancel();
    final nowUtc = DateTime.now().toUtc();
    final arNow = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final nextArMidnightUtc = DateTime.utc(
      arNow.year,
      arNow.month,
      arNow.day,
    ).add(const Duration(days: 1, hours: 3));
    final wait = nextArMidnightUtc.difference(nowUtc);
    _midnightSpawnResetTimer = Timer(wait, () {
      _initSpawnClaimCount();
      _scheduleMidnightSpawnReset();
    });
  }

  Future<void> _refreshExplorationIfNeeded() async {
    final now = DateTime.now();
    if (now.difference(_lastExplorationRefresh).inSeconds < 5) {
      return;
    }
    _lastExplorationRefresh = now;
    await _loadExplorationData();
  }

  Future<void> _loadExplorationData() async {
    try {
      debugPrint(
        '[Map] Cargando datos desde: ${ApiService.baseUrl} '
        '@ lat=${_currentLocation.latitude}, lng=${_currentLocation.longitude}',
      );
      final mapNearby = await ApiService.getMapNearbyPoints(
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        radiusM: 5000,
      );
      final mapData = _extractMapNearbyData(mapNearby);
      final mapState = await ApiService.getExplorationMapState(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
      );
      final missions = await ApiService.getGeoMissions();
      final missionItems = missions['data'] is List<dynamic>
          ? missions['data'] as List<dynamic>
          : (missions['missions'] as List<dynamic>? ?? []);

      if (!mounted) return;
      final businessesData =
          (mapData['businesses'] as List<dynamic>?) ??
          (mapData['shops'] as List<dynamic>?) ??
          const [];
      final touristLocationsData =
          (mapData['tourist_locations'] as List<dynamic>?) ??
          (mapData['touristLocations'] as List<dynamic>?) ??
          (mapData['pois'] as List<dynamic>?) ??
          const [];
      final dynamicSpawnsData =
          (mapData['dynamic_spawns'] as List<dynamic>?) ??
          (mapData['collectible_spawns'] as List<dynamic>?) ??
          (mapData['spawns'] as List<dynamic>?) ??
          const [];

      setState(() {
        _businesses = businessesData
            .map((e) => Business.fromJson(e as Map<String, dynamic>))
            .toList();
        _filteredBusinesses = _searchController.text.trim().isEmpty
            ? _businesses
            : _businesses
                  .where(
                    (b) => b.name.toLowerCase().contains(
                      _searchController.text.trim().toLowerCase(),
                    ),
                  )
                  .toList();

        _nearbyPois = touristLocationsData
            .map((e) => ExplorationPoi.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_spawnLimitReached) {
          _collectibleSpawns = [];
        } else {
          _collectibleSpawns = dynamicSpawnsData
              .map(
                (e) => CollectibleSpawnDto.fromJson(e as Map<String, dynamic>),
              )
              .where((s) => !s.claimed)
              .toList();
        }
        _exploredTiles =
            (mapState['data']?['explored_tiles'] as List<dynamic>? ?? [])
                .map((e) => ExploredTile.fromJson(e as Map<String, dynamic>))
                .toList();
        _missions = missionItems
            .map((e) => GeoMissionDto.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      debugPrint(
        '[Map] Datos cargados: negocios=${_businesses.length}, '
        'pois=${_nearbyPois.length}, dinamicos=${_collectibleSpawns.length}',
      );
    } catch (e, st) {
      debugPrint('[Map] Error cargando exploración: $e\n$st');
      // Exploración es complementaria: ignorar errores para no bloquear el mapa.
    }
  }

  Future<void> _loadBusinesses() async {
    try {
      final mapNearby = await ApiService.getMapNearbyPoints(
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        radiusM: 5000,
      );
      if (mounted) {
        final data = _extractMapNearbyData(mapNearby);
        final businessItems =
            (data['businesses'] as List<dynamic>?) ??
            (data['shops'] as List<dynamic>?) ??
            const [];
        final list = businessItems
            .map((b) => Business.fromJson(b as Map<String, dynamic>))
            .toList();
        final distanceCalc = const Distance();
        // Comercio inicial pasado desde otra pantalla
        final initial = widget.initialBusiness != null
            ? list.firstWhere(
                (b) => b.id == widget.initialBusiness!.id,
                orElse: () => widget.initialBusiness!,
              )
            : null;

        // Si el usuario esta muy lejos de los comercios semilla,
        // centra el mapa en el comercio mas cercano para que se vean marcadores.
        LatLng? nearestBusinessPoint;
        if (initial == null && list.isNotEmpty) {
          final withCoords = list
              .where((b) => b.latitude != null && b.longitude != null)
              .toList();
          if (withCoords.isNotEmpty) {
            withCoords.sort((a, b) {
              final da = distanceCalc.as(
                LengthUnit.Meter,
                _currentLocation,
                LatLng(a.latitude!, a.longitude!),
              );
              final db = distanceCalc.as(
                LengthUnit.Meter,
                _currentLocation,
                LatLng(b.latitude!, b.longitude!),
              );
              return da.compareTo(db);
            });

            final nearest = withCoords.first;
            final nearestDistanceM = distanceCalc.as(
              LengthUnit.Meter,
              _currentLocation,
              LatLng(nearest.latitude!, nearest.longitude!),
            );

            if (nearestDistanceM > 20000) {
              nearestBusinessPoint = LatLng(
                nearest.latitude!,
                nearest.longitude!,
              );
            }
          }
        }

        setState(() {
          _businesses = list;
          _filteredBusinesses = list;
          _selectedBusiness = initial;
          _loading = false;
        });
        // Mover el mapa al comercio inicial
        if (initial != null &&
            initial.latitude != null &&
            initial.longitude != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(
              LatLng(initial.latitude!, initial.longitude!),
              17,
            );
          });
        } else if (nearestBusinessPoint != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(nearestBusinessPoint!, 14.5);
          });
        }

        await _loadExplorationData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Map<String, dynamic> _extractMapNearbyData(Map<String, dynamic> mapNearby) {
    final nested = mapNearby['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    // Fallback para APIs que responden directamente con colecciones en raíz.
    if (mapNearby['businesses'] is List ||
        mapNearby['shops'] is List ||
        mapNearby['tourist_locations'] is List ||
        mapNearby['dynamic_spawns'] is List) {
      return mapNearby;
    }

    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_searchFocus.hasFocus) {
            _searchFocus.unfocus();
            setState(() => _searchOpen = false);
          }
        },
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15,
                onPositionChanged: (_, __) {
                  _refreshExplorationIfNeeded();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.walkwin.app',
                ),
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.walkwin.app',
                ),
                if (_exploredTiles.isNotEmpty)
                  CircleLayer(
                    circles: _exploredTiles
                        .map(
                          (t) => CircleMarker(
                            point: LatLng(t.lat, t.lng),
                            radius: 22,
                            useRadiusInMeter: true,
                            color: const Color(0x5534D399),
                            borderColor: const Color(0xAA10B981),
                            borderStrokeWidth: 1.2,
                          ),
                        )
                        .toList(),
                  ),
                MarkerLayer(
                  markers: [
                    // Marcador de ubicación actual del usuario
                    Marker(
                      point: _currentLocation,
                      width: 64,
                      height: 64,
                      child: _buildUserMarker(),
                    ),
                    if (_showBusinesses)
                      ..._filteredBusinesses.map((b) {
                        final point =
                            (b.latitude != null && b.longitude != null)
                            ? LatLng(b.latitude!, b.longitude!)
                            : _currentLocation;
                        return Marker(
                          point: point,
                          width: 54,
                          height: 54,
                          child: _buildBusinessMarker(
                            b,
                            _selectedBusiness?.id == b.id,
                          ),
                        );
                      }),
                    if (_showTouristPois)
                      ..._nearbyPois.map(
                        (p) => Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 46,
                          height: 46,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedBusiness = null;
                              _selectedSpawn = null;
                              _selectedPoi = p;
                              _showingRoute = false;
                              _routePoints = [];
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD97A),
                                    Color(0xFFFFC857),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFC857,
                                    ).withAlpha(80),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                TablerIcons.bulb,
                                color: Color(0xFF5B3A00),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_showDynamicSpawns && !_spawnLimitReached)
                      ..._collectibleSpawns.map(
                        (s) => Marker(
                          point: LatLng(s.lat, s.lng),
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedBusiness = null;
                              _selectedPoi = null;
                              _selectedSpawn = s;
                              _showingRoute = false;
                              _routePoints = [];
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8F6CFF),
                                    Color(0xFF6C4CF5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7C4DFF,
                                    ).withAlpha(90),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    TablerIcons.sparkles,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Polilínea de ruta peatonal por calles
                if (_showingRoute && _routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppColors.primary,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _buildSearchBar(isDark, card, textPrimary, textSecondary),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 84,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildMapFilters(isDark, card, textPrimary),
              ),
            ),
            // Botón "Generar puntos dinámicos"
            Positioned(
              bottom:
                  (_selectedBusiness != null ||
                      _selectedPoi != null ||
                      _selectedSpawn != null)
                  ? 280
                  : 84,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'generate_spawns',
                backgroundColor: _generatingSpawns
                    ? const Color(0xFF7C4DFF).withAlpha(150)
                    : const Color(0xFF7C4DFF),
                onPressed: _generatingSpawns
                    ? null
                    : () => _generateDynamicSpawns(),
                child: _generatingSpawns
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(TablerIcons.sparkles, color: Colors.white),
              ),
            ),
            // Botón "Mi ubicación"
            Positioned(
              bottom:
                  (_selectedBusiness != null ||
                      _selectedPoi != null ||
                      _selectedSpawn != null)
                  ? 220
                  : 24,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'locate',
                backgroundColor: AppColors.primary,
                onPressed: () {
                  _mapController.move(_currentLocation, 15);
                  _loadExplorationData();
                },
                child: const Icon(
                  TablerIcons.crosshair,
                  color: Colors.white,
                ),
              ),
            ),
            if (_selectedBusiness != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildBusinessCard(
                  _selectedBusiness!,
                  isDark,
                  card,
                  textPrimary,
                  textSecondary,
                ),
              ),
            if (_selectedPoi != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildPoiCard(
                  _selectedPoi!,
                  isDark,
                  card,
                  textPrimary,
                  textSecondary,
                ),
              ),
            if (_selectedSpawn != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildCollectibleCard(
                  _selectedSpawn!,
                  isDark,
                  card,
                  textPrimary,
                  textSecondary,
                ),
              ),
            Positioned(
              bottom:
                  (_selectedBusiness != null ||
                      _selectedPoi != null ||
                      _selectedSpawn != null)
                  ? 248
                  : 70,
              left: 16,
              child: _buildExplorationBadge(isDark),
            ),
            if (_loading)
              Container(
                color: Colors.black.withAlpha(80),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withAlpha(150),
                            width: 3,
                          ),
                        ),
                        child: const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Cargando puntos...',
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ), // Stack
      ), // GestureDetector
    );
  }

  Widget _avatarFallback() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildUserMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = 1.0 + 0.14 * _pulseAnimation.value;
        final opacity = 0.2 - 0.07 * _pulseAnimation.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(opacity),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6),
          ],
        ),
        child: ClipOval(
          child: _avatarUrl != null
              ? Image.network(
                  _avatarUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _avatarFallback(),
                  errorBuilder: (_, __, ___) => _avatarFallback(),
                )
              : _avatarFallback(),
        ),
      ),
    );
  }

  Widget _buildBusinessMarker(Business business, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedBusiness = business;
        _selectedPoi = null;
        _selectedSpawn = null;
        _showingRoute = false;
        _fetchingRoute = false;
        _routePoints = [];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 56 : 46,
        height: isSelected ? 56 : 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [AppColors.primary, const Color(0xFF4F46E5)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(isSelected ? 110 : 45),
              blurRadius: isSelected ? 14 : 8,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Icon(
          business.checkedInToday
              ? TablerIcons.circle_check_filled
              : TablerIcons.building_store,
          color: isSelected ? Colors.white : AppColors.primary,
          size: isSelected ? 28 : 22,
        ),
      ),
    );
  }

  Widget _buildMapFilters(bool isDark, Color card, Color textPrimary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: card.withAlpha(isDark ? 235 : 245),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 70 : 20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterChip(
                  label: 'Comercios',
                  icon: TablerIcons.building_store,
                  color: AppColors.primary,
                  selected: _showBusinesses,
                  onTap: () =>
                      setState(() => _showBusinesses = !_showBusinesses),
                ),
                const SizedBox(width: 6),
                _filterChip(
                  label: 'Turísticos',
                  icon: TablerIcons.bulb,
                  color: const Color(0xFFFFC857),
                  selected: _showTouristPois,
                  onTap: () =>
                      setState(() => _showTouristPois = !_showTouristPois),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: card.withAlpha(isDark ? 235 : 245),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 70 : 20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(TablerIcons.layers_union, color: textPrimary, size: 22),
              onPressed: () {},
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : color.withAlpha(90),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : color.withAlpha(220),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Barra de búsqueda ────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                TablerIcons.search,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _filterBusinesses,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar comercios, lugares...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _filterBusinesses('');
                    _searchFocus.unfocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      TablerIcons.x,
                      color: textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              // Badge de filtros activos + botón
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? AppColors.primary.withAlpha(isDark ? 60 : 30)
                          : AppColors.primary.withAlpha(isDark ? 40 : 20),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        TablerIcons.adjustments_horizontal,
                        size: 18,
                        color: _hasActiveFilters
                            ? AppColors.primary
                            : AppColors.primary,
                      ),
                      onPressed: () => _showFilterSheet(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4757),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Dropdown de resultados ───────────────────────────
        if (_searchOpen && _filteredBusinesses.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _filteredBusinesses.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 56,
                  color: textSecondary.withAlpha(30),
                ),
                itemBuilder: (_, i) {
                  final b = _filteredBusinesses[i];
                  final dist = _distanceTo(b);
                  return InkWell(
                    onTap: () => _selectBusiness(b),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Miniatura o ícono
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: b.imageUrl != null
                                ? Image.network(
                                    b.imageUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _searchThumb(),
                                  )
                                : _searchThumb(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dist.isInfinite
                                      ? 'Sin ubicación'
                                      : dist < 1000
                                      ? '${dist.toInt()}m de distancia'
                                      : '${(dist / 1000).toStringAsFixed(1)}km',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  TablerIcons.leaf,
                                  color: AppColors.primary,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '+${b.checkinRewardCoins}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // Sin resultados
        if (_searchOpen && _filteredBusinesses.isEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 60 : 15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(TablerIcons.search_off, color: textSecondary, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Sin resultados para "${_searchController.text}"',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchThumb() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        TablerIcons.building_store,
        color: AppColors.primary,
        size: 20,
      ),
    );
  }

  /// Distancia en metros desde la ubicación actual hasta el comercio.
  double _distanceTo(Business business) {
    if (business.latitude == null || business.longitude == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      business.latitude!,
      business.longitude!,
    );
  }

  /// Obtiene la ruta peatonal por calles usando OSRM y la dibuja en el mapa.
  Future<void> _showRoute(Business business) async {
    if (business.latitude == null || business.longitude == null) return;
    setState(() {
      _fetchingRoute = true;
      _showingRoute = false;
      _routePoints = [];
    });

    final from = _currentLocation;
    final to = LatLng(business.latitude!, business.longitude!);

    try {
      // OSRM demo server — routing peatonal, sin API key
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/foot/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final points = coords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();
        setState(() {
          _routePoints = points;
          _showingRoute = true;
          _fetchingRoute = false;
        });
      } else {
        // Fallback: línea recta si la API falla
        setState(() {
          _routePoints = [from, to];
          _showingRoute = true;
          _fetchingRoute = false;
        });
      }
    } catch (_) {
      // Sin conexión al servidor de rutas → línea recta
      setState(() {
        _routePoints = [from, to];
        _showingRoute = true;
        _fetchingRoute = false;
      });
    }

    // Encuadrar cámara para ver toda la ruta
    if (_routePoints.isNotEmpty && mounted) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.fromLTRB(
            40,
            MediaQuery.of(context).padding.top + 80,
            40,
            300,
          ),
        ),
      );
    }
  }

  Widget _buildBusinessCard(
    Business business,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final distance = _distanceTo(business);
    final withinRange = distance <= business.checkinRadiusMeters;
    final availableToday = !business.checkedInToday;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 100 : 30),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Imagen del local ────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessProfileScreen(business: business),
                ),
              ),
              child: business.imageUrl != null
                  ? SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Image.network(
                        business.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: AppColors.primary.withAlpha(15),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      ),
                    )
                  : _imagePlaceholder(),
            ),

            // ── Contenido ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + cerrar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Botón acceso al perfil del comercio
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BusinessProfileScreen(business: business),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            TablerIcons.building_store,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedBusiness = null;
                          _showingRoute = false;
                          _fetchingRoute = false;
                          _routePoints = [];
                        }),
                        child: Icon(TablerIcons.x, color: textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Monedas + distancia
                  Row(
                    children: [
                      // Badge monedas
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              TablerIcons.leaf,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '+${business.checkinRewardCoins} monedas',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge distancia
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: withinRange
                              ? const Color(0xFF4A9955).withAlpha(20)
                              : textSecondary.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              withinRange
                                  ? TablerIcons.circle_check
                                  : TablerIcons.navigation,
                              color: withinRange
                                  ? const Color(0xFF4A9955)
                                  : textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance.isInfinite
                                  ? 'Sin GPS'
                                  : withinRange
                                  ? 'En rango'
                                  : '${distance.toInt()}m',
                              style: TextStyle(
                                color: withinRange
                                    ? const Color(0xFF4A9955)
                                    : textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botón según distancia
                  SizedBox(
                    width: double.infinity,
                    child: (withinRange && availableToday)
                        ? _buildGetCoinsButton(business)
                        : (withinRange && !availableToday)
                        ? _buildAlreadyCheckedButton(textSecondary)
                        : _buildGoToButton(business, textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoiCard(
    ExplorationPoi poi,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final withinRange = poi.distanceM <= poi.interactionRadiusMeters;
    final alreadyClaimed = poi.claimedToday;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 100 : 30),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (poi.department != null)
                      Text(
                        poi.department!,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TouristPoiProfileScreen(poi: poi),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    TablerIcons.mountain,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedPoi = null),
                child: Icon(TablerIcons.x, color: textSecondary),
              ),
            ],
          ),
          if (poi.imageUrl != null && poi.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TouristPoiProfileScreen(poi: poi),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  poi.imageUrl!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.primary.withAlpha(20),
                    alignment: Alignment.center,
                    child: const Icon(
                      TablerIcons.photo_off,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if ((poi.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              poi.description!,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(
                icon: TablerIcons.navigation,
                label: withinRange ? 'En rango' : '${poi.distanceM}m',
                bg: withinRange
                    ? const Color(0xFF4A9955).withAlpha(20)
                    : textSecondary.withAlpha(20),
                fg: withinRange ? const Color(0xFF4A9955) : textSecondary,
              ),
              const SizedBox(width: 8),
              _chip(
                icon: TablerIcons.leaf,
                label: '+${poi.rewardCoins} / +${poi.rewardXp} XP',
                bg: AppColors.primary.withAlpha(20),
                fg: AppColors.primary,
              ),
              if (alreadyClaimed) ...[
                const SizedBox(width: 8),
                _chip(
                  icon: TablerIcons.circle_check,
                  label: '',
                  bg: const Color(0xFF4A9955).withAlpha(20),
                  fg: const Color(0xFF4A9955),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: alreadyClaimed
                ? SizedBox(
                    key: const ValueKey('claimed'),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(TablerIcons.circle_check, size: 20),
                      label: const Text('Reclamado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: textSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('unclaimed'),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (withinRange && !_claimingExploration)
                          ? () => _claimPoi(poi)
                          : null,
                      icon: _claimingExploration
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(TablerIcons.gift, size: 20),
                      label: Text(
                        withinRange
                            ? 'Reclamar recompensa'
                            : 'Acercate al punto para reclamar',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: withinRange
                            ? AppColors.primary
                            : textSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectibleCard(
    CollectibleSpawnDto spawn,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final withinRange = spawn.distanceM <= spawn.interactionRadiusMeters;
    final alreadyClaimed = spawn.claimed;
    final remaining = _maxDailySpawnClaims - _todaySpawnClaims;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 100 : 30),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spawn.collectibleName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Hoy: $remaining/$_maxDailySpawnClaims',
                      style: TextStyle(
                        color: const Color(0xFF7C4DFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (spawn.department != null)
                      Text(
                        spawn.department!,
                        style: TextStyle(
                          color: const Color(0xFF7C4DFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedSpawn = null),
                child: Icon(TablerIcons.x, color: textSecondary),
              ),
            ],
          ),
          if (spawn.collectibleImageUrl != null &&
              spawn.collectibleImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                spawn.collectibleImageUrl!,
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: const Color(0xFF7C4DFF).withAlpha(24),
                  alignment: Alignment.center,
                  child: const Icon(
                    TablerIcons.photo_off,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                icon: TablerIcons.sparkles,
                label: alreadyClaimed
                    ? 'Ya reclamado'
                    : '+${spawn.rewardCoins} coins',
                bg: const Color(0xFF7C4DFF).withAlpha(22),
                fg: const Color(0xFF7C4DFF),
              ),
              const SizedBox(width: 8),
              _chip(
                icon: TablerIcons.navigation,
                label: withinRange ? 'En rango' : '${spawn.distanceM}m',
                bg: withinRange
                    ? const Color(0xFF4A9955).withAlpha(20)
                    : textSecondary.withAlpha(20),
                fg: withinRange ? const Color(0xFF4A9955) : textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (withinRange && !_claimingExploration) && !alreadyClaimed
                  ? () => _collectSpawn(spawn)
                  : null,
              icon: _claimingExploration
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(TablerIcons.box, size: 20),
              label: Text(
                alreadyClaimed
                    ? 'Reclamado'
                    : (withinRange
                          ? 'Reclamar punto dinámico'
                          : 'Acercate para reclamar'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: withinRange
                    ? const Color(0xFF7C4DFF)
                    : textSecondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorationBadge(bool isDark) {
    final completed = _missions.where((m) => m.isCompleted).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.cardDark : Colors.white).withAlpha(240),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 70 : 20),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(TablerIcons.compass, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            'Explorado ${_exploredTiles.length} · Misiones $completed/${_missions.length}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 90,
      width: double.infinity,
      color: AppColors.primary.withAlpha(15),
      child: const Center(
        child: Icon(
          TablerIcons.building_store,
          color: AppColors.primary,
          size: 36,
        ),
      ),
    );
  }

  // Botón "Ir al comercio" (fuera del rango)
  Widget _buildGoToButton(Business business, Color textSecondary) {
    return ElevatedButton.icon(
      onPressed: _fetchingRoute ? null : () => _showRoute(business),
      icon: _fetchingRoute
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _showingRoute
                  ? TablerIcons.route_alt_left
                  : TablerIcons.walk,
              size: 20,
            ),
      label: Text(
        _fetchingRoute
            ? 'Calculando ruta...'
            : _showingRoute
            ? 'Ruta trazada'
            : 'Ir al comercio',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _showingRoute ? Colors.orange.shade600 : textSecondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // Botón "Obtener monedas" (dentro del rango) → abre scanner QR
  Widget _buildGetCoinsButton(Business business) {
    return ElevatedButton.icon(
      onPressed: _isCheckingIn ? null : () => _openQrScanner(business),
      icon: _isCheckingIn
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(TablerIcons.scan, size: 20),
      label: Text(
        _isCheckingIn
            ? 'Verificando...'
            : 'Obtener ${business.checkinRewardCoins} monedas',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildAlreadyCheckedButton(Color textSecondary) {
    return ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(TablerIcons.circle_check, size: 20),
      label: const Text('Ya reclamaste este comercio hoy'),
      style: ElevatedButton.styleFrom(
        backgroundColor: textSecondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _claimPoi(ExplorationPoi poi) async {
    setState(() => _claimingExploration = true);
    try {
      final result = await ApiService.claimMapTouristLocation(
        poiId: poi.id,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
      );

      if (!mounted) return;
      final ok = result['success'] == true;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'No se pudo reclamar este punto.',
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      if (ok) {
        final starterCollectible = (result['data'] is Map<String, dynamic>)
            ? (result['data']['starter_collectible'] as Map<String, dynamic>?)
            : null;

        if (starterCollectible != null) {
          final collectibleName =
              starterCollectible['name']?.toString() ?? 'tarjeta común';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Nueva tarjeta desbloqueada: $collectibleName!'),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        await _loadExplorationData();

        final matches = _nearbyPois.where((p) => p.id == poi.id);
        final updatedPoi = matches.isNotEmpty ? matches.first : null;
        setState(() {
          _selectedPoi = updatedPoi ?? poi;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error de conexión al reclamar POI.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingExploration = false);
    }
  }

  Future<void> _collectSpawn(CollectibleSpawnDto spawn) async {
    if (_todaySpawnClaims >= _maxDailySpawnClaims) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Ya reclamaste tus 5 puntos dinámicos de hoy. Volvé mañana.',
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _claimingExploration = true);
    try {
      final result = await ApiService.claimMapDynamicSpawn(
        spawnId: spawn.id,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
      );

      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (result['message'] ?? 'Coleccionable obtenido.')
                : (result['message'] ?? 'No se pudo recolectar.'),
          ),
          backgroundColor: ok
              ? const Color(0xFF7C4DFF)
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (ok) {
        await _incrementSpawnCount();
        setState(() => _selectedSpawn = null);
        await _loadExplorationData();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error de conexión al recolectar item.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingExploration = false);
    }
  }

  Future<void> _generateDynamicSpawns() async {
    setState(() => _generatingSpawns = true);
    try {
      final result = await ApiService.generateDynamicSpawns(
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
      );

      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (result['message'] ?? 'Puntos generados correctamente')
                : (result['message'] ?? 'Error al generar puntos'),
          ),
          backgroundColor: ok
              ? const Color(0xFF7C4DFF)
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (ok) {
        await _loadExplorationData();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error de conexión al generar puntos'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingSpawns = false);
    }
  }

  bool _isCheckingIn = false;

  Future<void> _openQrScanner(Business business) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          businessId: business.id,
          businessName: business.name,
          coinsReward: business.checkinRewardCoins,
        ),
      ),
    );
    if (result != null && mounted) {
      await _doCheckin(business, qrPayload: result);
    }
  }

  Future<void> _doCheckin(Business business, {String? qrPayload}) async {
    setState(() => _isCheckingIn = true);
    try {
      final result = await ApiService.claimMapShop(
        businessId: business.id,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        qrPayload: qrPayload,
      );

      if (!mounted) return;

      if (result['coins_earned'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '¡Puntos Exploria obtenidas!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        await _loadExplorationData();
      } else {
        final msg = result['error'] ?? 'Error al hacer check-in.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error de conexión.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }
}
