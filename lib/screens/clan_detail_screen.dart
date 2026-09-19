import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clan_v2_widgets.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class ClanDetailScreen extends StatefulWidget {
  final int clanId;
  final bool isViewingOwn;

  const ClanDetailScreen({
    super.key,
    required this.clanId,
    this.isViewingOwn = false,
  });

  @override
  State<ClanDetailScreen> createState() => _ClanDetailScreenState();
}

class _ClanDetailScreenState extends State<ClanDetailScreen> {
  static const _storage = FlutterSecureStorage();
  ClanDetail? _clan;
  UserClanData? _myData;
  bool _loading = true;
  bool _isMember = false;
  bool _isLeader = false;
  bool _isJoining = false;
  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('ClanDetailScreen');
    AnalyticsService.instance.trackEvent('clan_detail_viewed', properties: {
      'clan_id': widget.clanId,
    });
    _load();
    if (widget.isViewingOwn) _showClanOnboardingOnce();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final myResult = await ApiService.getMyClan();
      final detailResult = await ApiService.getClanDetail(widget.clanId);

      if (mounted) {
        setState(() {
          if (myResult['clan'] != null) {
            _myData = UserClanData.fromJson(myResult['clan']);
            _isMember = _myData!.clanId == widget.clanId;
            _isLeader = _isMember && _myData!.role == 'leader';
          }
          _clan = ClanDetail.fromJson(detailResult['clan']);
          _loading = false;
        });
        _loadClanV2Data();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _improvements = [];
  int _historicalInfluence = 0;
  Map<String, dynamic>? _activeOperation;
  List<dynamic> _trades = [];

  Future<void> _loadClanV2Data() async {
    try {
      final impRes = await ApiService.getClanImprovements(widget.clanId);
      final opRes = await ApiService.getClanOperations(widget.clanId);
      final tradeRes = await ApiService.getClanTrades(widget.clanId);
      if (!mounted) return;
      setState(() {
        _improvements = (impRes['improvements'] as List?) ?? [];
        _historicalInfluence = impRes['historical_influence'] as int? ?? 0;
        _activeOperation = opRes['active_operation'] as Map<String, dynamic>?;
        _trades = (tradeRes['trades'] as List?) ?? [];
      });
    } catch (_) {}
  }

  Future<void> _onSelectRole(String role, int targetUserId) async {
    try {
      final res = await ApiService.assignClanRole(widget.clanId, targetUserId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Rol asignado correctamente')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onBuyImprovement(String key) async {
    try {
      final res = await ApiService.buyClanImprovement(widget.clanId, key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? '¡Mejora comprada!')),
        );
        _loadClanV2Data();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onStartOperation(String type) async {
    try {
      final res = await ApiService.startClanOperation(widget.clanId, type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? '¡Operación iniciada!')),
        );
        _loadClanV2Data();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onAcceptTrade(int tradeId) async {
    try {
      final res = await ApiService.acceptClanTrade(widget.clanId, tradeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Intercambio completado')),
        );
        _loadClanV2Data();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onGiftPe() async {
    final peController = TextEditingController();
    int? selectedRecipientId;
    final members = _clan?.members ?? [];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regalar PE a un compañero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Destinatario'),
              items: members
                  .where((m) => m.userId != _currentUserId)
                  .map((m) => DropdownMenuItem(value: m.userId, child: Text(m.name)))
                  .toList(),
              onChanged: (val) => selectedRecipientId = val,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: peController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad de PE', hintText: 'Ej: 100'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(peController.text) ?? 0;
              if (selectedRecipientId != null && amount > 0) {
                Navigator.pop(ctx);
                try {
                  final res = await ApiService.giftPeToMember(widget.clanId, selectedRecipientId!, amount);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message']?.toString() ?? 'PE regalado exitosamente')),
                    );
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Enviar PE'),
          ),
        ],
      ),
    );
  }


  Future<void> _showClanOnboardingOnce() async {
    const key = 'clan_onboarding_shown';
    final shown = await _storage.read(key: key);
    if (shown == 'true' || !mounted) return;
    await _storage.write(key: key, value: 'true');
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.users, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bienvenido a los Clanes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Unite a un grupo, caminá junto a tus compañeros y compitan por ser los mejores de su departamento.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _onboardingFeatureRow(
                icon: TablerIcons.walk,
                title: 'Generá influencia',
                subtitle: 'Cada paso que des suma para tu clan.',
              ),
              const SizedBox(height: 10),
              _onboardingFeatureRow(
                icon: TablerIcons.trophy,
                title: 'Escalá posiciones',
                subtitle: 'Compití en rankings de departamento y globales.',
              ),
              const SizedBox(height: 10),
              _onboardingFeatureRow(
                icon: TablerIcons.calendar,
                title: 'Temporadas',
                subtitle: 'Cada 30 días arranca una nueva competencia.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboardingFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _joinClan() async {
    setState(() => _isJoining = true);
    try {
      final result = await ApiService.joinClanById(widget.clanId);
      _isMember = true;
      if (mounted) {
        if (result['clan'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Te has unido al clan'), backgroundColor: Color(0xFF10B981), behavior: SnackBarBehavior.floating),
          );
          _load();
        } else {
          _showError(result['error'] ?? 'Error al unirse');
        }
      }
    } catch (_) {
      if (mounted) _showError('Error de conexión');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveClan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonar clan'),
        content: const Text('¿Estás seguro? Tendrás que esperar 7 días para unirte a otro clan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abandonar')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.leaveClan(widget.clanId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) _showError('Error al abandonar');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_clan?.name ?? 'Clan'),
        actions: [
          if (_isLeader)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  // Navigate to edit screen
                } else if (v == 'code') {
                  try {
                    final result = await ApiService.regenerateCode(widget.clanId);
                    if (mounted && result['invitation_code'] != null) {
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nuevo código: ${result['invitation_code']}'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (_) {}
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar Clan')),
                const PopupMenuItem(value: 'code', child: Text('Regenerar Código')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clan == null
              ? const Center(child: Text('Clan no encontrado'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(isDark, card, textPrimary, textSecondary),
                        const SizedBox(height: 16),
                        _buildStatsRow(isDark, card, textPrimary, textSecondary),
                        const SizedBox(height: 16),
                        _buildInviteCard(isDark, card, textPrimary, textSecondary),
                        const SizedBox(height: 16),
                        // Clan v2 Weekly Operation Progress
                        ClanOperationCardWidget(
                          activeOperation: _activeOperation,
                          onStartOperationTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Iniciar Operación Semanal'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('Expedición (5 POIs)'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _onStartOperation('expedition');
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Incursión (10 Miembros)'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _onStartOperation('incursion');
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Festival (5 Check-ins)'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _onStartOperation('festival');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Clan v2 Improvements Tree
                        ClanImprovementTreeWidget(
                          improvements: _improvements,
                          historicalInfluence: _historicalInfluence,
                          onBuyImprovement: _onBuyImprovement,
                        ),
                        const SizedBox(height: 16),
                        // Clan v2 Trade Market & Gifts
                        ClanTradeMarketWidget(
                          trades: _trades,
                          onAcceptTradeTap: _onAcceptTrade,
                          onGiftPeTap: _onGiftPe,
                        ),
                        const SizedBox(height: 16),
                        _buildMembersSection(isDark, card, textPrimary, textSecondary),
                        const SizedBox(height: 20),
                        if (!_isMember)
                          ElevatedButton(
                            onPressed: _isJoining ? null : _joinClan,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isJoining
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Unirse al Clan', style: TextStyle(fontSize: 16)),
                          )
                        else ...[
                          if (!_isLeader)
                            OutlinedButton(
                              onPressed: _leaveClan,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Abandonar Clan', style: TextStyle(color: AppColors.danger)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A9BFF), Color(0xFF207AF5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _clan!.name.isNotEmpty ? _clan!.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_clan!.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          if (_clan!.description != null && _clan!.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_clan!.description!, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TablerIcons.map_pin, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(_clan!.department, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          if (_clan!.departmentPosition != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '#${_clan!.departmentPosition} en ${_clan!.department}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Miembros', '${_clan!.memberCount}', TablerIcons.users, isDark, card, textPrimary, textSecondary)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Influencia', '${_clan!.seasonInfluence}', TablerIcons.trending_up, isDark, card, textPrimary, textSecondary)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Temporada', '${_clan!.daysLeftInSeason}d', TablerIcons.calendar, isDark, card, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildInviteCard(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(TablerIcons.link, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Código de invitación', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _clan!.invitationCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado'), behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardAltDark : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_clan!.invitationCode, style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const Icon(TablerIcons.copy, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Miembros', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${_clan!.members.length}', style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        ..._clan!.members.map((m) => _buildMemberTile(m, isDark, card, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildMemberTile(ClanMemberInfo member, bool isDark, Color card, Color textPrimary, Color textSecondary) {
    final isUser = member.userId == _currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: isUser ? Border.all(color: AppColors.primary.withAlpha(80)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: member.role == 'leader' ? const Color(0xFFFFB800).withAlpha(30) : AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#${member.rank}',
                style: TextStyle(
                  color: member.role == 'leader' ? const Color(0xFFFFB800) : AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (member.role == 'leader') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Líder', style: TextStyle(color: Color(0xFFFFB800), fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text('${member.seasonInfluence} influencia', style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (_isLeader && member.role != 'leader')
            IconButton(
              icon: const Icon(TablerIcons.circle_minus, color: AppColors.danger, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Expulsar miembro'),
                    content: Text('¿Expulsar a ${member.name}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Expulsar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ApiService.kickMember(widget.clanId, member.userId);
                    _load();
                  } catch (_) {
                    _showError('Error al expulsar');
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}
