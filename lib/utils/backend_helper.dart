import 'dart:io';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../config/environment.dart';

class BackendHelper {
  static Future<bool> testBackendConnection() async {
    return await BackendService.testConnection();
  }
  
  static Future<bool> testBackendAWSConnection() async {
    return await BackendService.testAWSConnection();
  }
  
  static Future<String?> uploadImageToBackend(File imageFile, {String? folder}) async {
    try {
      final result = await BackendService.uploadImage(imageFile, folder: folder);
      
      if (result['success']) {
        return result['file_url'];
      } else {
        print('Upload failed: ${result['error']}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
  
  static Future<String?> uploadFileToBackend(File file, {String? folder}) async {
    try {
      final result = await BackendService.uploadFile(file, folder: folder);
      
      if (result['success']) {
        return result['file_url'];
      } else {
        print('Upload failed: ${result['error']}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getBackendFiles({String? prefix}) async {
    return await BackendService.listFiles(prefix: prefix);
  }
  
  static Future<Map<String, dynamic>?> getBackendFileInfo(String objectName) async {
    return await BackendService.getFileInfo(objectName);
  }
  
  static Future<String?> getBackendFileUrl(String objectName, {int expiration = 3600}) async {
    return await BackendService.getFileUrl(objectName, expiration: expiration);
  }
  
  static Future<bool> deleteBackendFile(String objectName) async {
    final result = await BackendService.deleteFile(objectName);
    return result['success'] ?? false;
  }
  
  static Future<Map<String, dynamic>> getBackendBucketInfo() async {
    return await BackendService.getBucketInfo();
  }
  
  static void showBackendSnackbar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  static Future<bool> isBackendAvailable(BuildContext context) async {
    if (!Environment.enableBackendUpload) {
      showBackendSnackbar(context, 'Backend upload is disabled', isError: true);
      return false;
    }
    
    bool isConnected = await testBackendConnection();
    if (!isConnected) {
      showBackendSnackbar(
        context, 
        'Backend server not running. Please start the Python backend.', 
        isError: true
      );
      return false;
    }
    
    bool isAWSConnected = await testBackendAWSConnection();
    if (!isAWSConnected) {
      showBackendSnackbar(
        context, 
        'Backend AWS connection failed. Check AWS credentials.', 
        isError: true
      );
      return false;
    }
    
    return true;
  }
}
