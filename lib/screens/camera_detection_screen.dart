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

class _CameraDetectionScreenState extends State<CameraDetectionScreen>
    with TickerProviderStateMixin {
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
      minFaceSize: 0.05,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Timer? _detectionTimer;

  late final AnimationController _recBlinkController;
  late final AnimationController _creditMarqueeController;

  // Distance estimation constants (these may need calibration)
  static const double _knownFaceWidth = 14.0; // Average face width in cm
  static const double _focalLength =
      500.0; // Approximate focal length for mobile camera

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

    _recBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _creditMarqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _initializeCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _recBlinkController.dispose();
    _creditMarqueeController.dispose();
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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        // Auto-start detection for CCTV-like behavior with small delay
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted &&
              _cameraController != null &&
              _cameraController!.value.isInitialized) {
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
      if (!_isDetectionActive ||
          _cameraController == null ||
          _isProcessingCapture) {
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
        debugPrint('InputImage created from: ${image.path}');

        // Log image metadata for debugging
        final file = File(image.path);
        final fileSize = await file.length();
        debugPrint('Image file size: ${fileSize} bytes');

        try {
          final faces = await _faceDetector.processImage(inputImage);
          debugPrint('Faces detected: ${faces.length}');

          double? closestDistance;

          // Find the closest face
          for (final face in faces) {
            final distance = _estimateDistance(face);
            if (distance != double.infinity &&
                (closestDistance == null || distance < closestDistance)) {
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
          debugPrint(
            'Closest face distance: ${closestDistance?.toStringAsFixed(2)}m',
          );
          debugPrint(
            'Is capturing: $_isCapturing, Is processing: $_isProcessingCapture',
          );

          if (faces.isNotEmpty &&
              !_isCapturing &&
              closestDistance != null &&
              closestDistance <= 0.50) {
            debugPrint(
              'Triggering auto capture for closest face at ${closestDistance.toStringAsFixed(2)}m',
            );
            await _smartAutoCaptureAndStore(
              image,
              faces.length,
              closestDistance,
            );
          } else if (faces.isNotEmpty &&
              closestDistance != null &&
              closestDistance > 0.50) {
            debugPrint(
              'Face detected but too far: ${closestDistance.toStringAsFixed(2)}m > 0.50m',
            );
          } else {
            debugPrint(
              'Not capturing - Faces: ${faces.isNotEmpty}, Distance: ${closestDistance?.toStringAsFixed(2)}m, Capturing: $_isCapturing',
            );
          }
        } catch (e) {
          if (e.toString().contains('ImageFormat is not supported')) {
            debugPrint(
              'Image format not supported, trying manual conversion...',
            );
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

  Future<void> _smartAutoCaptureAndStore(
    XFile image,
    int faceCount,
    double distance,
  ) async {
    debugPrint(
      'Smart auto capture called with faceCount: $faceCount, distance: ${distance.toStringAsFixed(2)}m',
    );
    debugPrint(
      'Current state - Capturing: $_isCapturing, Processing: $_isProcessingCapture',
    );

    if (_isCapturing) {
      debugPrint('Smart auto capture blocked - already capturing');
      return;
    }

    debugPrint('Starting smart auto capture process');

    _detectionTimer?.cancel();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final autoName =
        'Person_${timestamp}_F${faceCount}_D${distance.toStringAsFixed(2)}m';

    debugPrint('Generated smart auto name: $autoName');

    await _smartCaptureAndStorePerson(image, autoName, distance);
  }

  Future<void> _smartCaptureAndStorePerson(
    XFile image,
    String personName,
    double distance,
  ) async {
    debugPrint(
      'Smart capture and store called for: $personName at ${distance.toStringAsFixed(2)}m',
    );

    setState(() {
      _isCapturing = true;
    });

    try {
      debugPrint('Converting XFile to File');
      final imageFile = File(image.path);

      debugPrint('Testing backend connection');
      bool isAvailable = await BackendService.testConnection();
      if (!isAvailable) {
        debugPrint(
          'Backend server not available - Check network connection and server status',
        );
        debugPrint('Backend URL: ${Environment.backendBaseUrl}');
        if (mounted) {
          _showErrorDialog(
            'Backend server not available. Please check:\n1. Backend server is running\n2. Network connection to 10.16.74.126:5000\n3. Firewall settings',
          );
        }
        return;
      }

      debugPrint('Starting smart person capture and store process');
      Map<String, dynamic>? result;
      if (mounted) {
        result = await PersonHelper.smartCaptureAndStorePerson(
          imageFile: imageFile,
          personName: personName,
          context: context,
          estimatedDistance: distance,
        );
      }

      debugPrint('Smart capture result: $result');

      if (result != null && result['success'] == true && mounted) {
        debugPrint('Showing success dialog');
        _showSuccessDialog(
          'Person "$personName" captured successfully at ${distance.toStringAsFixed(2)}m!',
        );

        debugPrint('Entry type: ${result['entry_type']}');
        debugPrint('Re-entry count from result: ${result['re_entry_count']}');
        debugPrint('Current re-entry count before update: $_reEntryCount');

        // Update re-entry count if this was a re-entry
        if (result['entry_type'] == 're_entry') {
          final newCount = result['re_entry_count'] ?? _reEntryCount + 1;
          debugPrint('Setting re-entry count to: $newCount');
          setState(() {
            _reEntryCount = newCount;
          });
          debugPrint('Re-entry count after update: $_reEntryCount');
        } else {
          debugPrint('Not a re-entry, keeping current count: $_reEntryCount');
        }
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
    final formattedResults = NetworkDiagnostics.formatDiagnosticsResults(
      results,
    );

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
        content: const Text(
          'No camera found on this device. Please ensure your device has a working camera.',
        ),
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
    return Scaffold(backgroundColor: Colors.black, body: _buildCameraPreview());
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
                color: Colors.red.withValues(alpha: 0.22),
                width: 1.5,
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
                top: BorderSide(color: Colors.red, width: 2),
                left: BorderSide(color: Colors.red, width: 2),
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
                top: BorderSide(color: Colors.red, width: 2),
                right: BorderSide(color: Colors.red, width: 2),
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
                bottom: BorderSide(color: Colors.red, width: 2),
                left: BorderSide(color: Colors.red, width: 2),
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
                bottom: BorderSide(color: Colors.red, width: 2),
                right: BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),

        // Top overlay (REC + Timestamp)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildRecIndicator(), _buildTimestamp()],
              ),
            ),
          ),
        ),

        // Center-bottom system alert badge
        if (_estimatedDistance != null && _estimatedDistance! > 0.50)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'OUT OF RANGE (>0.50m)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Bottom status bar (Faces + Monitoring)
        Positioned(
          left: 0,
          right: 0,
          bottom: 44,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(
                    label: 'Faces: $_detectedFaces',
                    color: Colors.orange.withValues(alpha: 0.85),
                  ),
                  _buildStatusBadge(
                    label: _isDetectionActive ? 'MONITORING' : 'STANDBY',
                    color: _isDetectionActive
                        ? Colors.green.withValues(alpha: 0.85)
                        : Colors.grey.withValues(alpha: 0.70),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Re-entry counter on the right side
        if (_reEntryCount > 0)
          Positioned(
            bottom: 80,
            right: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Re-entries: $_reEntryCount',
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

        // Developer credit footer
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDeveloperCreditFooter(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.25, end: 1.0).animate(
              CurvedAnimation(
                parent: _recBlinkController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDeveloperCreditFooter() {
    const text =
        'Developed by Sri Varahi IT Solutions, Rajahmundry – 533101    Contact: 8688535933';

    return Container(
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: const TextSpan(
                text: text,
                style: TextStyle(
                  color: Color(0xFFF8E7A1),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();

            final textWidth = painter.width;
            final travel = constraints.maxWidth + textWidth + 24;

            return AnimatedBuilder(
              animation: _creditMarqueeController,
              builder: (context, child) {
                final dx =
                    constraints.maxWidth -
                    (travel * _creditMarqueeController.value);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: const TextStyle(
                      color: Color(0xFFF8E7A1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
