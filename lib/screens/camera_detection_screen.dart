import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../services/backend_service.dart';
import '../utils/person_helper.dart';
import '../config/environment.dart';
import '../utils/network_diagnostics.dart';

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
  double? _estimatedDistance;
  int _reEntryCount = 0;
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

  // Distance estimation constants (these may need calibration)
  static const double _knownFaceWidth = 14.0; // Average face width in cm
  static const double _focalLength = 500.0; // Approximate focal length for mobile camera

  double _estimateDistance(Face face) {
    try {
      // Get face bounding box width in pixels
      final faceWidth = face.boundingBox.width;
      
      // Simple distance estimation formula
      // Distance = (Known Width * Focal Length) / Perceived Width
      final distance = (_knownFaceWidth * _focalLength) / faceWidth;
      
      // Convert to meters and add some calibration factor
      final calibratedDistance = (distance / 100) * 0.8; // Calibration factor
      
      return calibratedDistance;
    } catch (e) {
      developer.log('Error estimating distance: $e');
      return double.infinity; // Return infinity instead of null
    }
  }

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
        // Auto-start detection for CCTV-like behavior with small delay
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _cameraController != null && _cameraController!.value.isInitialized) {
            _startDetection();
          }
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
          
          double? closestDistance;
          
          // Find the closest face
          for (final face in faces) {
            final distance = _estimateDistance(face);
            if (distance != double.infinity && (closestDistance == null || distance < closestDistance)) {
              closestDistance = distance;
            }
          }
          
          if (mounted) {
            setState(() {
              _detectedFaces = faces.length;
              _estimatedDistance = closestDistance;
            });
          }

          debugPrint('Face detection complete: ${faces.length} faces detected');
          debugPrint('Closest face distance: ${closestDistance?.toStringAsFixed(2)}m');
          debugPrint('Is capturing: $_isCapturing, Is processing: $_isProcessingCapture');

          if (faces.isNotEmpty && !_isCapturing && closestDistance != null && closestDistance <= 0.50) {
            debugPrint('Triggering auto capture for closest face at ${closestDistance.toStringAsFixed(2)}m');
            await _smartAutoCaptureAndStore(image, faces.length, closestDistance);
          } else if (faces.isNotEmpty && closestDistance != null && closestDistance > 0.50) {
            debugPrint('Face detected but too far: ${closestDistance.toStringAsFixed(2)}m > 0.50m');
          } else {
            debugPrint('Not capturing - Faces: ${faces.isNotEmpty}, Distance: ${closestDistance?.toStringAsFixed(2)}m, Capturing: $_isCapturing');
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

  Future<void> _smartAutoCaptureAndStore(XFile image, int faceCount, double distance) async {
    debugPrint('Smart auto capture called with faceCount: $faceCount, distance: ${distance.toStringAsFixed(2)}m');
    debugPrint('Current state - Capturing: $_isCapturing, Processing: $_isProcessingCapture');
    
    if (_isCapturing) {
      debugPrint('Smart auto capture blocked - already capturing');
      return;
    }
    
    debugPrint('Starting smart auto capture process');
    
    _detectionTimer?.cancel();
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final autoName = 'Person_${timestamp}_F${faceCount}_D${distance.toStringAsFixed(2)}m';
    
    debugPrint('Generated smart auto name: $autoName');
    
    await _smartCaptureAndStorePerson(image, autoName, distance);
  }

  Future<void> _smartCaptureAndStorePerson(XFile image, String personName, double distance) async {
    debugPrint('Smart capture and store called for: $personName at ${distance.toStringAsFixed(2)}m');
    
    setState(() {
      _isCapturing = true;
    });

    try {
      debugPrint('Converting XFile to File');
      final imageFile = File(image.path);
      
      debugPrint('Testing backend connection');
      bool isAvailable = await BackendService.testConnection();
      if (!isAvailable) {
        debugPrint('Backend server not available - Check network connection and server status');
        debugPrint('Backend URL: ${Environment.backendBaseUrl}');
        if (mounted) {
          _showErrorDialog('Backend server not available. Please check:\n1. Backend server is running\n2. Network connection to 10.16.74.126:5000\n3. Firewall settings');
        }
        return;
      }

      debugPrint('Starting smart person capture and store process');
      String? imageUrl;
      if (mounted) {
        imageUrl = await PersonHelper.smartCaptureAndStorePerson(
          imageFile: imageFile,
          personName: personName,
          context: context,
          estimatedDistance: distance,
        );
      }

      debugPrint('Smart upload result: $imageUrl');
      
      if (imageUrl != null && mounted) {
        debugPrint('Showing success dialog');
        _showSuccessDialog('Person "$personName" captured successfully at ${distance.toStringAsFixed(2)}m!');
      }
    } catch (e) {
      debugPrint('Error in smart capture and store: $e');
      developer.log('Error smart capturing and storing person: $e');
      if (mounted) {
        _showErrorDialog('Failed to store person: ${e.toString()}');
      }
    } finally {
      debugPrint('Smart capture and store process completed');
      setState(() {
        _isCapturing = false;
      });
      
      if (_isDetectionActive) {
        debugPrint('Resuming detection');
        _startDetection();
      }
    }
  }

  Future<void> _runNetworkDiagnostics() async {
    debugPrint('Running network diagnostics...');
    
    final results = await NetworkDiagnostics.runFullDiagnostics();
    final formattedResults = NetworkDiagnostics.formatDiagnosticsResults(results);
    
    debugPrint(formattedResults);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Diagnostics'),
          content: SingleChildScrollView(
            child: Text(
              formattedResults,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCameraPreview(),
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
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        
        // CCTV overlay elements
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
        ),
        
        // Corner brackets
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.red, width: 3),
                left: BorderSide(color: Colors.red, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.red, width: 3),
                right: BorderSide(color: Colors.red, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.red, width: 3),
                left: BorderSide(color: Colors.red, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.red, width: 3),
                right: BorderSide(color: Colors.red, width: 3),
              ),
            ),
          ),
        ),
        
        // Recording indicator
        Positioned(
          top: 30,
          left: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 8),
                Text(
                  'REC',
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
        
        // Timestamp
        Positioned(
          top: 30,
          right: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final now = DateTime.now();
                return Text(
                  now.toString().substring(0, 19),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ),
        ),
        
        // Face detection indicator
        if (_isDetectionActive)
          Positioned(
            bottom: 30,
            left: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _estimatedDistance != null && _estimatedDistance! <= 0.50
                    ? Colors.green.withValues(alpha: 0.8)
                    : Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Faces: $_detectedFaces',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (_estimatedDistance != null)
                    Text(
                      'Distance: ${_estimatedDistance!.toStringAsFixed(2)}m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  if (_reEntryCount > 0)
                    Text(
                      'Re-entries: $_reEntryCount',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        
        // Distance range indicator
        Positioned(
          bottom: 80,
          left: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _estimatedDistance != null && _estimatedDistance! <= 0.50
                  ? Colors.green.withValues(alpha: 0.9)
                  : Colors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _estimatedDistance != null && _estimatedDistance! <= 0.50
                      ? Icons.check_circle
                      : Icons.warning,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _estimatedDistance != null && _estimatedDistance! <= 0.50
                      ? 'IN RANGE (≤0.50m)'
                      : 'OUT OF RANGE (>0.50m)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Re-entry counter indicator (separate display)
        if (_reEntryCount > 0)
          Positioned(
            top: 80,
            left: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Re-entries Today: $_reEntryCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Status indicator
        Positioned(
          bottom: 30,
          right: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isDetectionActive ? 
                Colors.green.withValues(alpha: 0.8) : 
                Colors.orange.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _isDetectionActive ? 'MONITORING' : 'STANDBY',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        
        // Network diagnostics button
        Positioned(
          top: 80,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: _runNetworkDiagnostics,
              icon: const Icon(Icons.network_check, color: Colors.white, size: 20),
              tooltip: 'Run Network Diagnostics',
            ),
          ),
        ),
      ],
    );
  }
}
