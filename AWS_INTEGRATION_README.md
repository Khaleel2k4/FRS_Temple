# AWS Integration Guide - Backend Architecture

This document explains how AWS services are integrated into the FRS Temple application using a Python backend architecture.

## 🏗️ Architecture Overview

```
Flutter App (Frontend)
        ↓ HTTP API Calls
Python Flask Backend
        ↓ AWS SDK
AWS S3 Bucket
```

## ✅ What's Been Configured:

### Frontend (Flutter)
- **Backend Service**: HTTP client for API communication
- **Backend Helper**: Utility functions for UI integration
- **Environment Config**: Backend URL and feature flags
- **Upload Widget**: Example implementation

### Backend (Python)
- **Flask API**: RESTful endpoints for file operations
- **AWS S3 Service**: Direct AWS SDK integration
- **File Validation**: Type checking and size limits
- **Error Handling**: Comprehensive error management

## 🔑 AWS Credentials

Your AWS credentials are now managed in the Python backend:
- **Access Key ID**: `AKIAU57EX2DOESZKU6J6`
- **Region**: `us-east-1`
- **Secret Key**: Configured in backend `.env` file

## 📁 Project Structure

### Flutter Frontend
```
lib/
├── config/
│   └── environment.dart          # Backend configuration
├── services/
│   └── backend_service.dart     # HTTP API client
├── utils/
│   └── backend_helper.dart      # UI helper functions
├── widgets/
│   └── backend_upload_widget.dart # Example UI component
└── main.dart                     # Clean initialization
```

### Python Backend
```
backend/
├── app.py                 # Flask API server
├── aws_s3_service.py      # AWS S3 operations
├── run.py                 # Startup script
├── start.bat              # Windows batch file
├── test_client.py         # API testing client
├── requirements.txt       # Python dependencies
└── .env                   # Environment configuration
```

## 🛠️ How to Use Backend Services

### 1. Test Backend Connection
```dart
import 'package:frs_temple/utils/backend_helper.dart';

bool isConnected = await BackendHelper.testBackendConnection();
bool isAWSConnected = await BackendHelper.testBackendAWSConnection();
```

### 2. Upload File/Image
```dart
import 'package:frs_temple/utils/backend_helper.dart';

// Upload image
File imageFile = File('path/to/image.jpg');
String? url = await BackendHelper.uploadImageToBackend(
  imageFile, 
  folder: 'flutter-uploads'
);

// Upload any file
File dataFile = File('path/to/file.txt');
String? fileUrl = await BackendHelper.uploadFileToBackend(dataFile);
```

### 3. Manage Files
```dart
// List files
List<Map<String, dynamic>> files = await BackendHelper.getBackendFiles(
  prefix: 'flutter-uploads'
);

// Get file info
Map<String, dynamic>? fileInfo = await BackendHelper.getBackendFileInfo('file-key');

// Get download URL
String? downloadUrl = await BackendHelper.getBackendFileUrl('file-key');

// Delete file
bool success = await BackendHelper.deleteBackendFile('file-key');
```

### 4. UI Integration
```dart
// Check backend availability
bool isAvailable = await BackendHelper.isBackendAvailable(context);
if (isAvailable) {
  // Proceed with operations
}

// Show feedback
BackendHelper.showBackendSnackbar(
  context, 
  'Upload successful!', 
  isError: false
);
```

## 🚀 Quick Start

### 1. Start the Backend
```bash
cd backend
python run.py
# or on Windows: start.bat
```

### 2. Run Flutter App
```bash
flutter run
```

### 3. Test Integration
Use the `BackendUploadWidget` or create your own UI components.

## 📡 Backend API Endpoints

### Health & Connection
- `GET /health` - Health check
- `GET /api/aws/test-connection` - Test AWS S3 connection
- `GET /api/bucket/info` - Get bucket information

### File Operations
- `POST /api/upload/file` - Upload any file
- `POST /api/upload/image` - Upload image with validation
- `GET /api/files/list` - List files with prefix filter
- `GET /api/files/<object_name>/info` - Get file metadata
- `GET /api/files/<object_name>/url` - Get presigned download URL
- `DELETE /api/files/<object_name>` - Delete file

## ⚙️ Configuration

### Backend Configuration
Edit `backend/.env`:
```env
# AWS Configuration
AWS_ACCESS_KEY_ID=AKIAU57EX2DOESZKU6J6
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-bucket-name

# Flask Configuration
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=True

# CORS Configuration
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

### Flutter Configuration
Edit `lib/config/environment.dart`:
```dart
class Environment {
  static const String backendBaseUrl = 'http://localhost:5000';
  static const bool enableBackendUpload = true;
  // ... other settings
}
```

## 🔧 Required AWS Setup

### 1. Create S3 Bucket
- Navigate to AWS S3 console
- Create a bucket with your desired name
- Update `AWS_S3_BUCKET` in backend `.env`

### 2. IAM Permissions
Your AWS user needs:
- `s3:PutObject` - Upload files
- `s3:GetObject` - Download files
- `s3:DeleteObject` - Delete files
- `s3:ListBucket` - List files
- `s3:GetObjectMetadata` - Get file info

### 3. CORS Configuration (Optional)
Add CORS configuration to your S3 bucket if needed for direct access.

## 🚨 Security Notes

✅ **Improved Security**:
- AWS credentials are now only in the backend
- Frontend never exposes AWS keys
- Backend validates all inputs
- File type and size restrictions

⚠️ **Production Considerations**:
- Use HTTPS in production
- Add authentication to backend
- Implement rate limiting
- Use environment-specific configurations

## 📱 Example Usage

### Complete Upload Flow
```dart
class MyUploadScreen extends StatefulWidget {
  @override
  _MyUploadScreenState createState() => _MyUploadScreenState();
}

class _MyUploadScreenState extends State<MyUploadScreen> {
  Future<void> _uploadAndManage() async {
    // 1. Check backend availability
    bool isAvailable = await BackendHelper.isBackendAvailable(context);
    if (!isAvailable) return;

    // 2. Pick image
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    // 3. Upload via backend
    String? url = await BackendHelper.uploadImageToBackend(
      File(image.path),
      folder: 'my-uploads'
    );

    // 4. Handle result
    if (url != null) {
      BackendHelper.showBackendSnackbar(context, 'Upload successful!');
      // Use the URL as needed
    } else {
      BackendHelper.showBackendSnackbar(context, 'Upload failed!', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Backend Upload')),
      body: Center(
        child: ElevatedButton(
          onPressed: _uploadAndManage,
          child: Text('Upload Image'),
        ),
      ),
    );
  }
}
```

## � Testing

### Backend Testing
```bash
cd backend
python test_client.py
```

### Flutter Testing
Add test buttons to your app or use the provided `BackendUploadWidget`.

## 📚 Benefits of Backend Architecture

1. **Security**: AWS credentials never exposed in frontend
2. **Validation**: Backend validates all inputs and files
3. **Control**: Centralized file management
4. **Scalability**: Easy to add features like authentication
5. **Monitoring**: Centralized logging and error tracking
6. **Flexibility**: Can switch cloud providers without frontend changes

## 🔄 Migration from Direct AWS

If migrating from direct AWS integration:
1. Replace `AWSHelper` calls with `BackendHelper`
2. Update import statements
3. Test all upload/download functionality
4. Update error handling
5. Remove old AWS dependencies (already done)

For more details, see `FLUTTER_BACKEND_INTEGRATION.md`.
