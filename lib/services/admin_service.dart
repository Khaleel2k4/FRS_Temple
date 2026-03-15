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
  final String? camera;

  PersonEntry({
    required this.id,
    required this.personName,
    required this.imageUrl,
    this.s3Key,
    this.faceConfidence,
    required this.captureTime,
    required this.createdAt,
    required this.entryType,
    this.camera,
  });

  factory PersonEntry.fromJson(Map<String, dynamic> json) {
    // Extract camera from person_name if camera field is not available
    String? camera = json['camera'];
    if (camera == null || camera.isEmpty) {
      final personName = json['person_name'] ?? '';
      // Look for patterns like "F1", "F2", "F3", "F4" in the person name
      // Updated regex to catch both "_F1_" and "_F1" patterns
      final match = RegExp(r'_F(\d+)(?:_|$)').firstMatch(personName);
      if (match != null) {
        final cameraNum = match.group(1);
        camera = 'camera$cameraNum';
      }
    }
    
    print('🔗 PersonEntry: Parsing entry - ID: ${json['id']}, Name: ${json['person_name']}, Camera: $camera');
    
    try {
      // Parse RFC 1123 date format from backend manually
      DateTime captureTime;
      DateTime createdAt;
      
      // Helper function to parse RFC 1123 format
      DateTime parseRfc1123Date(String dateString) {
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          // Manual parsing for RFC 1123 format: "Sun, 15 Mar 2026 14:00:22 GMT" or "Sun, 15 Mar 2026 14:00:22"
          final months = {
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
          };
          
          // Remove "GMT" if present and split the date string
          final cleanDate = dateString.replaceAll(' GMT', '').replaceAll('UTC', '');
          final parts = cleanDate.split(' ');
          
          // Handle different RFC 1123 formats
          if (parts.length >= 5) {
            try {
              int day, month, year, hour, minute, second;
              
              // Format: "Sun, 15 Mar 2026 14:00:22"
              if (parts.length >= 6) {
                day = int.parse(parts[1]);
                month = months[parts[2]] ?? 1;
                year = int.parse(parts[3]);
                final timeParts = parts[4].split(':');
                hour = int.parse(timeParts[0]);
                minute = int.parse(timeParts[1]);
                second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
              } else {
                // Alternative format
                day = int.parse(parts[0]);
                month = months[parts[1]] ?? 1;
                year = int.parse(parts[2]);
                final timeParts = parts[3].split(':');
                hour = int.parse(timeParts[0]);
                minute = int.parse(timeParts[1]);
                second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
              }
              
              return DateTime.utc(year, month, day, hour, minute, second);
            } catch (parseError) {
              // If parsing fails, try a simpler approach
              return DateTime.tryParse(cleanDate) ?? DateTime.now();
            }
          }
          
          // Final fallback - try without any processing
          return DateTime.tryParse(cleanDate) ?? DateTime.now();
        }
      }
      
      captureTime = parseRfc1123Date(json['capture_time']);
      createdAt = parseRfc1123Date(json['created_at']);
      
      return PersonEntry(
        id: json['id'],
        personName: json['person_name'],
        imageUrl: json['image_url'],
        s3Key: json['s3_key'],
        faceConfidence: json['face_confidence']?.toDouble(),
        captureTime: captureTime,
        createdAt: createdAt,
        entryType: json['entry_type'] ?? 'unknown',
        camera: camera,
      );
    } catch (e) {
      print('🔗 PersonEntry: Error creating PersonEntry: $e');
      print('🔗 PersonEntry: JSON data: $json');
      rethrow;
    }
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
      'camera': camera,
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
    String? camera,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (personName != null) 'person_name': personName,
        'entry_type': entryType,
        if (camera != null) 'camera': camera,
      };

      final uri = Uri.parse('$baseUrl/api/persons').replace(queryParameters: queryParams);
      print('🔗 AdminService: Requesting $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      print('🔗 AdminService: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔗 AdminService: Response data keys: ${data.keys}');
        print('🔗 AdminService: Success flag: ${data['success']}');
        
        if (data['success'] == true) {
          final List<dynamic> personsJson = data['persons'];
          print('🔗 AdminService: Persons array length: ${personsJson.length}');
          
          if (personsJson.isNotEmpty) {
            print('🔗 AdminService: Sample person data: ${personsJson.first}');
          }
          
          final persons = personsJson.map((json) {
            try {
              return PersonEntry.fromJson(json);
            } catch (e) {
              print('🔗 AdminService: Error parsing person: $e');
              print('🔗 AdminService: Problematic JSON: $json');
              rethrow;
            }
          }).toList();
          
          print('🔗 AdminService: Successfully parsed ${persons.length} persons');
          return persons;
        } else {
          print('🔗 AdminService: API returned success=false');
        }
      } else {
        print('🔗 AdminService: HTTP error: ${response.statusCode}');
      }
      return [];
    } catch (e, stackTrace) {
      print('🔗 AdminService: Get persons failed: $e');
      print('🔗 AdminService: Stack trace: $stackTrace');
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
