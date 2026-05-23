import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pedometer/pedometer.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/celebration_service.dart';
import '../theme/app_theme.dart';
import 'level_progress_screen.dart';
import 'missions_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPremios;
  final void Function(Business)? onNavigateToMap;
  final VoidCallback? onOpenSettings;

  const DashboardScreen({
    super.key,
    this.onNavigateToPremios,
    this.onNavigateToMap,
    this.onOpenSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _steps = 0;
  int _coins = 1240;
  int _pepitas = 0;
  int _level = 5;
  int _streak = 7;
  int _xpTotal = 0;
  int _xpToday = 0;
  int _xpCurrentLevelStart = 0;
  int _xpNextLevelTarget = 300;
  int _nextLevel = 2;
  int _levelBaseXp = 300;
  int _levelGrowthXp = 150;
  int _maxLevel = 30;
  bool _isMaxLevel = false;
  String? _apiLevelTitle;
  int _dailyGoal = 10000;
  bool _loading = false;
  bool _pepitasLoading = true;
  List<Business> _featured = [];
  bool _featuredLoading = true;
  WeeklyActivitySummary? _weekly;
  bool _weeklyLoading = true;
  List<GeoMissionDto> _missions = [];
  bool _missionsLoading = true;

  // Pedómetro en tiempo real
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int? _initialSteps; // pasos al arrancar el sensor
  int _sessionSteps = 0; // delta desde que se abrió la app

  // Sincronización al backend
  Timer? _syncTimer;
  Timer? _realtimeSyncDebounce;
  Timer? _midnightResetTimer;
  int _lastSyncedSteps = 0;
  String _stepSource = 'native_sensor';
  String _activeDayKey = '';
  static const _storage = FlutterSecureStorage();

  // Meta diaria y celebración
  bool _dailyGoalReached = false;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  late AnimationController _walkerController;
  late Animation<Offset> _walkerOffset;
  late Animation<double> _walkerTilt;
  Timer? _walkerStopTimer;

  @override
  void initState() {
    super.initState();
    _activeDayKey = _argentinaDateKey();
    _setupCelebrationAnimation();
    _setupWalkerAnimation();
    _scheduleMidnightReset();
    _loadStepSource();
    _loadStats();
    _loadPepitas();
    _loadWeeklyActivity();
    _initPedometer();
    _loadFeatured();
    _loadMissions();
    // Mostrar notificación persistente de progreso
    _showProgressNotification();
    // Sincronización ultra-frecuente para sensación de tiempo real
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _syncSteps(),
    );
  }

  void _setupCelebrationAnimation() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _celebrationScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
  }

  void _setupWalkerAnimation() {
    _walkerController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _walkerOffset =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0.08, 0)).animate(
          CurvedAnimation(parent: _walkerController, curve: Curves.easeInOut),
        );
    _walkerTilt = Tween<double>(begin: -0.06, end: 0.08).animate(
      CurvedAnimation(parent: _walkerController, curve: Curves.easeInOut),
    );
  }

  void _triggerWalkerAnimation() {
    _walkerStopTimer?.cancel();
    if (!_walkerController.isAnimating) {
      _walkerController.repeat(reverse: true);
    }
    _walkerStopTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _walkerController.stop();
      _walkerController.reset();
    });
  }

  void _scheduleRealtimeSync() {
    _realtimeSyncDebounce?.cancel();
    _realtimeSyncDebounce = Timer(const Duration(seconds: 3), _syncSteps);
  }

  Future<void> _loadStepSource() async {
    final saved = await _storage.read(key: 'step_source');
    if (saved != null && mounted) {
      setState(() => _stepSource = saved);
    }
  }

  void _initPedometer() {
    _stepSub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        final dayKey = _argentinaDateKey();
        if (dayKey != _activeDayKey) {
          _activeDayKey = dayKey;
          _initialSteps = event.steps;
          if (mounted) {
            setState(() {
              _steps = 0;
              _sessionSteps = 0;
              _lastSyncedSteps = 0;
              _xpToday = 0;
              _dailyGoalReached = false;
            });
          }
          _showProgressNotification();
          return;
        }

        _initialSteps ??= event.steps;
        final delta = event.steps - _initialSteps!;
        final newSteps = delta < 0 ? 0 : delta;
        final previousSessionSteps = _sessionSteps;

        if (mounted) {
          setState(() {
            _sessionSteps = newSteps;
          });
          if (newSteps > previousSessionSteps) {
            _triggerWalkerAnimation();
            _scheduleRealtimeSync();
          }
          // Actualizar notificación persistente
          _showProgressNotification();
        }

        // Detectar cuando se alcanza la meta diaria (10,000 pasos)
        final totalSteps = _steps + newSteps;
        if (totalSteps >= _dailyGoal && !_dailyGoalReached) {
          _showDailyGoalAchievement();
        }

        // Sincronizar por bloques muy cortos para máxima reactividad
        if (newSteps - _lastSyncedSteps >= 5) {
          _syncSteps();
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus _) {},
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _loadFeatured() async {
    try {
      final list = await ApiService.getFeaturedBusinesses();
      if (mounted) {
        setState(() {
          _featured = list.map((b) => Business.fromJson(b)).toList();
          _featuredLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _featuredLoading = false);
    }
  }

  Future<void> _loadPepitas() async {
    try {
      final data = await ApiService.getPepitaBalance();
      if (mounted) {
        setState(() {
          _pepitas = data['pepitas_balance'] ?? data['balance'] ?? _pepitas;
          _pepitasLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pepitasLoading = false);
    }
  }

  Future<void> _loadMissions() async {
    try {
      final data = await ApiService.getGeoMissions();
      if (mounted) {
        final missionItems = data['data'] is List<dynamic>
            ? data['data'] as List<dynamic>
            : (data['missions'] as List<dynamic>? ?? []);
        setState(() {
          _missions = missionItems
              .map((m) => GeoMissionDto.fromJson(m as Map<String, dynamic>))
              .toList();
          _missionsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _missionsLoading = false);
    }
  }

  Future<void> _loadWeeklyActivity() async {
    try {
      final data = await ApiService.getWeeklyActivity();
      if (mounted) {
        setState(() {
          _weekly = WeeklyActivitySummary.fromJson(data);
          _weeklyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _weeklyLoading = false);
      }
    }
  }

  Future<void> _showProgressNotification() async {
    await NotificationService.showProgressNotification(
      steps: _totalSteps,
      coins: _liveCoins,
      dailyGoal: _dailyGoal,
    );
  }

  void _showDailyGoalAchievement() async {
    _dailyGoalReached = true;

    // Disparar animación de celebración
    _celebrationController.forward().then((_) {
      _celebrationController.reverse();
    });

    // Reproducir sonido y vibración
    await CelebrationService.celebrate(withSound: true, withVibration: true);

    // Mostrar notificación de felicitaciones
    NotificationService.showLocal(
      title: '🎉 ¡Meta Diaria Alcanzada!',
      body: 'Felicidades, ¡lograste $_dailyGoal pasos! Ganaste bonus.',
    );
  }

  // Total = pasos de la API (histórico) + pasos en esta sesión
  int get _totalSteps => _steps + _sessionSteps;
  int get _pendingSteps => math.max(0, _sessionSteps - _lastSyncedSteps);
  int get _liveCoins => _coins + (_pendingSteps ~/ 100);

  DateTime _argentinaNow() {
    // Argentina UTC-3 (sin DST actual)
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }

  String _argentinaDateKey() {
    final now = _argentinaNow();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _scheduleMidnightReset() {
    _midnightResetTimer?.cancel();
    final nowUtc = DateTime.now().toUtc();
    final arNow = _argentinaNow();
    final nextArMidnightUtc = DateTime.utc(
      arNow.year,
      arNow.month,
      arNow.day,
    ).add(const Duration(days: 1, hours: 3));
    final wait = nextArMidnightUtc.difference(nowUtc);
    _midnightResetTimer = Timer(wait, _handleMidnightReset);
  }

  void _handleMidnightReset() {
    _activeDayKey = _argentinaDateKey();
    _initialSteps = null;
    if (mounted) {
      setState(() {
        _steps = 0;
        _sessionSteps = 0;
        _lastSyncedSteps = 0;
        _xpToday = 0;
        _dailyGoalReached = false;
      });
    }
    _showProgressNotification();
    _loadStats();
    _scheduleMidnightReset();
  }

  String _todayDate() {
    final now = _argentinaNow();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _syncSteps() async {
    final pendingSteps = _sessionSteps - _lastSyncedSteps;
    if (pendingSteps <= 0) return;
    final date = _todayDate();

    // If using a health platform, prefer its total for accuracy
    int stepsToSync = _totalSteps;
    String source = _stepSource;
    if (_stepSource == 'google_fit' || _stepSource == 'healthkit') {
      final healthSteps = await HealthService.getTodaySteps();
      if (healthSteps != null && healthSteps > 0) {
        stepsToSync = healthSteps;
        if (mounted) setState(() => _sessionSteps = healthSteps - _steps);
      }
    }

    // Save locally first
    await OfflineSyncService.saveSteps(
      date: date,
      steps: stepsToSync,
      source: source,
    );
    // Then try to flush to backend
    await OfflineSyncService.flushPending();
    _lastSyncedSteps = _sessionSteps;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _realtimeSyncDebounce?.cancel();
    _midnightResetTimer?.cancel();
    _walkerStopTimer?.cancel();
    _stepSub?.cancel();
    _statusSub?.cancel();
    _celebrationController.dispose();
    _walkerController.dispose();
    // Remover notificación persistente al salir
    NotificationService.cancelProgressNotification();
    super.dispose();
  }

  int _prevStreak = 0;

  Future<void> _loadStats() async {
    try {
      final stats = await ApiService.getStats();
      if (mounted) {
        final previousBaseSteps = _steps;
        final nextBaseSteps =
            stats['today_steps'] ?? stats['total_steps'] ?? _steps;
        final newStreak = stats['streak'] ?? _streak;
        setState(() {
          _steps = nextBaseSteps;
          _coins = stats['coins'] ?? _coins;
          _level = stats['level'] ?? _level;
          _streak = newStreak;
          _xpTotal = stats['xp_total'] ?? _xpTotal;
          _xpToday = stats['xp_today'] ?? _xpToday;
          _xpCurrentLevelStart =
              stats['xp_current_level_start'] ?? _xpCurrentLevelStart;
          _xpNextLevelTarget =
              stats['xp_next_level_target'] ?? _xpNextLevelTarget;
          _nextLevel = stats['next_level'] ?? _nextLevel;
            _maxLevel = stats['max_level'] ?? _maxLevel;
            _isMaxLevel = stats['is_max_level'] ?? (_level >= _maxLevel);
            _apiLevelTitle = stats['level_title'] ?? _apiLevelTitle;
          _levelBaseXp = stats['level_base_xp'] ?? _levelBaseXp;
          _levelGrowthXp = stats['level_growth_xp'] ?? _levelGrowthXp;
          _dailyGoal = stats['daily_steps_goal'] ?? _dailyGoal;
          _pepitas = stats['pepitas_balance'] ?? _pepitas;
          _loading = false;
        });
        if (nextBaseSteps > previousBaseSteps) {
          _triggerWalkerAnimation();
        }
        // Notify on streak milestones
        const milestones = [3, 7, 14, 30];
        if (newStreak > _prevStreak && milestones.contains(newStreak)) {
          NotificationService.showLocal(
            title: '🔥 ¡Racha de $newStreak días!',
            body: 'Seguís caminando — ¡mantené el ritmo!',
          );
        }
        _prevStreak = newStreak;
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _levelTitle {
    if ((_apiLevelTitle ?? '').isNotEmpty) {
      return _apiLevelTitle!;
    }
    if (_level >= 26) return 'Explorador Maestro';
    if (_level >= 21) return 'Explorador Elite';
    if (_level >= 16) return 'Explorador Experto';
    if (_level >= 11) return 'Explorador Avanzado';
    if (_level >= 6) return 'Explorador Activo';
    return 'Explorador Novato';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadStats();
                  await _loadPepitas();
                  await _loadWeeklyActivity();
                  await _loadMissions();
                },
                color: cs.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeader(isDark, textPrimary, textSecondary),
                      const SizedBox(height: 16),
                      _buildLevelStreak(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildPepitasCard(),
                      const SizedBox(height: 16),
                      _buildStepRing(isDark, card, textPrimary, textSecondary),
                      const SizedBox(height: 16),
                      _buildWeeklyActivityCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildMissionsCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildNudgeCard(isDark, textPrimary, textSecondary),
                      const SizedBox(height: 20),
                      _buildLocalSpotlight(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildMapPreview(isDark, textPrimary, textSecondary),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onOpenSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
            ),
            child: ClipOval(
              child: Image.network(
                'https://i.pravatar.cc/80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'WalkWin',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelStreak(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        // Level card
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LevelProgressScreen(
                    level: _level,
                    xpTotal: _xpTotal,
                    levelStartXp: _xpCurrentLevelStart,
                    nextLevelXp: _xpNextLevelTarget,
                    nextLevel: _nextLevel,
                    levelBaseXp: _levelBaseXp,
                    levelGrowthXp: _levelGrowthXp,
                    maxLevel: _maxLevel,
                    isMaxLevel: _isMaxLevel,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'NIVEL\nACTUAL',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.military_tech_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Level $_level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _levelTitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ver progresión',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Streak card â€“ white bg
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'RACHA\nACTIVA',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFE8691B),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_streak Días',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '¡Seguí así!',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepRing(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final stepProgress = (_totalSteps / _dailyGoal).clamp(0.0, 1.0);
    final stepPct = (stepProgress * 100).round();
    final xpDenominator = (_xpNextLevelTarget - _xpCurrentLevelStart);
    final xpProgress = _isMaxLevel || xpDenominator <= 0
      ? 1.0
      : ((_xpTotal - _xpCurrentLevelStart) / xpDenominator).clamp(0.0, 1.0);
    final stepsFormatted = _totalSteps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: stepProgress,
                          isDark: isDark,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SlideTransition(
                                position: _walkerOffset,
                                child: AnimatedBuilder(
                                  animation: _walkerTilt,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _walkerTilt.value,
                                      child: child,
                                    );
                                  },
                                  child: const Icon(
                                    Icons.directions_run_rounded,
                                    color: AppColors.primary,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stepsFormatted,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Meta: ${_dailyGoal ~/ 1000}.000',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Badge minimalista de monedas - clickeable
              Positioned(
                top: 1,
                right: 1,
                child: GestureDetector(
                  onTap: widget.onNavigateToPremios,
                  child: ScaleTransition(
                    scale: _celebrationScale,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD88A), Color(0xFFF7B94A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(140)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE19A2F).withAlpha(90),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(170),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wallet_rounded,
                              size: 13,
                              color: Color(0xFF7A4A00),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '$_liveCoins',
                            style: const TextStyle(
                              color: Color(0xFF3A2600),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.0,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'XP de Experiencia',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$_xpToday XP hoy',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: xpProgress,
              backgroundColor: isDark
                  ? AppColors.dividerDark
                  : AppColors.dividerLight,
              color: stepPct >= 100
                  ? const Color(0xFF10B981)
                  : AppColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isMaxLevel
                  ? 'Nivel máximo alcanzado (Nivel $_maxLevel)'
                  : 'Te faltan ${(_xpNextLevelTarget - _xpTotal).clamp(0, 999999)} XP para nivel $_nextLevel',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPepitasConversionSheet() async {
    if (_coins <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavia no tenes monedas para convertir.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: '100');
    final converted = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final card = isDark ? AppColors.cardDark : Colors.white;
        final textPrimary = isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight;
        final textSecondary = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  'Convertir monedas a pepitas',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo actual: $_coins monedas • $_pepitas pepitas',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de monedas',
                    hintText: 'Ej: 100',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'La conversión queda sujeta a los límites diarios del sistema.',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final value = int.tryParse(controller.text.trim());
                          if (value == null || value <= 0) return;
                          Navigator.of(context).pop(value);
                        },
                        child: const Text('Convertir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    if (converted == null || converted <= 0 || !mounted) return;

    if (converted > _coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tenes suficientes monedas para convertir.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final result = await ApiService.convertCoinsToPepitas(
        coins: converted,
      );
      final updatedCoins = result['coins_balance'] ?? result['coins'] ?? _coins;
      final updatedPepitas =
          result['pepitas_balance'] ?? result['balance'] ?? _pepitas;
      if (!mounted) return;
      setState(() {
        _coins = updatedCoins;
        _pepitas = updatedPepitas;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Convertiste $converted monedas en pepitas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar la conversion.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPepitasCard() {
    return GestureDetector(
      onTap: _openPepitasConversionSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withAlpha(36),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.diamond_rounded,
                color: Color(0xFFFFD166),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pepitas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_pepitasLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFD166),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo: $_pepitas pepitas',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tocá para convertir monedas y usar las recompensas nuevas.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(170),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeCard(bool isDark, Color textPrimary, Color textSecondary) {
    final stepsLeft = math.max(0, 500 - (_totalSteps % 500));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardAltDark : const Color(0xFFEAEDF5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_cafe_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Café Mañanero',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$stepsLeft pasos para el café',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSecondary),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_weeklyLoading) {
      return Container(
        height: 170,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final weekly = _weekly;
    if (weekly == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Registro semanal',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${weekly.exerciseDaysCompleted} de ${weekly.exerciseGoalDays}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekly.days
                .map(
                  (d) => _buildDayBadge(d, isDark, textPrimary, textSecondary),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildWeeklyMetric(
                  'Pasos',
                  weekly.totalSteps.toString(),
                  textPrimary,
                  textSecondary,
                ),
              ),
              Expanded(
                child: _buildWeeklyMetric(
                  'Distancia',
                  '${weekly.totalDistanceKm.toStringAsFixed(2)} km',
                  textPrimary,
                  textSecondary,
                ),
              ),
              Expanded(
                child: _buildWeeklyMetric(
                  'Calorías',
                  weekly.totalCaloriesKcal != null
                      ? '${weekly.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
                      : '--',
                  textPrimary,
                  textSecondary,
                ),
              ),
            ],
          ),
          if (weekly.needsProfileData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardAltDark : const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      weekly.profileHint ??
                          'Para un calculo mas preciso, completa tus datos en Ajustes.',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenSettings,
                    child: const Text('Ir a Ajustes'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayBadge(
    WeeklyActivityDay day,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final bg = day.completed
        ? AppColors.primary.withAlpha(40)
        : (isDark ? AppColors.cardAltDark : const Color(0xFFF0F2F6));
    final border = day.completed
        ? AppColors.primary.withAlpha(120)
        : Colors.transparent;

    return Column(
      children: [
        Container(
          width: 32,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(
            day.completed ? Icons.check_rounded : Icons.remove,
            color: day.completed ? AppColors.primary : textSecondary,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day.label,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyMetric(
    String title,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionsCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_missionsLoading) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_missions.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = _missions.where((m) => m.isCompleted).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MissionsScreen(missions: _missions),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Misiones Activas',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$completedCount/${_missions.length} realizadas',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Toca para ver el detalle de tus misiones',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _missions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final mission = _missions[index];
                  final progressSteps =
                      (mission.progressSteps / mission.targetSteps * 100)
                          .clamp(0, 100)
                          .toInt();
                  final progressBusinesses =
                      mission.nearbyBusinessesRequired > 0
                      ? (mission.progressBusinesses /
                                mission.nearbyBusinessesRequired *
                                100)
                            .clamp(0, 100)
                            .toInt()
                      : 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardAltDark
                          : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: mission.isCompleted
                            ? AppColors.primary
                            : Colors.transparent,
                        width: mission.isCompleted ? 2 : 0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                mission.title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (mission.isCompleted)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${mission.rewardCoins}🪙',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (mission.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            mission.description!,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Progress bars
                        Column(
                          children: [
                            // Pasos
                            Row(
                              children: [
                                Text(
                                  'Pasos',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: mission.targetSteps > 0
                                          ? mission.progressSteps /
                                                mission.targetSteps
                                          : 0,
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? AppColors.cardDark
                                          : const Color(0xFFE0E0E0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary.withAlpha(200),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$progressSteps%',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Comercios
                            Row(
                              children: [
                                Text(
                                  'Comercios',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value:
                                          mission.nearbyBusinessesRequired > 0
                                          ? mission.progressBusinesses /
                                                mission.nearbyBusinessesRequired
                                          : 0,
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? AppColors.cardDark
                                          : const Color(0xFFE0E0E0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary.withAlpha(200),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$progressBusinesses%',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalSpotlight(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Destacados del Barrio',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: widget.onNavigateToPremios,
              child: const Text(
                'Ver todos',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Contenido ─────────────────────────────────────────
        if (_featuredLoading)
          SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_featured.isEmpty)
          _buildFeaturedEmpty(isDark, card, textSecondary)
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _featured.length > 3 ? 3 : _featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildFeaturedCard(
                _featured[i],
                isDark,
                card,
                textPrimary,
                textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedCard(
    Business b,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: () => widget.onNavigateToMap?.call(b),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 230,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen de fondo
              b.imageUrl != null
                  ? Image.network(
                      b.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _featuredPlaceholder(isDark),
                    )
                  : _featuredPlaceholder(isDark),

              // Gradiente oscuro
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(190)],
                  ),
                ),
              ),

              // Badge "Destacado"
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(220),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE8A020),
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Destacado',
                        style: TextStyle(
                          color: Color(0xFF0F1428),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nombre + monedas
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.eco_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${b.checkinRewardCoins}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.map_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardAltDark : const Color(0xFFCDD4E8),
      child: const Center(
        child: Icon(
          Icons.store_rounded,
          size: 50,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }

  Widget _buildFeaturedEmpty(bool isDark, Color card, Color textSecondary) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, color: textSecondary, size: 28),
            const SizedBox(height: 6),
            Text(
              'No hay comercios destacados por ahora.',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardAltDark : const Color(0xFFD8E4F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Map pattern (lines)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _MapPatternPainter(isDark: isDark),
            ),
          ),
          // Explore pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Explorar rutas cercanas',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Walking FAB
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_walk_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = isDark ? AppColors.dividerDark : AppColors.dividerLight
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

class _MapPatternPainter extends CustomPainter {
  final bool isDark;
  _MapPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? const Color(0xFF2A3550).withAlpha(120)
          : const Color(0xFFB0C4DE).withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Horizontal road lines
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width * 0.55, size.height * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.35),
      Offset(size.width, size.height * 0.6),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.65),
      Offset(size.width * 0.4, size.height * 0.65),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.65),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, size.height * 0),
      Offset(size.width * 0.6, size.height * 0.35),
      paint,
    );

    // Dashed route line
    final routePaint = Paint()
      ..color = AppColors.primary.withAlpha(isDark ? 180 : 140)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.65)
      ..lineTo(size.width * 0.3, size.height * 0.65)
      ..lineTo(size.width * 0.3, size.height * 0.35)
      ..lineTo(size.width * 0.55, size.height * 0.35);

    _drawDashedPath(canvas, path, routePaint, 8, 5);

    // Pin / location dot
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.35),
      6,
      dotPaint,
    );

    // Triangle pointing down (destination marker)
    final trianglePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final trianglePath = Path()
      ..moveTo(size.width * 0.55, size.height * 0.12)
      ..lineTo(size.width * 0.55 - 10, size.height * 0.35)
      ..lineTo(size.width * 0.55 + 10, size.height * 0.35)
      ..close();
    canvas.drawPath(trianglePath, trianglePaint);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPatternPainter old) => old.isDark != isDark;
}
