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
