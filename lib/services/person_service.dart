import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class PersonService {
  static String _baseUrl = '${Environment.backendBaseUrl}/api';

  static Future<Map<String, dynamic>> addPerson({
    required String personName,
    required String imageUrl,
    String? s3Key,
    double? faceConfidence,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/persons'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'person_name': personName,
          'image_url': imageUrl,
          's3_key': s3Key,
          'face_confidence': faceConfidence,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Person added successfully'};
      } else {
        return {
          'success': false,
          'error': 'Failed to add person: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error adding person: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getPersons({
    String? personName,
    int limit = 100,
  }) async {
    try {
      String url = '$_baseUrl/persons?limit=$limit';
      if (personName != null && personName.isNotEmpty) {
        url += '&person_name=$personName';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'persons': data['persons'] ?? []
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get persons: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error getting persons: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUniquePersons() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/persons/unique'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'persons': data['persons'] ?? []
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get unique persons: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error getting unique persons: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getRecentCaptures({
    int hours = 24,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/persons/recent?hours=$hours')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'persons': data['persons'] ?? []
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get recent captures: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error getting recent captures: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deletePersonEntry(int entryId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/persons/$entryId')
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Person entry deleted successfully'};
      } else {
        return {
          'success': false,
          'error': 'Failed to delete person entry: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error deleting person entry: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkPersonExists(String personName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/persons/exists?person_name=$personName')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'exists': data['exists'] ?? false
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check person exists: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error checking person exists: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addPassInEntry({
    required String personName,
    required String imageUrl,
    String? s3Key,
    double? faceConfidence,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/persons/pass-in'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'person_name': personName,
          'image_url': imageUrl,
          's3_key': s3Key,
          'face_confidence': faceConfidence,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'entry_id': data['entry_id'],
          'message': 'Pass-in entry added successfully'
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to add pass-in entry: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error adding pass-in entry: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addPassOutEntry({
    required String personName,
    required String imageUrl,
    String? s3Key,
    double? faceConfidence,
    int? passInEntryId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/persons/pass-out'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'person_name': personName,
          'image_url': imageUrl,
          's3_key': s3Key,
          'face_confidence': faceConfidence,
          'pass_in_entry_id': passInEntryId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'entry_id': data['entry_id'],
          're_entry_count': data['re_entry_count'],
          'message': 'Pass-out entry added successfully'
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to add pass-out entry: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error adding pass-out entry: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getPersonStats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/persons/stats'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'stats': data['stats'] ?? {}
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get person stats: ${response.statusCode}'
        };
      }
    } catch (e) {
      developer.log('Error getting person stats: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
