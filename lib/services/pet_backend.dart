import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pet_catalog.dart';

/// Minimal client to forward pet changes to a backend API when configured.
///
/// Set the API base URL at build time:
/// `flutter run --dart-define=PET_API_URL=https://your-api.example.com`
///
/// Endpoints expected:
/// - POST   /pets                    (body: PetCatalogItem JSON)
/// - PUT    /pets/{title}            (body: PetCatalogItem JSON)
/// - DELETE /pets/{title}
class PetBackend {
  const PetBackend();

  static const String _baseUrl =
      String.fromEnvironment('PET_API_URL', defaultValue: '');

  bool get isConfigured => _baseUrl.isNotEmpty;

  Map<String, String> get _headers =>
      const {'Content-Type': 'application/json'};

  Uri _petsUri([String? title]) {
    if (title == null || title.isEmpty) {
      return Uri.parse('$_baseUrl/pets');
    }
    final encoded = Uri.encodeComponent(title);
    return Uri.parse('$_baseUrl/pets/$encoded');
  }

  /// Create a new pet or update an existing one on the backend.
  Future<void> upsert(PetCatalogItem pet, {String? previousTitle}) async {
    if (!isConfigured) return;
    final body = jsonEncode(pet.toJson());
    final uri = previousTitle == null
        ? _petsUri()
        : _petsUri(previousTitle.isEmpty ? pet.title : previousTitle);
    final resp = previousTitle == null
        ? await http.post(uri, headers: _headers, body: body)
        : await http.put(uri, headers: _headers, body: body);
    if (resp.statusCode >= 400) {
      throw Exception(
          'Backend rejected pet (${resp.statusCode}): ${resp.body}');
    }
  }

  /// Remove a pet from the backend by its (normalized) title.
  Future<void> delete(String title) async {
    if (!isConfigured) return;
    final resp = await http.delete(_petsUri(title), headers: _headers);
    if (resp.statusCode >= 400) {
      throw Exception(
          'Backend failed to delete (${resp.statusCode}): ${resp.body}');
    }
  }
}
