import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../models/vacancy.dart';

/// Consume los endpoints GET de la API de vacantes.
class VacancyService {
  static const _timeout = Duration(seconds: 10);

  /// GET /vacancies con filtros opcionales.
  /// [search] busca texto en el puesto; [categoryId] filtra por área.
  Future<List<Vacancy>> getVacancies({String? search, int? categoryId}) async {
    final params = <String, String>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (categoryId != null) 'categoryId': '$categoryId',
    };
    final uri = Uri.parse('$apiBaseUrl/vacancies')
        .replace(queryParameters: params.isEmpty ? null : params);

    final data = await _getJsonList(uri);
    return data.map((item) => Vacancy.fromJson(item)).toList();
  }

  /// GET /categories
  Future<List<Category>> getCategories() async {
    final data = await _getJsonList(Uri.parse('$apiBaseUrl/categories'));
    return data.map((item) => Category.fromJson(item)).toList();
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  /// POST /vacancies → 201 con la vacante creada.
  Future<Vacancy> createVacancy(Vacancy vacancy) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/vacancies'),
          headers: _jsonHeaders,
          body: jsonEncode(vacancy.toJson()),
        )
        .timeout(_timeout);
    _check(response, 201);
    return Vacancy.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  /// PUT /vacancies/{id} → 200 con la vacante actualizada.
  Future<Vacancy> updateVacancy(Vacancy vacancy) async {
    final response = await http
        .put(
          Uri.parse('$apiBaseUrl/vacancies/${vacancy.id}'),
          headers: _jsonHeaders,
          body: jsonEncode(vacancy.toJson()),
        )
        .timeout(_timeout);
    _check(response, 200);
    return Vacancy.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  /// DELETE /vacancies/{id} → 204 sin cuerpo.
  Future<void> deleteVacancy(int id) async {
    final response = await http
        .delete(Uri.parse('$apiBaseUrl/vacancies/$id'))
        .timeout(_timeout);
    _check(response, 204);
  }

  /// Lanza una excepción con un mensaje entendible si el código no es el esperado.
  void _check(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    throw Exception(switch (response.statusCode) {
      400 => 'Datos inválidos. Revisa los campos.',
      404 => 'La vacante ya no existe.',
      _ => 'Error ${response.statusCode} del servidor.',
    });
  }

  Future<List<Map<String, dynamic>>> _getJsonList(Uri uri) async {
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode} al consultar $uri');
    }
    // utf8.decode para que lleguen bien los acentos (Diseño, Híbrido…)
    final List<dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
    return json.cast<Map<String, dynamic>>();
  }
}
