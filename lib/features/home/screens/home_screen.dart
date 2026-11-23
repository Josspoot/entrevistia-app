import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../shared/character/blob_character.dart';
import '../../vacancies/models/vacancy.dart';
import '../../vacancies/screens/vacancy_detail_screen.dart';
import '../../vacancies/screens/vacancy_form_screen.dart';
import '../../vacancies/services/vacancy_service.dart';
import '../../vacancies/widgets/vacancy_card.dart';

/// Pantalla principal: catálogo de vacantes que viene de la API
/// de Spring Boot, con búsqueda por puesto y filtro por área.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = VacancyService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Category> _categories = [];
  List<Vacancy> _vacancies = [];
  int? _selectedCategoryId; // null = todas las áreas
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadVacancies();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _service.getCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Sin categorías solo se ocultan los filtros; la lista sigue
    }
  }

  Future<void> _loadVacancies() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vacancies = await _service.getVacancies(
        search: _searchController.text,
        categoryId: _selectedCategoryId,
      );
      if (!mounted) return;
      setState(() => _vacancies = vacancies);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Servidor no disponible');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Espera 400 ms después de la última tecla antes de consultar,
  /// para no hacer una petición por cada letra.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadVacancies);
  }

  void _selectCategory(int? id) {
    setState(() => _selectedCategoryId = id);
    _loadVacancies();
  }

  /// Abre el detalle; si ahí se editó o eliminó, recarga la lista.
  Future<void> _openDetail(Vacancy vacancy) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VacancyDetailScreen(vacancy: vacancy)),
    );
    if (changed == true) _loadVacancies();
  }

  /// Abre el formulario vacío; si se creó la vacante, recarga la lista.
  Future<void> _openCreate() async {
    final created = await Navigator.push<Vacancy>(
      context,
      MaterialPageRoute(builder: (_) => const VacancyFormScreen()),
    );
    if (created != null) _loadVacancies();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EntrevistIA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Vacante'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(email: user?.email ?? ''),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Buscar puesto…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (_categories.isNotEmpty) _buildCategoryChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Todas', null),
          for (final category in _categories) _chip(category.name, category.id),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedCategoryId == id,
        selectedColor: AppColors.secondary,
        onSelected: (_) => _selectCategory(id),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _vacancies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Message(
        icon: Icons.wifi_off,
        text: _error!,
        action: FilledButton(
          onPressed: _loadVacancies,
          child: const Text('Reintentar'),
        ),
      );
    }
    if (_vacancies.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        text: 'No hay vacantes con esos filtros.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadVacancies,
      child: ListView.separated(
        // Espacio abajo para que el botón + no tape la última tarjeta
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _vacancies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => VacancyCard(
          vacancy: _vacancies[i],
          onTap: () => _openDetail(_vacancies[i]),
        ),
      ),
    );
  }
}

/// Saludo con el blob (tócalo: reacciona y cambia de color).
class _Header extends StatelessWidget {
  final String email;

  const _Header({required this.email});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const BlobCharacter(size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Hola!',
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('Encuentra una vacante y prepárate para la entrevista',
                    style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
