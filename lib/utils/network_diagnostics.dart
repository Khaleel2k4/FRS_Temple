import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class NetworkDiagnostics {
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    final results = <String, dynamic>{};
    
    // 1. Test basic network connectivity
    results['ping_test'] = await _testPing();
    
    // 2. Test HTTP connection
    results['http_test'] = await _testHttpConnection();
    
    // 3. Test backend health endpoint
    results['health_test'] = await _testHealthEndpoint();
    
    // 4. Test AWS connection
    results['aws_test'] = await _testAWSConnection();
    
    return results;
  }
  
  static Future<String> _testPing() async {
    try {
      final result = await Process.run('ping', ['-n', '1', '10.16.74.126']);
      if (result.exitCode == 0) {
        return 'Success: Server is reachable';
      } else {
        return 'Failed: Server not reachable';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  static Future<String> _testHttpConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.16.74.126:5000/'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return 'Success: HTTP connection working (${response.statusCode})';
      } else {
        return 'Failed: HTTP error (${response.statusCode})';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  static Future<String> _testHealthEndpoint() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.backendBaseUrl}/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return 'Success: Health endpoint working';
      } else {
        return 'Failed: Health endpoint error (${response.statusCode})';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  static Future<String> _testAWSConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.backendBaseUrl}/api/aws/test-connection'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return 'Success: AWS connection working';
      } else {
        return 'Failed: AWS connection error (${response.statusCode})';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  static String formatDiagnosticsResults(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('=== Network Diagnostics Results ===\n');
    
    results.forEach((test, result) {
      buffer.writeln('$test: $result');
    });
    
    buffer.writeln('\n=== Troubleshooting Tips ===');
    buffer.writeln('1. If ping test fails: Check network connection and IP address');
    buffer.writeln('2. If HTTP test fails: Backend server may not be running');
    buffer.writeln('3. If health test fails: Backend may have issues');
    buffer.writeln('4. If AWS test fails: Check AWS credentials and S3 bucket');
    
    return buffer.toString();
  }
}
