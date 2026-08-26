import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class ClanCreateScreen extends StatefulWidget {
  const ClanCreateScreen({super.key});

  @override
  State<ClanCreateScreen> createState() => _ClanCreateScreenState();
}

class _ClanCreateScreenState extends State<ClanCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedProvince;
  String? _selectedDepartment;
  List<String> _provinces = [];
  List<String> _departments = [];
  bool _loadingProvinces = true;
  bool _loadingDepartments = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('ClanCreateScreen');
    _loadProvinces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provs = await ApiService.getProvinces();
      if (mounted) {
        setState(() {
          _provinces = provs.cast<String>();
          _loadingProvinces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProvinces = false);
      }
    }
  }

  Future<void> _loadDepartments() async {
    if (_selectedProvince == null) return;
    setState(() => _loadingDepartments = true);
    try {
      final deps = await ApiService.getDepartments(province: _selectedProvince);
      if (mounted) {
        setState(() {
          _departments = deps.cast<String>();
          _selectedDepartment = null;
          _loadingDepartments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDepartments = false);
      }
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('El nombre del clan es obligatorio');
      return;
    }
    if (_selectedProvince == null) {
      _showError('Seleccioná una provincia');
      return;
    }
    if (_selectedDepartment == null) {
      _showError('Seleccioná un departamento');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ApiService.createClan(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        province: _selectedProvince!,
        department: _selectedDepartment!,
      );
      if (mounted) {
        if (result['clan'] != null) {
          Navigator.of(context).pop(true);
        } else {
          _showError(result['error'] ?? 'Error al crear el clan');
        }
      }
    } catch (e) {
      if (mounted) _showError('Error de conexión');
    } finally {
      if (mounted) setState(() => _saving = false);
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
      appBar: AppBar(title: const Text('Crear Clan')),
      body: _loadingProvinces
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nombre del Clan', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Ej: Los Cóndores',
                            filled: true,
                            fillColor: isDark ? AppColors.cardAltDark : const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Descripción (opcional)', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          style: TextStyle(color: textPrimary),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Describí tu clan...',
                            filled: true,
                            fillColor: isDark ? AppColors.cardAltDark : const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Provincia', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardAltDark : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedProvince,
                              hint: Text('Seleccioná una provincia', style: TextStyle(color: textSecondary)),
                              isExpanded: true,
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedProvince = v;
                                  _selectedDepartment = null;
                                  _departments = [];
                                });
                                _loadDepartments();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Departamento', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardAltDark : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: _loadingDepartments
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(),
                                  )
                                : DropdownButton<String>(
                                    value: _selectedDepartment,
                                    hint: Text('Seleccioná un departamento', style: TextStyle(color: textSecondary)),
                                    isExpanded: true,
                                    style: TextStyle(color: textPrimary, fontSize: 15),
                                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                    onChanged: (v) => setState(() => _selectedDepartment = v),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('La provincia y el departamento no podrán modificarse después.', style: TextStyle(color: textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Crear Clan', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
