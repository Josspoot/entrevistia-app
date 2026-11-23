import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../models/vacancy.dart';

/// Tarjeta de una vacante en el catálogo.
/// Muestra lo que pide la rúbrica: nombre, precio (salario),
/// stock (plazas) y categoría (área).
class VacancyCard extends StatelessWidget {
  final Vacancy vacancy;
  final VoidCallback? onTap;

  const VacancyCard({super.key, required this.vacancy, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      clipBehavior:
          Clip.antiAlias, // para que el efecto del toque respete las esquinas
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompanyInitial(company: vacancy.company),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vacancy.title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vacancy.company} · ${vacancy.location}',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${formatSalary(vacancy.salary)} / mes',
                style: text.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (vacancy.category != null)
                    _Tag(vacancy.category!.name, AppColors.lilac),
                  _Tag(vacancy.mode, AppColors.mint),
                  _Tag(
                    vacancy.openings == 1
                        ? '1 plaza'
                        : '${vacancy.openings} plazas',
                    vacancy.openings == 0
                        ? AppColors.border
                        : AppColors.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatea 18000.0 como "$18,000".
String formatSalary(double salary) {
  final digits = salary.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    // Coma cada tres cifras contando desde la derecha
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '\$$buffer';
}

/// Círculo con la inicial de la empresa.
/// En el Hito 2 se cambiará por el logo guardado en Supabase (imageUrl).
class _CompanyInitial extends StatelessWidget {
  final String company;

  const _CompanyInitial({required this.company});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.sky,
      child: Text(
        company.isEmpty ? '?' : company[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
