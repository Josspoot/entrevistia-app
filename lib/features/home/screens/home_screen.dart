import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../shared/brand/brand.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _service = VacancyService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Category> _categories = [];
  List<Vacancy> _vacancies = [];
  int? _selectedCategoryId; // null = todas las áreas
  bool _loading = true;
  String? _error;

  // Entrada: el encabezado aparece y la hoja blanca sube
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadVacancies();
  }

  @override
  void dispose() {
    _enter.dispose();
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
    final header = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );
    final sheet = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.night,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: false,
          title: const Wordmark(fontSize: 20),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _signOut,
            ),
            const SizedBox(width: 4),
          ],
        ),
        extendBodyBehindAppBar: true,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreate,
          backgroundColor: AppColors.night,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Vacante'),
        ),
        body: NightBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight),
                FadeTransition(
                  opacity: header,
                  child: _Header(
                    email: user?.email ?? '',
                    count: _loading || _error != null
                        ? null
                        : _vacancies.length,
                  ),
                ),
                Expanded(
                  // La hoja blanca sube desde abajo al entrar
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(sheet),
                    child: FadeTransition(opacity: sheet, child: _buildSheet()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
        showCheckmark: false,
        // Seleccionado: pastilla oscura con texto blanco
        selectedColor: AppColors.night,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: _selectedCategoryId == id
              ? Colors.white
              : AppColors.textPrimary,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
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
  final int? count; // null mientras carga

  const _Header({required this.email, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onNight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vacantes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == null
                      ? 'Encuentra tu próxima entrevista'
                      : '$count disponibles para practicar',
                  style: const TextStyle(color: AppColors.onNight),
                ),
              ],
            ),
          ),
          const Halo(size: 120, child: BlobCharacter(size: 84)),
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
