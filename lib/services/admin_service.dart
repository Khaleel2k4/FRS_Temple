import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class PersonEntry {
  final int id;
  final String personName;
  final String imageUrl;
  final String? s3Key;
  final double? faceConfidence;
  final DateTime captureTime;
  final DateTime createdAt;
  final String entryType;

  PersonEntry({
    required this.id,
    required this.personName,
    required this.imageUrl,
    this.s3Key,
    this.faceConfidence,
    required this.captureTime,
    required this.createdAt,
    required this.entryType,
  });

  factory PersonEntry.fromJson(Map<String, dynamic> json) {
    return PersonEntry(
      id: json['id'],
      personName: json['person_name'],
      imageUrl: json['image_url'],
      s3Key: json['s3_key'],
      faceConfidence: json['face_confidence']?.toDouble(),
      captureTime: DateTime.parse(json['capture_time']),
      createdAt: DateTime.parse(json['created_at']),
      entryType: json['entry_type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'person_name': personName,
      'image_url': imageUrl,
      's3_key': s3Key,
      'face_confidence': faceConfidence,
      'capture_time': captureTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'entry_type': entryType,
    };
  }
}

class PersonStats {
  final int totalPersons;
  final int totalCaptures;
  final int passInCount;
  final int reEntryCount;
  final int uniquePersons;

  PersonStats({
    required this.totalPersons,
    required this.totalCaptures,
    required this.passInCount,
    required this.reEntryCount,
    required this.uniquePersons,
  });

  factory PersonStats.fromJson(Map<String, dynamic> json) {
    return PersonStats(
      totalPersons: json['total_persons'] ?? 0,
      totalCaptures: json['total_captures'] ?? 0,
      passInCount: json['pass_in_count'] ?? 0,
      reEntryCount: json['re_entry_count'] ?? 0,
      uniquePersons: json['unique_persons'] ?? 0,
    );
  }
}

class AdminService {
  static const String baseUrl = Environment.backendBaseUrl;

  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Admin service connection test failed: $e');
      return false;
    }
  }

  static Future<List<PersonEntry>> getPersons({
    String? personName,
    int limit = 100,
    String entryType = 'all', // 'all', 'pass_in', 're_entry'
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (personName != null) 'person_name': personName,
        'entry_type': entryType,
      };

      final uri = Uri.parse('$baseUrl/api/persons').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> personsJson = data['persons'];
          return personsJson.map((json) => PersonEntry.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Get persons failed: $e');
      return [];
    }
  }

  static Future<List<String>> getUniquePersons() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/persons/unique'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> personsJson = data['persons'];
          return personsJson.map((json) => json.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Get unique persons failed: $e');
      return [];
    }
  }

  static Future<List<PersonEntry>> getRecentCaptures({int hours = 24}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/persons/recent?hours=$hours'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> personsJson = data['persons'];
          return personsJson.map((json) => PersonEntry.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Get recent captures failed: $e');
      return [];
    }
  }

  static Future<PersonStats?> getPersonStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/persons/stats'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return PersonStats.fromJson(data['stats']);
        }
      }
      return null;
    } catch (e) {
      print('Get person stats failed: $e');
      return null;
    }
  }

  static Future<bool> deletePersonEntry(int entryId, {String table = 'pass_in'}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/persons/$entryId?table=$table'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Delete person entry failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getBucketInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/bucket/info'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['bucket'];
        }
      }
      return null;
    } catch (e) {
      print('Get bucket info failed: $e');
      return null;
    }
  }

  static Future<bool> testAWSConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/aws/test-connection'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true && data['connected'] == true;
      }
      return false;
    } catch (e) {
      print('Test AWS connection failed: $e');
      return false;
    }
  }
}
