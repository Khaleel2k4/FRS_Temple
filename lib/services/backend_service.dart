import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class BackendService {
  static const String baseUrl = Environment.backendBaseUrl;
  
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Backend connection failed: $e');
      return false;
    }
  }
  
  static Future<bool> testAWSConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/aws/test-connection'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['connected'] ?? false;
      }
      return false;
    } catch (e) {
      print('AWS connection test failed: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> uploadFile(File file, {String? folder}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/file'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      return json.decode(responseData);
    } catch (e) {
      print('File upload failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> uploadImage(File imageFile, {String? folder}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/image'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      return json.decode(responseData);
    } catch (e) {
      print('Image upload failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  static Future<List<Map<String, dynamic>>> listFiles({String? prefix}) async {
    try {
      final url = prefix != null 
          ? '$baseUrl/api/files/list?prefix=$prefix'
          : '$baseUrl/api/files/list';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['files']);
      }
      return [];
    } catch (e) {
      print('List files failed: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>?> getFileInfo(String objectName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/files/$objectName/info'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['file'];
      }
      return null;
    } catch (e) {
      print('Get file info failed: $e');
      return null;
    }
  }
  
  static Future<String?> getFileUrl(String objectName, {int expiration = 3600}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/files/$objectName/url?expiration=$expiration')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      }
      return null;
    } catch (e) {
      print('Get file URL failed: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>> deleteFile(String objectName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/files/$objectName'),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Delete file failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> getBucketInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/bucket/info'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'error': 'Failed to get bucket info'};
    } catch (e) {
      print('Get bucket info failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
