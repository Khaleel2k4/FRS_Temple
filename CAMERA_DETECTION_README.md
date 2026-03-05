# Camera Detection Sub-App

A dedicated Flutter sub-app for live camera face detection using Google ML Kit.

## Features

- **Live Camera Preview**: Real-time camera feed with front camera preference
- **Face Detection**: Powered by Google ML Kit for accurate face detection
- **Detection Counter**: Shows the number of faces detected in real-time
- **Start/Stop Controls**: Easy control over detection process
- **Permission Handling**: Automatic camera permission requests
- **Error Handling**: Graceful handling of camera and detection errors

## Files Created

- `lib/camera_detection_app.dart` - Main entry point for the camera detection sub-app
- `lib/screens/camera_detection_screen.dart` - Core camera detection functionality

## Dependencies Added

- `camera: ^0.10.5+5` - Camera functionality
- `google_ml_kit: ^0.16.0` - ML Kit for face detection
- `permission_handler: ^11.0.1` - Camera permission management

## How to Run

### Method 1: Direct Entry Point
```dart
// In your main.dart or any other file
import 'package:frs_temple/camera_detection_app.dart';

void main() {
  mainCameraDetection(); // This will launch the camera detection app
}
```

### Method 2: Navigation from Existing App
```dart
// Navigate from any screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const CameraDetectionScreen(),
  ),
);
```

## Usage

1. **Launch the App**: Start the camera detection sub-app
2. **Grant Permissions**: Allow camera access when prompted
3. **Start Detection**: Tap "Start Detection" to begin face detection
4. **View Results**: See real-time face count and live camera feed
5. **Stop Detection**: Tap the button again to stop detection

## Technical Details

### Face Detection Configuration
- **Performance Mode**: Fast (optimized for real-time detection)
- **Minimum Face Size**: 10% of image
- **Features Enabled**: Classification, Landmarks, Tracking
- **Detection Interval**: 500ms for optimal performance

### Camera Setup
- **Preferred Camera**: Front camera (falls back to any available camera)
- **Resolution**: High
- **Format**: YUV420 for optimal ML Kit processing
- **Audio**: Disabled for privacy

### Error Handling
- Camera permission denied
- No camera available
- Camera initialization failure
- Detection processing errors

## Permissions Required

- **Camera**: Required for accessing device camera
- **Storage**: Implicitly required for temporary image processing

## Platform Support

- **Android**: Fully supported
- **iOS**: Supported (requires camera usage description in Info.plist)

## Performance Considerations

- Detection runs every 500ms to balance accuracy and performance
- Temporary images are deleted after processing
- Memory-efficient implementation with proper disposal

## Future Enhancements

- Face recognition (not just detection)
- Multiple face tracking
- Detection confidence scores
- Export detection data
- Custom detection zones
