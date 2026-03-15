import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/person_service.dart';

class PersonHelper {
  static Future<bool> addPersonToDatabase({
    required String personName,
    required String imageUrl,
    String? s3Key,
    double? faceConfidence,
    BuildContext? context,
  }) async {
    try {
      final result = await PersonService.addPerson(
        personName: personName,
        imageUrl: imageUrl,
        s3Key: s3Key,
        faceConfidence: faceConfidence,
      );
      
      if (result['success']) {
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Person "$personName" added successfully to database and S3!',
            false,
          );
        }
        return true;
      } else {
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            result['error'] ?? 'Failed to add person',
            true,
          );
        }
        return false;
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showPersonSnackbar(
          context,
          'Error: ${e.toString()}',
          true,
        );
      }
      return false;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAllPersons({
    String? personName,
    int limit = 100,
  }) async {
    try {
      final result = await PersonService.getPersons(
        personName: personName,
        limit: limit,
      );
      
      if (result['success']) {
        return List<Map<String, dynamic>>.from(result['persons']);
      }
      return [];
    } catch (e) {
      developer.log('Error getting persons: $e');
      return [];
    }
  }
  
  static Future<List<String>> getUniquePersons() async {
    try {
      final result = await PersonService.getUniquePersons();
      
      if (result['success']) {
        return List<String>.from(result['persons']);
      }
      return [];
    } catch (e) {
      developer.log('Error getting unique persons: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getRecentCaptures({
    int hours = 24,
  }) async {
    try {
      final result = await PersonService.getRecentCaptures(hours: hours);
      
      if (result['success']) {
        return List<Map<String, dynamic>>.from(result['persons']);
      }
      return [];
    } catch (e) {
      developer.log('Error getting recent captures: $e');
      return [];
    }
  }
  
  static Future<bool> deletePersonEntry(int entryId, {BuildContext? context}) async {
    try {
      final result = await PersonService.deletePersonEntry(entryId);
      
      if (result['success']) {
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Person entry deleted successfully',
            false,
          );
        }
        return true;
      } else {
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            result['error'] ?? 'Failed to delete person entry',
            true,
          );
        }
        return false;
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showPersonSnackbar(
          context,
          'Error: ${e.toString()}',
          true,
        );
      }
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> getPersonStats() async {
    try {
      final result = await PersonService.getPersonStats();
      
      if (result['success']) {
        return result['stats'];
      }
      return null;
    } catch (e) {
      developer.log('Error getting person stats: $e');
      return null;
    }
  }
  
  static Future<String?> smartCaptureAndStorePerson({
    required File imageFile,
    required String personName,
    double? faceConfidence,
    double? estimatedDistance,
    BuildContext? context,
  }) async {
    try {
      developer.log('Starting smart capture process for: $personName');
      developer.log('Estimated distance: ${estimatedDistance ?? "unknown"} meters');
      
      // Check if person is within 0.50 meters range
      if (estimatedDistance != null && estimatedDistance > 0.50) {
        developer.log('Person too far: ${estimatedDistance}m > 0.50m threshold');
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Person too far from camera (${estimatedDistance.toStringAsFixed(2)}m). Please move closer.',
            true,
          );
        }
        return null;
      }
      
      // Upload image to backend first
      final uploadResult = await BackendService.uploadImage(
        imageFile,
        folder: 'person-captures',
      );
      
      developer.log('Upload result: $uploadResult');
      
      if (!uploadResult['success']) {
        developer.log('Upload failed: ${uploadResult['error']}');
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Failed to upload image: ${uploadResult['error']}',
            true,
          );
        }
        return null;
      }
      
      developer.log('Image uploaded successfully to: ${uploadResult['file_url']}');
      
      // Check if person exists in pass_in table for today
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Check if person exists in database
      final existsResult = await PersonService.checkPersonExists(personName);
      
      if (!existsResult['success']) {
        developer.log('Failed to check person existence: ${existsResult['error']}');
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Failed to verify person: ${existsResult['error']}',
            true,
          );
        }
        return null;
      }
      
      bool personExistsToday = existsResult['exists'] ?? false;
      String? imageUrl;
      String entryType = '';
      
      if (personExistsToday) {
        // Person exists, add to pass_out (re-entry)
        developer.log('Person exists today, adding to pass_out (re-entry)');
        final passOutResult = await PersonService.addPassOutEntry(
          personName: personName,
          imageUrl: uploadResult['file_url'],
          s3Key: uploadResult['object_name'],
          faceConfidence: faceConfidence,
        );
        
        if (passOutResult['success']) {
          imageUrl = uploadResult['file_url'];
          entryType = 're-entry';
          final reEntryCount = passOutResult['re_entry_count'] ?? 1;
          
          developer.log('Pass-out entry added successfully. Re-entry count: $reEntryCount');
          
          if (context != null && context.mounted) {
            _showPersonSnackbar(
              context,
              'Re-entry recorded for "$personName" (Count: $reEntryCount)',
              false,
            );
          }
        } else {
          developer.log('Failed to add pass-out entry: ${passOutResult['error']}');
          if (context != null && context.mounted) {
            _showPersonSnackbar(
              context,
              'Failed to record re-entry: ${passOutResult['error']}',
              true,
            );
          }
          return null;
        }
      } else {
        // First time today, add to pass_in
        developer.log('First time today, adding to pass_in');
        final passInResult = await PersonService.addPassInEntry(
          personName: personName,
          imageUrl: uploadResult['file_url'],
          s3Key: uploadResult['object_name'],
          faceConfidence: faceConfidence,
        );
        
        if (passInResult['success']) {
          imageUrl = uploadResult['file_url'];
          entryType = 'pass-in';
          
          developer.log('Pass-in entry added successfully');
          
          if (context != null && context.mounted) {
            _showPersonSnackbar(
              context,
              'First-time entry recorded for "$personName"',
              false,
            );
          }
        } else {
          developer.log('Failed to add pass-in entry: ${passInResult['error']}');
          if (context != null && context.mounted) {
            _showPersonSnackbar(
              context,
              'Failed to record entry: ${passInResult['error']}',
              true,
            );
          }
          return null;
        }
      }
      
      if (imageUrl != null) {
        developer.log('Smart capture completed successfully for $personName ($entryType)');
        return imageUrl;
      }
      
      return null;
    } catch (e) {
      developer.log('Error in smartCaptureAndStorePerson: $e');
      if (context != null && context.mounted) {
        _showPersonSnackbar(
          context,
          'Error: ${e.toString()}',
          true,
        );
      }
      return null;
    }
  }

  static Future<String?> captureAndStorePerson({
    required File imageFile,
    required String personName,
    double? faceConfidence,
    BuildContext? context,
  }) async {
    try {
      developer.log('Starting capture and store process for: $personName');
      
      // First upload image to backend
      final uploadResult = await BackendService.uploadImage(
        imageFile,
        folder: 'person-captures',
      );
      
      developer.log('Upload result: $uploadResult');
      
      if (!uploadResult['success']) {
        developer.log('Upload failed: ${uploadResult['error']}');
        if (context != null && context.mounted) {
          _showPersonSnackbar(
            context,
            'Failed to upload image: ${uploadResult['error']}',
            true,
          );
        }
        return null;
      }
      
      developer.log('Image uploaded successfully to: ${uploadResult['file_url']}');
      
      // Then add person to database
      bool added = await addPersonToDatabase(
        personName: personName,
        imageUrl: uploadResult['file_url'],
        s3Key: uploadResult['object_name'],
        faceConfidence: faceConfidence,
        context: context,
      );
      
      if (added) {
        developer.log('Person successfully added to database');
        return uploadResult['file_url'];
      }
      return null;
    } catch (e) {
      developer.log('Error in captureAndStorePerson: $e');
      if (context != null && context.mounted) {
        _showPersonSnackbar(
          context,
          'Error: ${e.toString()}',
          true,
        );
      }
      return null;
    }
  }
  
  static void _showPersonSnackbar(
    BuildContext context,
    String message,
    bool isError,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        action: isError ? null : SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to person list or details - only if context is still valid
            if (context.mounted) {
              // Navigation logic here
            }
          },
        ),
      ),
    );
  }
  
  static String formatCaptureTime(String captureTime) {
    try {
      final dateTime = DateTime.parse(captureTime);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return captureTime;
    }
  }
  
  static String getConfidenceColor(double? confidence) {
    if (confidence == null) return 'Grey';
    
    if (confidence >= 0.9) return 'Green';
    if (confidence >= 0.7) return 'Yellow';
    return 'Red';
  }
  
  static String getPersonInitials(String personName) {
    final parts = personName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return personName.isNotEmpty ? personName[0].toUpperCase() : '?';
  }
}
