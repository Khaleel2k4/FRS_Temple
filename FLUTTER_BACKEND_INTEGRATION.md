# Flutter Frontend + Python Backend Integration Guide

This guide shows how to integrate your Flutter frontend with the Python backend for AWS S3 operations.

## 🏗️ Architecture Overview

```
Flutter App (Frontend)
        ↓ HTTP API Calls
Python Flask Backend
        ↓ AWS SDK
AWS S3 Bucket
```

## 🔄 Integration Flow

### Option 1: Direct Flutter AWS Integration (Already Done)
- Flutter app directly connects to AWS S3
- Uses Amplify SDK
- Good for simple applications

### Option 2: Backend-Mediated Integration (Recommended)
- Flutter app calls Python backend API
- Backend handles AWS operations
- Better security, validation, and control

## 🚀 Setting Up Backend Integration

### 1. Start the Python Backend

```bash
cd backend
python run.py
```

Or on Windows:
```bash
cd backend
start.bat
```

The backend will be available at `http://localhost:5000`

### 2. Update Flutter Configuration

Create a new service file to handle backend communication:

```dart
// lib/services/backend_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  static const String baseUrl = 'http://localhost:5000';
  
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Backend connection failed: $e');
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
}
```

### 3. Add HTTP Dependency to Flutter

Add to `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
```

### 4. Create Backend Integration Helper

```dart
// lib/utils/backend_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class BackendHelper {
  static Future<bool> testBackendConnection() async {
    return await BackendService.testConnection();
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
  
  static Future<bool> deleteBackendFile(String objectName) async {
    final result = await BackendService.deleteFile(objectName);
    return result['success'] ?? false;
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
}
```

## 🎯 Usage Examples in Flutter

### Upload Image Using Backend

```dart
ElevatedButton(
  onPressed: () async {
    File? image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      // Test backend connection first
      bool isConnected = await BackendHelper.testBackendConnection();
      if (!isConnected) {
        BackendHelper.showBackendSnackbar(
          context, 
          'Backend server not running', 
          isError: true
        );
        return;
      }
      
      // Upload image
      String? url = await BackendHelper.uploadImageToBackend(
        File(image.path), 
        folder: 'flutter-uploads'
      );
      
      if (url != null) {
        BackendHelper.showBackendSnackbar(
          context, 
          'Image uploaded successfully via backend!'
        );
        // Use the URL as needed
      } else {
        BackendHelper.showBackendSnackbar(
          context, 
          'Upload failed', 
          isError: true
        );
      }
    }
  },
  child: Text('Upload via Backend'),
),
```

### List Files from Backend

```dart
FutureBuilder<List<Map<String, dynamic>>>(
  future: BackendHelper.getBackendFiles(prefix: 'flutter-uploads'),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    final files = snapshot.data ?? [];
    
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          title: Text(file['key']),
          subtitle: Text('${file['size']} bytes'),
          trailing: IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              bool success = await BackendHelper.deleteBackendFile(file['key']);
              if (success) {
                // Refresh the list
                setState(() {});
              }
            },
          ),
        );
      },
    );
  },
),
```

## 🔧 Configuration Options

### Backend Configuration

Edit `backend/.env`:

```env
# Change the port if needed
FLASK_PORT=8080

# Update CORS origins for your Flutter app
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

# Update bucket name
AWS_S3_BUCKET=your-actual-bucket-name
```

### Flutter Configuration

Update the base URL in `BackendService`:

```dart
static const String baseUrl = 'http://192.168.1.100:5000'; // Your server IP
```

## 🚀 Production Considerations

### Backend Security

1. **Authentication**: Add API keys or JWT tokens
2. **Rate Limiting**: Prevent abuse
3. **HTTPS**: Use SSL in production
4. **Input Validation**: Validate all inputs
5. **File Size Limits**: Configure appropriate limits

### Flutter Security

1. **SSL Pinning**: Secure API calls
2. **Error Handling**: Handle network errors gracefully
3. **User Feedback**: Show appropriate loading states

## 🐛 Troubleshooting

### Common Issues

1. **Connection Refused**
   - Backend not running
   - Wrong IP/port in Flutter
   - Firewall blocking connection

2. **CORS Errors**
   - Update CORS origins in backend
   - Check Flutter app origin

3. **Upload Failures**
   - Check file size limits
   - Verify AWS credentials
   - Check bucket permissions

### Debug Steps

1. **Test Backend**: Run `python test_client.py`
2. **Check Logs**: Review backend console output
3. **Network Debugging**: Use tools like Postman
4. **Flutter Logs**: Check debug console

## 📱 Testing the Integration

### Backend Test

```bash
cd backend
python test_client.py
```

### Flutter Test

Add this to your Flutter app:

```dart
// Test button
ElevatedButton(
  onPressed: () async {
    bool connected = await BackendHelper.testBackendConnection();
    print('Backend connected: $connected');
  },
  child: Text('Test Backend'),
),
```

## 🔄 Migration from Direct AWS

If you want to migrate from direct AWS to backend:

1. Replace `AWSHelper` calls with `BackendHelper`
2. Update error handling
3. Test all upload/download functionality
4. Update UI feedback messages

## 📚 Next Steps

1. **Authentication**: Add user authentication
2. **File Management**: Implement file organization
3. **Monitoring**: Add logging and monitoring
4. **Scaling**: Consider containerization
5. **Testing**: Write comprehensive tests

This integration provides a robust, secure, and scalable solution for your FRS Temple application!
