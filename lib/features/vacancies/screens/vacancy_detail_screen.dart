import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../models/vacancy.dart';
import '../services/vacancy_service.dart';
import '../widgets/vacancy_card.dart';
import 'vacancy_form_screen.dart';

/// Detalle de una vacante con opciones para editarla o eliminarla.
/// Regresa `true` al catálogo si hubo cambios, para que recargue la lista.
class VacancyDetailScreen extends StatefulWidget {
  final Vacancy vacancy;

  const VacancyDetailScreen({super.key, required this.vacancy});

  @override
  State<VacancyDetailScreen> createState() => _VacancyDetailScreenState();
}

class _VacancyDetailScreenState extends State<VacancyDetailScreen> {
  final _service = VacancyService();
  late Vacancy _vacancy = widget.vacancy;
  bool _changed = false;
  bool _deleting = false;

  Future<void> _edit() async {
    final updated = await Navigator.push<Vacancy>(
      context,
      MaterialPageRoute(builder: (_) => VacancyFormScreen(vacancy: _vacancy)),
    );
    if (updated != null) {
      setState(() {
        _vacancy = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar vacante'),
        content: Text('¿Seguro que quieres eliminar "${_vacancy.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await _service.deleteVacancy(_vacancy.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vacante eliminada')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      // Al regresar (botón o gesto) avisamos si hubo cambios
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: _deleting ? null : _edit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _deleting ? null : _delete,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VacancyCard(vacancy: _vacancy),
            if (!_vacancy.active) ...[
              const SizedBox(height: 12),
              const Text(
                'Esta vacante está inactiva.',
                style: TextStyle(color: AppColors.error),
              ),
            ],
            _Section(
              title: 'Descripción',
              body: _vacancy.description,
              text: text,
            ),
            _Section(
              title: 'Requisitos',
              body: _vacancy.requirements,
              text: text,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? body;
  final TextTheme text;

  const _Section({required this.title, required this.body, required this.text});

  @override
  Widget build(BuildContext context) {
    if (body == null || body!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body!, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Quita el prefijo "Exception: " para mostrar solo el mensaje.
String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
