/// Área de trabajo (Tecnología, Diseño, Ventas…).
/// Equivale a la "categoría" de la rúbrica.
class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['categoryId'] as int,
      name: json['category'] as String,
    );
  }
}

/// Vacante de empleo que devuelve la API de Spring Boot.
/// Equivalencias con la rúbrica: producto → vacante,
/// precio → salario mensual, stock → plazas disponibles.
class Vacancy {
  /// null cuando la vacante aún no existe (se está creando).
  final int? id;
  final String title;
  final String company;
  final String? description;
  final String? requirements;
  final int categoryId;
  final double salary;
  final int openings;
  final String mode;
  final String location;
  final String? imageUrl;
  final bool active;
  final Category? category;

  const Vacancy({
    this.id,
    required this.title,
    required this.company,
    this.description,
    this.requirements,
    required this.categoryId,
    required this.salary,
    required this.openings,
    required this.mode,
    required this.location,
    this.imageUrl,
    this.active = true,
    this.category,
  });

  factory Vacancy.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Vacancy(
      id: json['vacancyId'] as int,
      title: json['title'] as String,
      company: json['company'] as String,
      description: json['description'] as String?,
      requirements: json['requirements'] as String?,
      categoryId: json['categoryId'] as int,
      // El salario llega como número JSON (BigDecimal en Java)
      salary: (json['salary'] as num).toDouble(),
      openings: json['openings'] as int,
      mode: json['mode'] as String,
      location: json['location'] as String,
      imageUrl: json['imageUrl'] as String?,
      active: json['active'] as bool? ?? true,
      category: category == null ? null : Category.fromJson(category),
    );
  }

  /// Cuerpo JSON para POST y PUT. El id va en la URL, no en el cuerpo.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'company': company,
      'description': description,
      'requirements': requirements,
      'categoryId': categoryId,
      'salary': salary,
      'openings': openings,
      'mode': mode,
      'location': location,
      'imageUrl': imageUrl,
      'active': active,
    };
  }
}
