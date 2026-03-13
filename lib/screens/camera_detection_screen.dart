import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../services/backend_service.dart';
import '../utils/person_helper.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetectionActive = false;
  bool _isCapturing = false;
  bool _isProcessingCapture = false;
  int _detectedFaces = 0;
  File? _lastCapturedImage;
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
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('Initializing camera...');
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras found');
        if (mounted) {
          _showNoCameraDialog();
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      if (mounted) {
        _showErrorDialog('Failed to initialize camera: $e');
      }
    }
  }

  void _startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetectionActive = true;
    });

    _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isDetectionActive || _cameraController == null || _isProcessingCapture) {
        return;
      }

      try {
        setState(() {
          _isProcessingCapture = true;
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!_cameraController!.value.isInitialized) {
          debugPrint('Camera not initialized');
          setState(() {
            _isProcessingCapture = false;
          });
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

          debugPrint('Face detection complete: ${faces.length} faces detected');
          debugPrint('Is capturing: $_isCapturing, Is processing: $_isProcessingCapture');

          if (faces.isNotEmpty && !_isCapturing) {
            debugPrint('Triggering auto capture for ${faces.length} faces');
            await _autoCaptureAndStore(image, faces.length);
          } else {
            debugPrint('Not capturing - Faces: ${faces.isNotEmpty}, Capturing: $_isCapturing');
          }
        } catch (e) {
          if (e.toString().contains('ImageFormat is not supported')) {
            debugPrint('Image format not supported, trying manual conversion...');
            await _tryManualImageConversion(image.path);
          } else {
            debugPrint('Face detection error: $e');
          }
        } finally {
          try {
            final file = File(image.path);
            if (await file.exists()) {
              await file.delete();
              debugPrint('Temporary file deleted');
            }
          } catch (e) {
            debugPrint('File deletion error: $e');
          }
          
          setState(() {
            _isProcessingCapture = false;
          });
        }
      } catch (e) {
        debugPrint('Detection error: $e');
        
        setState(() {
          _isProcessingCapture = false;
        });
        
        if (e.toString().contains('channel-error')) {
          debugPrint('Camera channel error, attempting to reinitialize...');
          await _reinitializeCamera();
        }
      }
    });
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    
    setState(() {
      _isDetectionActive = false;
      _isProcessingCapture = false;
      _detectedFaces = 0;
    });
  }

  Future<void> _autoCaptureAndStore(XFile image, int faceCount) async {
    debugPrint('Auto capture called with faceCount: $faceCount');
    debugPrint('Current state - Capturing: $_isCapturing, Processing: $_isProcessingCapture');
    
    if (_isCapturing) {
      debugPrint('Auto capture blocked - already capturing');
      return;
    }
    
    debugPrint('Starting auto capture process');
    
    _detectionTimer?.cancel();
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final autoName = 'Person_${timestamp}_F$faceCount';
    
    debugPrint('Generated auto name: $autoName');
    
    await _captureAndStorePerson(image, autoName);
  }

  Future<void> _captureAndStorePerson(XFile image, String personName) async {
    debugPrint('Capture and store called for: $personName');
    
    setState(() {
      _isCapturing = true;
    });

    try {
      debugPrint('Converting XFile to File');
      final imageFile = File(image.path);
      
      debugPrint('Testing backend connection');
      bool isAvailable = await BackendService.testConnection();
      if (!isAvailable) {
        debugPrint('Backend server not available');
        if (mounted) {
          _showErrorDialog('Backend server not available');
        }
        return;
      }

      debugPrint('Starting person capture and store process');
      String? imageUrl;
      if (mounted) {
        imageUrl = await PersonHelper.captureAndStorePerson(
          imageFile: imageFile,
          personName: personName,
          context: context,
        );
      }

      debugPrint('Upload result: $imageUrl');
      
      if (imageUrl != null && mounted) {
        debugPrint('Showing success dialog');
        _showSuccessDialog('Person "$personName" captured and stored successfully in S3 bucket!');
        
        setState(() {
          _lastCapturedImage = imageFile;
        });
      }
    } catch (e) {
      debugPrint('Error in capture and store: $e');
      developer.log('Error capturing and storing person: $e');
      if (mounted) {
        _showErrorDialog('Failed to store person: ${e.toString()}');
      }
    } finally {
      debugPrint('Capture and store process completed');
      setState(() {
        _isCapturing = false;
      });
      
      if (_isDetectionActive) {
        debugPrint('Resuming detection');
        _startDetection();
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
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

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Camera'),
        content: const Text('No camera found on this device. Please ensure your device has a working camera.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _tryManualImageConversion(String imagePath) async {
    try {
      debugPrint('Attempting manual image conversion...');
      
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: const Size(640, 480),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 640,
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
    }
  }

  Future<void> _reinitializeCamera() async {
    try {
      debugPrint('Reinitializing camera...');
      
      await _cameraController?.dispose();
      _cameraController = null;
      
      setState(() {
        _isCameraInitialized = false;
        _isProcessingCapture = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _initializeCamera();
      
      debugPrint('Camera reinitialized successfully');
    } catch (e) {
      debugPrint('Failed to reinitialize camera: $e');
    }
  }

  Future<void> _tryDifferentCamera() async {
    try {
      debugPrint('Trying different camera...');
      
      await _cameraController?.dispose();
      _cameraController = null;
      
      setState(() {
        _isCameraInitialized = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final targetCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.length > 1 ? cameras[1] : cameras.first,
      );
      
      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.high,
        enableAudio: false,
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
      await _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF01A1A2),
      appBar: AppBar(
        title: const Text('Face Detection', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF424242),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF01A1A2),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildCameraPreview(),
                ),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF424242),
                                Color(0xFF6366F1),
                                Color(0xFF9333EA),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFD27D).withValues(alpha: 0.18),
                                blurRadius: 30,
                                spreadRadius: 0.8,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Face Detection Status',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.face_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$_detectedFaces faces detected',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _isDetectionActive ? _stopDetection : _startDetection,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isDetectionActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isDetectionActive ? 'Detection Active' : 'Start Detection',
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF424242),
                                Color(0xFF6366F1),
                                Color(0xFF9333EA),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFD27D).withValues(alpha: 0.28),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.face,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Faces Detected: $_detectedFaces',
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
                  ),
                ],
              ),
            ),
          ],
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
