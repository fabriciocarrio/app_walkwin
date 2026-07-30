import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'clan_detail_screen.dart';

class ClanRankingsScreen extends StatefulWidget {
  const ClanRankingsScreen({super.key});

  @override
  State<ClanRankingsScreen> createState() => _ClanRankingsScreenState();
}

class _ClanRankingsScreenState extends State<ClanRankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ClanRankingEntry> _departmentRankings = [];
  List<ClanRankingEntry> _globalRankings = [];
  bool _loading = true;
  String? _selectedDepartment;
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDepartments();
    _loadRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final deps = await ApiService.getDepartments();
      if (mounted) setState(() => _departments = deps.cast<String>());
    } catch (_) {}
  }

  Future<void> _loadRankings() async {
    setState(() => _loading = true);
    try {
      final deptResult = await ApiService.getDepartmentRankings(department: _selectedDepartment);
      final globalResult = await ApiService.getGlobalClanRankings();
      if (mounted) {
        setState(() {
          final deptList = deptResult['rankings'] is List ? deptResult['rankings'] : [];
          final globalList = globalResult['rankings'] is List ? globalResult['rankings'] : [];
          _departmentRankings = deptList.map((c) => ClanRankingEntry.fromJson(c as Map<String, dynamic>)).toList();
          _globalRankings = globalList.map((c) => ClanRankingEntry.fromJson(c as Map<String, dynamic>)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
        title: const Text('Rankings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Departamento'),
            Tab(text: 'Global'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDepartmentTab(isDark, card, textPrimary, textSecondary),
                _buildGlobalTab(isDark, card, textPrimary, textSecondary),
              ],
            ),
    );
  }

  Widget _buildDepartmentTab(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        if (_departments.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDeptChip('Todos', null, isDark, card),
                ..._departments.map((d) => _buildDeptChip(d, d, isDark, card)),
              ],
            ),
          ),
        Expanded(
          child: _departmentRankings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 64, color: textSecondary),
                      const SizedBox(height: 16),
                      Text('Sin clanes en este departamento', style: TextStyle(color: textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRankings,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _departmentRankings.length,
                    itemBuilder: (_, i) => _buildRankingCard(_departmentRankings[i], i, isDark, card, textPrimary, textSecondary),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDeptChip(String label, String? value, bool isDark, Color card) {
    final selected = _selectedDepartment == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedDepartment = value);
          _loadRankings();
        },
        backgroundColor: card,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildGlobalTab(bool isDark, Color card, Color textPrimary, Color textSecondary) {
    if (_globalRankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_rounded, size: 64, color: textSecondary),
            const SizedBox(height: 16),
            Text('Sin clanes aún', style: TextStyle(color: textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRankings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _globalRankings.length,
        itemBuilder: (_, i) => _buildRankingCard(_globalRankings[i], i, isDark, card, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildRankingCard(ClanRankingEntry entry, int index, bool isDark, Color card, Color textPrimary, Color textSecondary) {
    final isKing = index == 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClanDetailScreen(clanId: entry.id)),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: isKing ? Border.all(color: const Color(0xFFFFB800), width: 2) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isKing ? const Color(0xFFFFB800).withAlpha(30) : AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isKing
                      ? const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 22)
                      : Text(
                          '${entry.rank}',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        if (isKing)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('REY', style: TextStyle(color: Color(0xFFFFB800), fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: textSecondary),
                        const SizedBox(width: 2),
                        Text(entry.department, style: TextStyle(color: textSecondary, fontSize: 11)),
                        const SizedBox(width: 12),
                        Icon(Icons.people_rounded, size: 12, color: textSecondary),
                        const SizedBox(width: 2),
                        Text('${entry.memberCount}', style: TextStyle(color: textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${entry.seasonInfluence}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('influencia', style: TextStyle(color: textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
