import 'package:flutter/material.dart';

import '../models/vacancy.dart';
import '../services/vacancy_service.dart';

/// Formulario para crear (POST) o editar (PUT) una vacante.
/// Si recibe [vacancy] edita; si no, crea una nueva.
/// Al guardar regresa la vacante que devolvió la API.
class VacancyFormScreen extends StatefulWidget {
  final Vacancy? vacancy;

  const VacancyFormScreen({super.key, this.vacancy});

  @override
  State<VacancyFormScreen> createState() => _VacancyFormScreenState();
}

class _VacancyFormScreenState extends State<VacancyFormScreen> {
  // Mismos valores que acepta el @Pattern del backend
  static const _modes = ['Presencial', 'Híbrido', 'Remoto'];

  final _formKey = GlobalKey<FormState>();
  final _service = VacancyService();

  late final _title = TextEditingController(text: widget.vacancy?.title);
  late final _company = TextEditingController(text: widget.vacancy?.company);
  late final _location = TextEditingController(text: widget.vacancy?.location);
  late final _salary = TextEditingController(
    text: widget.vacancy?.salary.round().toString(),
  );
  late final _openings = TextEditingController(
    text: widget.vacancy?.openings.toString(),
  );
  late final _description = TextEditingController(
    text: widget.vacancy?.description,
  );
  late final _requirements = TextEditingController(
    text: widget.vacancy?.requirements,
  );

  List<Category> _categories = [];
  late int? _categoryId = widget.vacancy?.categoryId;
  late String _mode = widget.vacancy?.mode ?? 'Presencial';
  late bool _active = widget.vacancy?.active ?? true;
  bool _saving = false;

  bool get _isEditing => widget.vacancy != null;

  @override
  void initState() {
    super.initState();
    _service
        .getCategories()
        .then((categories) {
          if (mounted) setState(() => _categories = categories);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _company,
      _location,
      _salary,
      _openings,
      _description,
      _requirements,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vacancy = Vacancy(
      id: widget.vacancy?.id,
      title: _title.text.trim(),
      company: _company.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      requirements: _requirements.text.trim(),
      categoryId: _categoryId!,
      salary: double.parse(_salary.text),
      openings: int.parse(_openings.text),
      mode: _mode,
      imageUrl:
          widget.vacancy?.imageUrl, // se conserva; Supabase llega en el Hito 2
      active: _active,
    );

    setState(() => _saving = true);
    try {
      final saved = _isEditing
          ? await _service.updateVacancy(vacancy)
          : await _service.createVacancy(vacancy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Vacante actualizada' : 'Vacante creada'),
        ),
      );
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---- Validaciones (las mismas reglas que el backend) ----

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo obligatorio' : null;

  String? _number(String? value) {
    if (_required(value) != null) return 'Campo obligatorio';
    final n = int.tryParse(value!.trim());
    if (n == null) return 'Solo números enteros';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar vacante' : 'Nueva vacante'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_title, 'Puesto', validator: _required),
            _field(_company, 'Empresa', validator: _required),
            _field(_location, 'Ubicación', validator: _required),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Área'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) => setState(() => _categoryId = id),
                validator: (id) => id == null ? 'Elige un área' : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Modalidad'),
                items: [
                  for (final m in _modes)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (m) => setState(() => _mode = m!),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _salary,
                    'Salario mensual',
                    prefix: '\$ ',
                    keyboard: TextInputType.number,
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _openings,
                    'Plazas',
                    keyboard: TextInputType.number,
                    validator: _number,
                  ),
                ),
              ],
            ),
            _field(_description, 'Descripción', lines: 3),
            _field(_requirements, 'Requisitos', lines: 3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vacante activa'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear vacante'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    String? prefix,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        maxLines: lines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(labelText: label, prefixText: prefix),
      ),
    );
  }
}
