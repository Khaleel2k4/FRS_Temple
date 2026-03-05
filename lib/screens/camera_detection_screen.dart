import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetectionActive = false;
  int _detectedFaces = 0;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: false,
      enableTracking: true,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      _showPermissionDialog();
      return;
    }

    // Get available cameras
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showNoCameraDialog();
        return;
      }

      // Use back camera for better face detection compatibility
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to initialize camera: $e');
    }
  }

  void _startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetectionActive = true;
    });

    // Use photo-based detection for better compatibility with delays
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isDetectionActive || _cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        // Add a small delay to prevent camera overload
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!_cameraController!.value.isInitialized) {
          debugPrint('Camera not initialized');
          return;
        }

        final image = await _cameraController!.takePicture();
        debugPrint('Picture taken: ${image.path}');
        
        final inputImage = InputImage.fromFilePath(image.path);
        debugPrint('InputImage created');
        
        try {
        final faces = await _faceDetector.processImage(inputImage);
        debugPrint('Faces detected: ${faces.length}');
        
        if (mounted) {
          setState(() {
            _detectedFaces = faces.length;
          });
        }
      } catch (e) {
        if (e.toString().contains('ImageFormat is not supported')) {
          debugPrint('Image format not supported, trying manual conversion...');
          await _tryManualImageConversion(image.path);
        } else {
          debugPrint('Face detection error: $e');
        }
      }

        // Delete the temporary image file
        try {
          final file = File(image.path);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Temporary file deleted');
          }
        } catch (e) {
          debugPrint('File deletion error: $e');
        }
      } catch (e) {
        debugPrint('Detection error: $e');
        
        // If camera error occurs, try to reinitialize
        if (e.toString().contains('channel-error')) {
          debugPrint('Camera channel error, attempting to reinitialize...');
          await _reinitializeCamera();
        }
      }
    });
  }

  Future<void> _tryManualImageConversion(String imagePath) async {
    try {
      debugPrint('Attempting manual image conversion...');
      
      // Read the image file
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      // Try to create InputImage from bytes directly
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(640, 480), // Default size, will be adjusted by ML Kit
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21, // Use NV21 format
          bytesPerRow: 640, // Default, will be adjusted
        ),
      );
      
      final faces = await _faceDetector.processImage(inputImage);
      debugPrint('Manual conversion - Faces detected: ${faces.length}');
      
      if (mounted) {
        setState(() {
          _detectedFaces = faces.length;
        });
      }
    } catch (e) {
      debugPrint('Manual conversion failed: $e');
      // As a last resort, try with a different camera
      await _tryDifferentCamera();
    }
  }

  Future<void> _tryDifferentCamera() async {
    try {
      debugPrint('Trying different camera...');
      
      // Dispose current controller
      await _cameraController?.dispose();
      _cameraController = null;
      
      // Reset state
      setState(() {
        _isCameraInitialized = false;
      });
      
      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      // Try front camera instead of back
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      
      debugPrint('Switched to front camera');
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
    }
  }

  Future<void> _reinitializeCameraWithDifferentFormat() async {
    try {
      debugPrint('Trying different camera format...');
      
      // Dispose current controller
      await _cameraController?.dispose();
      _cameraController = null;
      
      // Reset state
      setState(() {
        _isCameraInitialized = false;
      });
      
      // Wait a moment before reinitializing
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try with different format
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Try with YUV420 format
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.low, // Use low resolution for better compatibility
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      
      debugPrint('Camera reinitialized with YUV420 format');
    } catch (e) {
      debugPrint('Failed to reinitialize with different format: $e');
      // As a last resort, try without any format specification
      await _initializeCamera();
    }
  }

  Future<void> _reinitializeCamera() async {
    try {
      debugPrint('Reinitializing camera...');
      
      // Dispose current controller
      await _cameraController?.dispose();
      _cameraController = null;
      
      // Reset state
      setState(() {
        _isCameraInitialized = false;
      });
      
      // Wait a moment before reinitializing
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reinitialize camera
      await _initializeCamera();
      
      debugPrint('Camera reinitialized successfully');
    } catch (e) {
      debugPrint('Failed to reinitialize camera: $e');
    }
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    
    setState(() {
      _isDetectionActive = false;
      _detectedFaces = 0;
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to perform face detection. Please grant camera permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Camera Found'),
        content: const Text('No camera device was found on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live Face Detection',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 16,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.30),
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFD27D).withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD27D).withValues(alpha: 0.18),
                          blurRadius: 30,
                          spreadRadius: 0.8,
                        ),
                      ],
                    ),
                    child: _buildCameraPreview(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: _isDetectionActive ? 'Detection Active' : 'Start Detection',
                      icon: _isDetectionActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      onPressed: _isDetectionActive ? _stopDetection : _startDetection,
                      isActive: _isDetectionActive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetectionCountPill(
                countText: 'Faces Detected: $_detectedFaces',
                isActive: _isDetectionActive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_rounded, size: 74, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: CameraPreview(_cameraController!),
        ),
        if (_isDetectionActive)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 8),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [
                    Colors.red.shade400,
                    Colors.red.shade600,
                    Colors.red.shade800,
                  ]
                : [
                    const Color(0xFFFFE9A8),
                    const Color(0xFFFFB300),
                    const Color(0xFFFF8F00),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.red : const Color(0xFFFFD27D)).withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectionCountPill extends StatelessWidget {
  const _DetectionCountPill({
    required this.countText,
    this.isActive = false,
  });

  final String countText;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(
              color: (isActive ? Colors.red : const Color(0xFFFFD27D)).withValues(alpha: 0.40),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.face_rounded,
                  color: (isActive ? Colors.red : const Color(0xFFFFD27D)).withValues(alpha: 0.95),
                ),
                const SizedBox(width: 10),
                Text(
                  countText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
