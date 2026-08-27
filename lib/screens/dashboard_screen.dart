import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shimmer/shimmer.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';
import '../services/celebration_service.dart';
import '../services/step_counting_service.dart';
import '../theme/app_theme.dart';
import 'level_progress_screen.dart';
import 'earn_pe_screen.dart';
import 'missions_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'weekly_activity_screen.dart';
import 'clan_list_screen.dart';
import 'clan_detail_screen.dart';
import 'clan_rankings_screen.dart';
import '../config/app_config.dart';
import '../services/analytics_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPremios;
  final void Function(Business?)? onNavigateToMap;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _steps = 0;
  int _peBalance = 1240;
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
  List<Business> _featured = [];
  bool _featuredLoading = true;
  WeeklyActivitySummary? _weekly;
  bool _weeklyLoading = true;
  List<GeoMissionDto> _missions = [];
  bool _missionsLoading = true;
  UserClanData? _clanData;
  bool _clanLoading = true;

  int get _sessionSteps =>
      StepCountingService.instance.sessionStepsNotifier.value;

  // Sincronización al backend
  Timer? _syncTimer;
  Timer? _realtimeSyncDebounce;
  Timer? _midnightResetTimer;
  int _lastSyncedSteps = 0;
  bool _syncing = false;
  String _stepSource = 'native_sensor';
  String _activeDayKey = '';
  static const _storage = FlutterSecureStorage();

  DateTime? _lastNotificationUpdate;
  static const int _notificationThrottleMs = 500;

  // Meta diaria y celebración
  bool _dailyGoalReached = false;
  late AnimationController _celebrationController;
  late AnimationController _walkerController;
  Timer? _walkerStopTimer;
  int _notificationUnread = 0;
  String _userName = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('DashboardScreen');
    WidgetsBinding.instance.addObserver(this);
    _activeDayKey = _argentinaDateKey();
    _setupCelebrationAnimation();
    _setupWalkerAnimation();
    _scheduleMidnightReset();
    _loadStepSource();
    _loadStats();
    _loadWeeklyActivity();
    _loadFeatured();
    _loadMissions();
    _loadClanData();
    _loadUserProfile();

    StepCountingService.instance.onStepCounted = _onStepCounted;
    StepCountingService.instance.onMidnightReset = _onServiceMidnightReset;
    StepCountingService.instance.sessionStepsNotifier.addListener(
      _onSessionStepsChanged,
    );

    NotificationStore.instance.addListener(_onNotificationsChanged);
    _notificationUnread = NotificationStore.instance.unreadCount;

    _showProgressNotification();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _syncSteps(),
    );
  }

  void _onNotificationsChanged() {
    if (mounted) {
      setState(() {
        _notificationUnread = NotificationStore.instance.unreadCount;
      });
    }
  }

  void _setupCelebrationAnimation() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  void _setupWalkerAnimation() {
    _walkerController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
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

  /// Persiste el total de pasos de hoy en SQLite local de forma inmediata.
  ///
  /// Esta llamada es independiente del estado de la red: funciona offline y
  /// no depende de que _loading sea false. Es la primera línea de defensa
  /// para no perder pasos si la app se cierra antes del próximo _syncTimer.
  Future<void> _saveStepsLocally() async {
    if (_totalSteps <= 0) return;
    try {
      await OfflineSyncService.saveSteps(
        date: _todayDate(),
        steps: _totalSteps,
        source: _stepSource,
      );
    } catch (_) {
      // SQLite no debería fallar, pero si ocurre no bloqueamos el flujo.
    }
  }

  Future<void> _loadStepSource() async {
    final saved = await _storage.read(key: 'step_source');
    if (saved != null && mounted) {
      setState(() => _stepSource = saved);
    }
  }

  void _onStepCounted() {
    if (!mounted) return;
    _triggerWalkerAnimation();
    // Persistir en SQLite inmediatamente para no perder pasos si la app crashea
    // antes del próximo _syncTimer. Esta escritura es offline-safe.
    _saveStepsLocally();
    _scheduleRealtimeSync();
    _showProgressNotification();
    if (_sessionSteps - _lastSyncedSteps >= 5) {
      _syncSteps();
    }
  }

  void _onSessionStepsChanged() {
    if (!mounted) return;
    final currentDayKey = _argentinaDateKey();
    if (currentDayKey != _activeDayKey) {
      _activeDayKey = currentDayKey;
      _steps = 0;
      _lastSyncedSteps = 0;
      _xpToday = 0;
      _dailyGoalReached = false;
      _showProgressNotification();
      _loadStats();
    }
    final totalSteps = _steps + _sessionSteps;
    if (totalSteps >= _dailyGoal && !_dailyGoalReached) {
      _showDailyGoalAchievement();
      _showTierExplanationOnce();
    }
    setState(() {});
  }

  Future<void> _showTierExplanationOnce() async {
    const key = 'tier_explanation_shown';
    final shown = await _storage.read(key: key);
    if (shown == 'true' || !mounted) return;
    await _storage.write(key: key, value: 'true');
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(TablerIcons.trophy, color: Color(0xFFF5C535), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Meta cumplida!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguí sumando pasos para ganar más Puntos Exploria:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _tierRow(
              '1ᵉʳ tramo',
              '0 a 10.000',
              '100 pasos = 1 PE',
              const Color(0xFF20D4A4),
            ),
            const SizedBox(height: 10),
            _tierRow(
              '2ᵈᵒ tramo',
              '10.001 a 20.000',
              '200 pasos = 1 PE',
              const Color(0xFFFF6B00),
            ),
            const SizedBox(height: 10),
            _tierRow(
              '3ᵉʳ tramo',
              '20.001 a 30.000',
              '400 pasos = 1 PE',
              const Color(0xFF9C27B0),
            ),
            const SizedBox(height: 12),
            const Text(
              'A partir de 30.000 pasos no se generan más PE en el día.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierRow(String label, String range, String rate, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text('$range • $rate', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDayChange();
    }
  }

  void _checkDayChange() {
    final currentDayKey = _argentinaDateKey();
    if (currentDayKey != _activeDayKey) {
      _activeDayKey = currentDayKey;
      StepCountingService.instance.resetSession();
      if (mounted) {
        setState(() {
          _steps = 0;
          _lastSyncedSteps = 0;
          _xpToday = 0;
          _dailyGoalReached = false;
        });
      }
      _showProgressNotification();
      _loadStats();
      _scheduleMidnightReset();
    }
  }

  void _onServiceMidnightReset() {
    _activeDayKey = _argentinaDateKey();
    if (mounted) {
      setState(() {
        _steps = 0;
        _lastSyncedSteps = 0;
        _xpToday = 0;
        _dailyGoalReached = false;
      });
    }
    _showProgressNotification();
    _loadStats();
    _scheduleMidnightReset();
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

  // Pepitas balance loaded via stats endpoint, no separate load needed.

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

  Future<void> _loadClanData() async {
    try {
      final data = await ApiService.getMyClan();
      if (mounted) {
        if (data['clan'] != null) {
          setState(() {
            _clanData = UserClanData.fromJson(data['clan']);
            _clanLoading = false;
          });
        } else {
          setState(() => _clanLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _clanLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await ApiService.getUserProfile();
      if (mounted) {
        final name = data['name']?.toString() ?? '';
        final avatarId = data['avatar']?.toString();
        String? avatarUrl;
        if (avatarId != null && avatarId.isNotEmpty) {
          final base = AppConfig.apiBaseUrl.replaceAll(
            RegExp(r'/api/v1/?$'),
            '',
          );
          avatarUrl = '$base/img-profile/$avatarId';
        }
        setState(() {
          _userName = name;
          _avatarUrl = avatarUrl;
        });
      }
    } catch (_) {}
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
    final now = DateTime.now();
    if (_lastNotificationUpdate != null &&
        now.difference(_lastNotificationUpdate!).inMilliseconds <
            _notificationThrottleMs) {
      return;
    }
    _lastNotificationUpdate = now;
    await NotificationService.showProgressNotification(
      steps: _totalSteps,
      coins: _livePe,
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
      type: 'goal',
    );
  }

  int get _totalSteps => _steps + _sessionSteps;

  static int _tieredPE(int steps) {
    final t1 = steps.clamp(0, 10000) ~/ 100;
    final t2 = (steps - 10000).clamp(0, 10000) ~/ 200;
    final t3 = (steps - 20000).clamp(0, 10000) ~/ 400;
    return t1 + t2 + t3;
  }

  int get _livePe {
    final confirmedStepPE = _tieredPE(_steps);
    final totalStepPE = _tieredPE(_totalSteps);
    return _peBalance + (totalStepPE - confirmedStepPE);
  }

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
    StepCountingService.instance.resetSession();
    if (mounted) {
      setState(() {
        _steps = 0;
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
    if (_syncing) return; // Solo bloquear si ya hay un sync en curso
    _syncing = true;
    try {
      await _syncStepsInternal();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncStepsInternal() async {
    final date = _todayDate();
    final stepsAtStart = _sessionSteps;

    if (_stepSource == 'google_fit' || _stepSource == 'healthkit') {
      final healthSteps = await HealthService.getTodaySteps();
      if (healthSteps != null && healthSteps > 0) {
        StepCountingService.instance.resetSession();
        if (mounted) setState(() => _lastSyncedSteps = 0);
        await OfflineSyncService.saveSteps(
          date: date,
          steps: healthSteps,
          source: _stepSource,
        );
        final response = await OfflineSyncService.flushPending();
        if (mounted) {
          setState(() {
            if (response != null) {
              _peBalance = (response['new_balance'] as int?) ?? _peBalance;
              _xpTotal = (response['xp_total'] as int?) ?? _xpTotal;
              _level = (response['level'] as int?) ?? _level;
              _streak = (response['streak'] as int?) ?? _streak;
              _dailyGoal = (response['daily_steps_goal'] as int?) ?? _dailyGoal;
            }
          });
        }
      }
      return;
    }

    final pendingSteps = _sessionSteps - _lastSyncedSteps;
    if (pendingSteps <= 0) return;

    await OfflineSyncService.saveSteps(
      date: date,
      steps: _totalSteps,
      source: _stepSource,
    );
    final response = await OfflineSyncService.flushPending();
    // Solo actualizar lastSyncedSteps si _sessionSteps no cambió durante la sync
    if (_sessionSteps == stepsAtStart) {
      _lastSyncedSteps = _sessionSteps;
    } else {
      _lastSyncedSteps = stepsAtStart;
    }
    if (mounted) {
      setState(() {
        if (response != null) {
          _peBalance = (response['new_balance'] as int?) ?? _peBalance;
          _xpTotal = (response['xp_total'] as int?) ?? _xpTotal;
          _level = (response['level'] as int?) ?? _level;
          _streak = (response['streak'] as int?) ?? _streak;
          _dailyGoal = (response['daily_steps_goal'] as int?) ?? _dailyGoal;
        }
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _realtimeSyncDebounce?.cancel();
    _midnightResetTimer?.cancel();
    _walkerStopTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    StepCountingService.instance.onStepCounted = null;
    StepCountingService.instance.onMidnightReset = null;
    StepCountingService.instance.sessionStepsNotifier.removeListener(
      _onSessionStepsChanged,
    );
    _celebrationController.dispose();
    _walkerController.dispose();
    NotificationStore.instance.removeListener(_onNotificationsChanged);
    NotificationService.cancelProgressNotification();
    super.dispose();
  }

  int _prevStreak = 0;

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);
    try {
      final currentDayKey = _argentinaDateKey();
      if (currentDayKey != _activeDayKey) {
        _activeDayKey = currentDayKey;
        await StepCountingService.instance.resetSession();
        _steps = 0;
        _lastSyncedSteps = 0;
      }

      final stats = await ApiService.getStats();
      if (mounted) {
        final nextBaseSteps = (stats['today_steps'] as int?) ?? _steps;
        final newStreak = stats['streak'] ?? _streak;
        // Reconciliación ABSOLUTA: sessionSteps = lo que el sensor tiene localmente
        // MENOS lo que el backend ya tiene confirmado.
        //
        // Invariante: sessionSteps = max(0, totalLocalHoy - backendConfirmadoHoy)
        //
        // Esto evita la duplicación en pull-to-refresh y en reinstalación:
        //   - Si backend tiene 5000 y local tiene 5000 → sessionSteps = 0 ✓
        //   - Si el usuario caminó 10 pasos durante la sync → sessionSteps = 10 ✓
        //   - Si hay datos residuales en storage tras reinstalación → sessionSteps = 0 ✓
        final totalLocalSteps = _steps + _sessionSteps;
        final stepsStillPending = math.max(0, totalLocalSteps - nextBaseSteps);
        if (_sessionSteps != stepsStillPending) {
          await StepCountingService.instance.setConfirmedSession(stepsStillPending);
          // Los pasos pendientes aún no han sido re-enviados en este ciclo
          _lastSyncedSteps = 0;
        }
        setState(() {
          _steps = nextBaseSteps;
          _peBalance = stats['pe_balance'] ?? stats['coins'] ?? _peBalance;
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
          _loading = false;
        });
        // Notify on streak milestones
        const milestones = [3, 7, 14, 30];
        if (newStreak > _prevStreak && milestones.contains(newStreak)) {
          NotificationService.showLocal(
            title: '🔥 ¡Racha de $newStreak días!',
            body: 'Seguís caminando — ¡mantené el ritmo!',
            type: 'streak',
          );
        }
        _prevStreak = newStreak;
      }
      _showProgressNotification();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showProgressNotification();
    }
  }

  String get _levelTitle {
    if ((_apiLevelTitle ?? '').isNotEmpty) {
      return _apiLevelTitle!;
    }
    if (_level >= 26) return 'Maestro Explorador';
    if (_level >= 21) return 'Coleccionista';
    if (_level >= 16) return 'Aventurero';
    if (_level >= 11) return 'Descubridor';
    if (_level >= 6) return 'Explorador';
    return 'Caminante';
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
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(isDark, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _shimmerWrap(isDark, _shimmerMainCard()),
                    const SizedBox(height: 16),
                    _shimmerWrap(isDark, _shimmerPointsStreakRow()),
                    const SizedBox(height: 16),
                    _shimmerWrap(isDark, _shimmerLevelGoalCard()),
                    const SizedBox(height: 24),
                    _shimmerSpotlight(isDark),
                    const SizedBox(height: 16),
                    _shimmerWeeklyCard(isDark),
                    const SizedBox(height: 16),
                    _shimmerMissionsCard(isDark),
                    const SizedBox(height: 16),
                    _shimmerContainer(height: 70, radius: 20),
                    const SizedBox(height: 16),
                    _shimmerClanCard(isDark),
                    const SizedBox(height: 16),
                    _shimmerWrap(
                      isDark,
                      _shimmerContainer(height: 60, radius: 16),
                    ),
                    const SizedBox(height: 16),
                    _shimmerWrap(
                      isDark,
                      _shimmerContainer(height: 160, radius: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await _syncSteps();
                  await _loadStats();
                  await _loadWeeklyActivity();
                  await _loadMissions();
                  await _loadClanData();
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
                      const SizedBox(height: 24),
                      _buildMainDashboardCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildStatsOverviewRow(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 24),
                      _buildMissionsCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildMapPreview(isDark, textPrimary, textSecondary),
                      const SizedBox(height: 16),
                      _buildClanCard(isDark, card, textPrimary, textSecondary),
                      const SizedBox(height: 16),
                      _buildLocalSpotlight(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildWeeklyActivityCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildEarnPeCard(
                        isDark,
                        card,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _avatarPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardDark : const Color(0xFFE8EDF2),
      child: Icon(
        TablerIcons.user,
        size: 20,
        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9BABB8),
      ),
    );
  }

  Widget _shimmerWrap(bool isDark, Widget child) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2F3A) : const Color(0xFFE8EDF2),
      highlightColor: isDark
          ? const Color(0xFF3A3F4A)
          : const Color(0xFFF5F7FA),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }

  Widget _shimmerContainer({
    double? width,
    double? height,
    double radius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _shimmerMainCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A9BFF), Color(0xFF207AF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerContainer(width: 100, height: 16),
              const SizedBox(height: 12),
              _shimmerContainer(width: 140, height: 40, radius: 8),
              const SizedBox(height: 12),
              _shimmerContainer(width: 130, height: 14),
            ],
          ),
          _shimmerContainer(width: 100, height: 100, radius: 50),
        ],
      ),
    );
  }

  Widget _shimmerPointsStreakRow() {
    return Row(
      children: [
        Expanded(child: _shimmerContainer(height: 88)),
        const SizedBox(width: 16),
        Expanded(child: _shimmerContainer(height: 88)),
      ],
    );
  }

  Widget _shimmerLevelGoalCard() {
    return _shimmerContainer(height: 204);
  }

  Widget _shimmerWeeklyCard(bool isDark) {
    return _shimmerWrap(
      isDark,
      Container(
        height: 170,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _shimmerContainer(width: 160, height: 16),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                7,
                (_) => _shimmerContainer(width: 28, height: 28, radius: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerMissionsCard(bool isDark) {
    return _shimmerWrap(
      isDark,
      Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerContainer(width: 130, height: 16),
                _shimmerContainer(width: 80, height: 24, radius: 12),
              ],
            ),
            const SizedBox(height: 8),
            _shimmerContainer(width: 200, height: 12),
            const SizedBox(height: 16),
            _shimmerContainer(width: double.infinity, height: 6, radius: 3),
            const SizedBox(height: 16),
            _shimmerContainer(width: double.infinity, height: 6, radius: 3),
          ],
        ),
      ),
    );
  }

  Widget _shimmerClanCard(bool isDark) {
    return _shimmerWrap(
      isDark,
      Container(
        height: 90,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _shimmerContainer(width: 48, height: 48, radius: 14),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _shimmerContainer(width: 120, height: 14),
                const SizedBox(height: 8),
                _shimmerContainer(width: 180, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerSpotlight(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _shimmerContainer(width: 160, height: 16),
            _shimmerContainer(width: 60, height: 14),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => _shimmerWrap(
              isDark,
              Container(
                width: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _shimmerContainer(width: 72, height: 72, radius: 12),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _shimmerContainer(width: 100, height: 14),
                        const SizedBox(height: 6),
                        _shimmerContainer(width: 80, height: 12),
                        const SizedBox(height: 6),
                        _shimmerContainer(width: 60, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                TablerIcons.menu_2,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF112A46),
              ),
              onPressed: widget.onOpenSettings,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(4),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: _avatarUrl != null
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _avatarPlaceholder(isDark),
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                              ? child
                              : _avatarPlaceholder(isDark),
                        )
                      : _avatarPlaceholder(isDark),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Hola!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF6B7A8D),
                    height: 1.1,
                  ),
                ),
                Text(
                  _userName.isNotEmpty ? _userName : 'Explorador',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : const Color(0xFF112A46),
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // RichText(
        //   text: TextSpan(
        //     style: TextStyle(
        //       fontSize: 22,
        //       fontWeight: FontWeight.w900,
        //       color: isDark ? AppColors.textPrimaryDark : const Color(0xFF112A46),
        //       letterSpacing: 1.0,
        //     ),
        //     children: [
        //       const TextSpan(text: 'EXPL'),
        //       WidgetSpan(
        //         alignment: PlaceholderAlignment.middle,
        //         child: Padding(
        //           padding: const EdgeInsets.symmetric(horizontal: 1.0),
        //           child: Stack(
        //             alignment: Alignment.center,
        //             children: [
        //               const Icon(
        //                 TablerIcons.map_pin,
        //                 size: 24,
        //                 color: Color(0xFF20D4A4),
        //               ),
        //               Positioned(
        //                 top: 5,
        //                 child: Container(
        //                   width: 6,
        //                   height: 6,
        //                   decoration: const BoxDecoration(
        //                     color: Colors.white,
        //                     shape: BoxShape.circle,
        //                   ),
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ),
        //       ),
        //       const TextSpan(text: 'RIA'),
        //     ],
        //   ),
        // ),
        Stack(
          children: [
            IconButton(
              icon: Icon(
                TablerIcons.bell,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF112A46),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (_notificationUnread > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _notificationUnread > 99 ? '99+' : '$_notificationUnread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainDashboardCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final t1Fraction = (_totalSteps / _dailyGoal).clamp(0.0, 1.0);
    final t2Steps = (_totalSteps - _dailyGoal).clamp(0, _dailyGoal);
    final t2Fraction = _dailyGoal > 0 ? t2Steps / _dailyGoal : 0.0;
    final t3Steps = (_totalSteps - 2 * _dailyGoal).clamp(0, _dailyGoal);
    final t3Fraction = _dailyGoal > 0 ? t3Steps / _dailyGoal : 0.0;
    final stepPct = ((_totalSteps / _dailyGoal) * 100).round();
    final stepsFormatted = _totalSteps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    final goalFormatted = _dailyGoal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    final earnedToday = _tieredPE(_totalSteps);

    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF1A4D8F).withAlpha(35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/dashboard-hero.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A9BFF), Color(0xFF207AF5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF1A4D8F).withAlpha(220),
                    const Color(0xFF2E78F0).withAlpha(140),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pasos de hoy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: stepsFormatted,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' pasos',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 190,
                            child: LinearProgressIndicator(
                              value: t1Fraction,
                              minHeight: 10,
                              backgroundColor: Colors.white.withAlpha(80),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF2C78FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Meta: $goalFormatted pasos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C38E).withAlpha(30),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  TablerIcons.star_filled,
                                  color: Color(0xFF22C38E),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '+$earnedToday PE',
                                      style: const TextStyle(
                                        color: Color(0xFF1A2F4B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'obtenidos hoy',
                                      style: TextStyle(
                                        color: Color(0xFF41566F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _SegmentedRingPainter(
                            t1Fraction: t1Fraction,
                            t2Fraction: t2Fraction,
                            t3Fraction: t3Fraction,
                            backgroundColor: Colors.white.withAlpha(80),
                            totalSteps: _totalSteps,
                            dailyGoal: _dailyGoal,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$stepPct%',
                                style: const TextStyle(
                                  color: Color(0xFF153761),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'del objetivo',
                                style: TextStyle(
                                  color: Color(0xFF153761),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverviewRow(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: _buildDashboardMetricCard(
                isDark: isDark,
                card: card,
                title: 'Puntos Exploria',
                accent: const Color(0xFF20D4A4),
                icon: TablerIcons.star_filled,
                value: _livePe.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]}.',
                ),
                footer: _xpToday > 0 ? '+$_xpToday hoy' : 'Seguí caminando',
                footerColor: const Color(0xFF1FB978),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 9,
              child: _buildDashboardMetricCard(
                isDark: isDark,
                card: card,
                title: 'Racha',
                accent: const Color(0xFFFF6B00),
                icon: TablerIcons.flame,
                value: '$_streak',
                footer: _streak == 1 ? 'día seguido' : 'días seguidos',
                footerColor: const Color(0xFFFF6B00),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLevelOverviewCard(
          isDark,
          card,
          textPrimary,
          textSecondary,
        ),
      ],
    );
  }

  Widget _buildDashboardMetricCard({
    required bool isDark,
    required Color card,
    required String title,
    required Color accent,
    required IconData icon,
    required String value,
    required String footer,
    required Color footerColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            footer,
            style: TextStyle(
              color: footerColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelOverviewCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final currentLevelXp = math.max(0, _xpTotal - _xpCurrentLevelStart);
    final nextLevelXp = math.max(1, _xpNextLevelTarget - _xpCurrentLevelStart);
    final progress = _isMaxLevel
        ? 1.0
        : (currentLevelXp / nextLevelXp).clamp(0.0, 1.0);

    return GestureDetector(
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nivel $_level',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _levelTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E78F0).withAlpha(24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    TablerIcons.shield,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark
                    ? AppColors.dividerDark
                    : const Color(0xFFE5EAF2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isMaxLevel
                  ? 'Nivel máximo alcanzado'
                  : '$currentLevelXp / $nextLevelXp XP',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pepitas conversion removed as part of rebranding to PE

  Widget _buildClanCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_clanLoading) {
      return _shimmerClanCard(isDark);
    }

    final hasClan = _clanData != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image
            SizedBox(
              height: 168,
              width: double.infinity,
              child: Image.asset(
                'assets/dashboard-clan.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: hasClan
                      ? AppColors.primary.withAlpha(30)
                      : (isDark
                            ? AppColors.cardAltDark
                            : const Color(0xFFE8EDF5)),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              height: 168,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(hasClan ? 80 : 40),
                    Colors.black.withAlpha(hasClan ? 160 : 120),
                  ],
                ),
              ),
            ),
            // Content
            SizedBox(
              height: 168,
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (hasClan) {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => ClanDetailScreen(
                                    clanId: _clanData!.clanId,
                                    isViewingOwn: true,
                                  ),
                                ),
                              )
                              .then((_) => _loadClanData());
                        } else {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const ClanListScreen(),
                                ),
                              )
                              .then((_) => _loadClanData());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                hasClan
                                    ? TablerIcons.users
                                    : TablerIcons.user_plus,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasClan ? _clanData!.clanName : 'Clanes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasClan
                                        ? '#${_clanData!.memberRank} de ${_clanData!.totalMembers} · ${_clanData!.personalSeasonInfluence} influencia'
                                        : 'Unite o creá un clan',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              TablerIcons.chevron_right,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClanRankingsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              TablerIcons.trophy,
                              size: 18,
                              color: Color(0xFFFFB800),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Rankings de clanes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              TablerIcons.chevron_right,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarnPeCard(
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    Widget earnItem({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color tint,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardAltDark : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(TablerIcons.chevron_right, color: textSecondary, size: 22),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const EarnPeScreen()));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ganar + PE',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              earnItem(
                icon: TablerIcons.gift,
                title: 'Referidos',
                subtitle: '+ PE inmediato',
                tint: const Color(0xFF2E78F0),
              ),
              const SizedBox(height: 10),
              earnItem(
                icon: TablerIcons.dice_6,
                title: 'Ruleta diaria',
                subtitle: 'Hasta 100 PE',
                tint: const Color(0xFF5A84FF),
              ),
              const SizedBox(height: 10),
              earnItem(
                icon: TablerIcons.stars,
                title: 'Más formas de ganar',
                subtitle: 'Misiones y acciones especiales',
                tint: const Color(0xFFFFA63D),
              ),
            ],
          ),
        ),
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
      return _shimmerWeeklyCard(isDark);
    }

    final weekly = _weekly;
    if (weekly == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WeeklyActivityScreen(weekly: weekly),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Actividad semanal',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(TablerIcons.chevron_right, color: textSecondary),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weekly.days
                    .map(
                      (d) => _buildDayBadge(
                        d,
                        isDark,
                        textPrimary,
                        textSecondary,
                        weekly.exerciseThresholdSteps,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayBadge(
    WeeklyActivityDay day,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    int thresholdSteps,
  ) {
    final progress = (day.steps / (thresholdSteps > 0 ? thresholdSteps : 5000))
        .clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          day.label,
          style: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (day.completed) ...[
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF129B85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    TablerIcons.check,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ] else ...[
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.dividerDark : const Color(0xFFE2E8F0),
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF129B85),
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ],
            ],
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
      return _shimmerMissionsCard(isDark);
    }

    final activeMissions = _missions
        .where((m) => m.currentProgress > 0 || m.isCompleted)
        .toList();

    if (activeMissions.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = activeMissions.where((m) => m.isCompleted).length;

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
                      'Misiones del día',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MissionsScreen(missions: _missions),
                        ),
                      );
                    },
                    child: const Text(
                      'Ver todas',
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
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeMissions.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: VerticalDivider(
                      width: 20,
                      indent: 8,
                      endIndent: 8,
                      color: isDark ? AppColors.dividerDark : const Color(0xFFEEEEEE),
                    ),
                  ),
                  itemBuilder: (_, index) {
                    final mission = activeMissions[index];
                    
                    IconData iconData;
                    Color iconColor;
                    Color bgColor;

                    final type = mission.missionType.toLowerCase();
                    final title = mission.title.toLowerCase();

                    if (type.contains('step') || title.contains('paso')) {
                      iconData = TablerIcons.walk;
                      iconColor = const Color(0xFF22C38E);
                      bgColor = const Color(0xFF22C38E).withOpacity(0.15);
                    } else if (type.contains('poi') || title.contains('lugar')) {
                      iconData = TablerIcons.map_pin;
                      iconColor = const Color(0xFF8B5CF6);
                      bgColor = const Color(0xFF8B5CF6).withOpacity(0.15);
                    } else {
                      iconData = TablerIcons.building_store;
                      iconColor = const Color(0xFF3B82F6);
                      bgColor = const Color(0xFF3B82F6).withOpacity(0.15);
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon Circle
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, color: iconColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mission.title,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: mission.targetCount > 0
                                              ? mission.currentProgress / mission.targetCount
                                              : 0,
                                          minHeight: 6,
                                          backgroundColor: isDark
                                              ? AppColors.cardDark
                                              : const Color(0xFFE0E0E0),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            mission.isCompleted ? const Color(0xFF22C38E) : iconColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${mission.currentProgress}/${mission.targetCount}',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                if (mission.isCompleted)
                                  const Icon(
                                    TablerIcons.circle_check,
                                    color: Color(0xFF22C38E),
                                    size: 20,
                                  )
                                else
                                  const SizedBox(width: 20),
                              ],
                            ),
                          ],
                        ),
                        if (!mission.isCompleted) ...[
                          const SizedBox(width: 12),
                          Icon(TablerIcons.chevron_right, color: textSecondary, size: 20),
                        ],
                      ],
                    );
                  },
                ),
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
              'Comercios destacados',
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
          _shimmerSpotlight(isDark)
        else if (_featured.isEmpty)
          _buildFeaturedEmpty(isDark, card, textSecondary)
        else
          SizedBox(
            height: 230,
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
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : Colors.transparent,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Image (Top Half)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 110,
                child: b.imageUrl != null
                    ? Image.network(
                        b.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _featuredPlaceholder(isDark),
                      )
                    : _featuredPlaceholder(isDark),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        TablerIcons.star_filled,
                        color: Color(0xFF22C38E),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.offer ?? 'Promoción local',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.map_pin,
                            color: textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${b.distanceM} m',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B64F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${b.checkinRewardCoins} PE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  Widget _featuredPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardAltDark : const Color(0xFFCDD4E8),
      child: const Center(
        child: Icon(
          TablerIcons.building_store,
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
            Icon(TablerIcons.building_store, color: textSecondary, size: 28),
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
    final discoverLabel = _featured.isEmpty
        ? 'Nuevos lugares para descubrir'
        : '${_featured.length} lugares nuevos para descubrir';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onNavigateToMap?.call(null),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF1A4D8F).withAlpha(22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/dashboard-descubre.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: isDark
                      ? AppColors.cardAltDark
                      : const Color(0xFFD8E4F5),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF204A8D).withAlpha(180),
                      const Color(0xFF2E78F0).withAlpha(70),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Explorá hoy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          TablerIcons.chevron_right,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      discoverLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F5DDA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver mapa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            TablerIcons.map_pin,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
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
}

class _SegmentedRingPainter extends CustomPainter {
  _SegmentedRingPainter({
    required this.t1Fraction,
    required this.t2Fraction,
    required this.t3Fraction,
    required this.backgroundColor,
    required this.totalSteps,
    required this.dailyGoal,
  });

  final double t1Fraction;
  final double t2Fraction;
  final double t3Fraction;
  final Color backgroundColor;
  final int totalSteps;
  final int dailyGoal;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 10.0;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    const startAngle = -math.pi / 2;

    if (t1Fraction > 0) {
      paint.color = const Color(0xFF20D4A4);
      canvas.drawArc(rect, startAngle, 2 * math.pi * t1Fraction, false, paint);
    }

    if (totalSteps > dailyGoal) {
      final t2Start = startAngle + 2 * math.pi * t1Fraction;
      if (t2Fraction > 0) {
        paint.color = const Color(0xFFFF6B00);
        canvas.drawArc(rect, t2Start, 2 * math.pi * t2Fraction, false, paint);
      }

      if (totalSteps > 2 * dailyGoal) {
        final t3Start = t2Start + 2 * math.pi * t2Fraction;
        if (t3Fraction > 0) {
          paint.color = const Color(0xFF9C27B0);
          canvas.drawArc(rect, t3Start, 2 * math.pi * t3Fraction, false, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter oldDelegate) =>
      oldDelegate.t1Fraction != t1Fraction ||
      oldDelegate.t2Fraction != t2Fraction ||
      oldDelegate.t3Fraction != t3Fraction ||
      oldDelegate.totalSteps != totalSteps;
}
