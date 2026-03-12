import 'package:flutter/material.dart';
import 'screens/camera_detection_screen.dart';
import 'theme/app_theme.dart';

void mainCameraDetection() {
  runApp(const CameraDetectionApp());
}

class CameraDetectionApp extends StatelessWidget {
  const CameraDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Detection App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const CameraDetectionScreen(),
    );
  }
}
