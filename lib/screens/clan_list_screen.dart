import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'clan_create_screen.dart';
import 'clan_detail_screen.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class ClanListScreen extends StatefulWidget {
  const ClanListScreen({super.key});

  @override
  State<ClanListScreen> createState() => _ClanListScreenState();
}

class _ClanListScreenState extends State<ClanListScreen> {
  List<ClanInfo> _clans = [];
  bool _loading = true;
  String? _selectedDepartment;
  List<String> _departments = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await ApiService.searchClans(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        department: _selectedDepartment,
      );
      final deps = await ApiService.getDepartments();
      if (mounted) {
        setState(() {
          _clans = results.map((c) => ClanInfo.fromJson(c as Map<String, dynamic>)).toList();
          _departments = deps.cast<String>();
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
        title: const Text('Clanes'),
        actions: [
          IconButton(
            icon: const Icon(TablerIcons.plus),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ClanCreateScreen()),
              );
              if (created == true) _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar clan...',
                    prefixIcon: Icon(TablerIcons.search, color: textSecondary),
                    filled: true,
                    fillColor: card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 8),
                if (_departments.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('Todos', null, card),
                        ..._departments.map((d) => _buildFilterChip(d, d, card)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _clans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(TablerIcons.users, size: 64, color: textSecondary),
                            const SizedBox(height: 16),
                            Text('No hay clanes aún', style: TextStyle(color: textSecondary, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Creá el primer clan', style: TextStyle(color: textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _clans.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildClanCard(_clans[i], isDark, card, textPrimary, textSecondary),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, Color cardColor) {
    final selected = _selectedDepartment == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedDepartment = value);
          _load();
        },
        backgroundColor: cardColor,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildClanCard(ClanInfo clan, bool isDark, Color card, Color textPrimary, Color textSecondary) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClanDetailScreen(clanId: clan.id)),
          );
          _load();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.dividerDark : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    clan.name.isNotEmpty ? clan.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clan.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(TablerIcons.map_pin, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(clan.department, style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(TablerIcons.users, size: 16, color: Color(0xFF20D4A4)),
                      const SizedBox(width: 4),
                      Text('${clan.memberCount}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${clan.seasonInfluence} inf.', style: TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
