import 'dart:io';
import 'dart:async';
import 'package:bubblesheet_frontend/services/answer_key_cache_service.dart';
import 'package:bubblesheet_frontend/services/scanning_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/models/answer_sheet_model.dart';
import 'package:bubblesheet_frontend/models/scanning_result.dart';
import 'package:bubblesheet_frontend/providers/scanning_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/mobile/scanning_result_screen.dart';
import 'package:bubblesheet_frontend/services/aruco_detector_service.dart';
import 'package:bubblesheet_frontend/widgets/scan_result_overlay.dart';

class ScanningScreen extends StatefulWidget {
  final ExamModel quiz;
  final AnswerSheet answerSheet;

  const ScanningScreen({
    Key? key,
    required this.quiz,
    required this.answerSheet,
  }) : super(key: key);

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isReady = false;
  bool _isPreviewChecking = false;
  Timer? _previewTimer;
  List<Map<String, dynamic>> _normMarkers = const [];
  File? _capturedImage;
  DateTime? _lastCaptureTime;

  static const Duration _captureDebounceDuration = Duration(seconds: 2);

  int _scannedCount = 0;

  bool _showResultOverlay = false;
  ScanningResult? _lastScanResult;
  File? _lastScannedImage;

  @override
  void initState() {
    super.initState();
    _isReady = false;
    _normMarkers = [];
    _isProcessing = false;
    _isPreviewChecking = false;
    _hasResetAfterReturn = false;
    _scannedCount = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scanningProvider = Provider.of<ScanningProvider>(
        context,
        listen: false,
      );
      scanningProvider.clearResults();

      _preloadTemplate();
    });

    _initializeCamera();
  }

  Future<void> _preloadTemplate() async {
    final scanningProvider = Provider.of<ScanningProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      // Load template
      await scanningProvider.loadTemplate(
        answersheetId: widget.answerSheet.id,
        token: token,
      );
      try {
        final answerKey = await ScanningService.getAnswerKey(
          quizId: widget.quiz.id,
          token: token,
        );
        if (answerKey != null) {
          await AnswerKeyCacheService.cacheAnswerKey(widget.quiz.id, answerKey);
          print('[Sync] Answer key updated for quiz: ${widget.quiz.id}');
        }
      } catch (e) {
        print('[Sync] Cannot fetch answer key, using cache: $e');
      }
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await ArucoDetectorService.playShutterSound();
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  void _showSettingsDialog() {
    final scanningProvider = Provider.of<ScanningProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Settings'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Continuous Mode'),
                  subtitle: const Text(
                    'Scan multiple papers without viewing results',
                  ),
                  value: scanningProvider.isContinuousMode,
                  onChanged: (value) {
                    scanningProvider.setScanMode(value);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('Scanned: $_scannedCount papers'),
                  subtitle: Text('Quiz: ${widget.quiz.name}'),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        _showErrorDialog('Camera permission is required');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showErrorDialog('No cameras found');
        return;
      }

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        _isReady = false;
        _normMarkers = [];
      });
      _startPreviewCheckLoop();
    } catch (e) {
      _showErrorDialog('Error initializing camera: $e');
    }
  }

  void _startPreviewCheckLoop() {
    _previewTimer?.cancel();

    if (mounted) {
      setState(() {
        _isReady = false;
        _normMarkers = [];
      });
    }

    _previewTimer = Timer.periodic(const Duration(milliseconds: 300), (
      _,
    ) async {
      if (!mounted || _controller == null || !_controller!.value.isInitialized)
        return;
      if (_isProcessing || _isPreviewChecking) return;

      if (!_controller!.value.isTakingPicture) {
        _isPreviewChecking = true;
        try {
          final XFile shot = await _controller!.takePicture();
          final file = File(shot.path);
          final previewResult = await ArucoDetectorService.detectMarkers(
            file.path,
          );
          debugPrint('Preview result: $previewResult');
          if (previewResult == null) {
            try {
              await file.delete();
            } catch (_) {}
            return;
          }

          if (mounted && previewResult != null) {
            final result = previewResult!;
            final isReady = result['ready'] ?? false;
            final markers = List<Map<String, dynamic>>.from(
              result['markersNorm'] ?? [],
            );

            debugPrint(
              'Flutter: isReady=$isReady, markers.length=${markers.length}, _isProcessing=$_isProcessing',
            );

            setState(() {
              _isReady = isReady;
              _normMarkers = markers;
            });

            if (isReady && !_isProcessing) {
              debugPrint('Flutter: Ready to capture! Checking debounce...');
              final now = DateTime.now();
              final timeSinceLastCapture = _lastCaptureTime != null
                  ? now.difference(_lastCaptureTime!)
                  : null;
              debugPrint(
                'Flutter: timeSinceLastCapture=$timeSinceLastCapture, debounce=$_captureDebounceDuration',
              );

              if (_lastCaptureTime == null ||
                  now.difference(_lastCaptureTime!) >
                      _captureDebounceDuration) {
                _lastCaptureTime = now;
                debugPrint('Flutter: Debounce passed! Starting capture...');
                try {
                  await ArucoDetectorService.playShutterSound();
                } catch (e) {
                  debugPrint('Error playing shutter sound: $e');
                }

                _previewTimer?.cancel();
                await Future.delayed(const Duration(milliseconds: 30));
                _processImage(file.path);
                return;
              }
            }
          }
          try {
            await file.delete();
          } catch (_) {}
        } catch (e, stackTrace) {
          debugPrint('Preview check error: $e');
          debugPrint('Stack trace: $stackTrace');
        } finally {
          if (mounted) {
            _isPreviewChecking = false;
          }
        }
      }
    });
  }

  Future<void> _takePicture() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        !_isReady) {
      return;
    }
    _previewTimer?.cancel();

    int waitCount = 0;
    while (_isPreviewChecking && waitCount < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.isTakingPicture) {
      _startPreviewCheckLoop();
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _isReady = false;
        _normMarkers = [];
      });
      final XFile image = await _controller!.takePicture();
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'answer_sheet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);

      await image.saveTo(filePath);
      final capturedFile = File(filePath);

      if (mounted) {
        setState(() {
          _capturedImage = capturedFile;
        });
      }
      await _processImage(filePath);
    } catch (e) {
      _showErrorDialog('Error taking picture: $e');
      // Restart preview loop sau khi có lỗi
      if (mounted) {
        _startPreviewCheckLoop();
      }
    } finally {}
  }

  Future<void> _processImage(String imagePath) async {
    if (!mounted) return;

    try {
      final scanningProvider = Provider.of<ScanningProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('Not authenticated. Please login again.');
      }

      final imageFile = File(imagePath);

      var result = await scanningProvider.nativeScanAndGrade(
        imageFile: imageFile,
        quizId: widget.quiz.id,
        answersheetId: widget.answerSheet.id,
        token: token,
      );

      if (result == null || !result.success) {
        if (!mounted) return;

        final errorMsg =
            scanningProvider.error ?? result?.error ?? 'Scanning failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isProcessing = false;
          _capturedImage = null;
        });
        _startPreviewCheckLoop();
        return;
      }

      if (!mounted) return;

      // Success! Increment counter
      _scannedCount++;

      // Check scan mode
      final isContinuousMode = scanningProvider.isContinuousMode;

      if (isContinuousMode) {
        await _playSuccessSound();
        _lastCaptureTime = DateTime.now();

        setState(() {
          _showResultOverlay = true;
          _lastScanResult = result;
          _lastScannedImage = imageFile;
        });

        await Future.delayed(const Duration(milliseconds: 500));
        _startPreviewCheckLoop();
      } else {
        // Navigate to result screen
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ScanningResultScreen(
                  result: result,
                  quiz: widget.quiz,
                  answerSheet: widget.answerSheet,
                  scannedImage: imageFile,
                ),
              ),
            )
            .then((shouldRefresh) {
              if (mounted) {
                _resetState();
                _startPreviewCheckLoop();
                _hasResetAfterReturn = true;
              }
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        _startPreviewCheckLoop();
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted && !_isProcessing) {
                _startPreviewCheckLoop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetState() {
    setState(() {
      _isReady = false;
      _normMarkers = [];
      _isProcessing = false;
      _capturedImage = null;
      _lastCaptureTime = null;
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });

    final scanningProvider = Provider.of<ScanningProvider>(
      context,
      listen: false,
    );
    scanningProvider.clearResults();
  }

  void _dismissOverlay() {
    setState(() {
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });
    _startPreviewCheckLoop();
  }

  void _erasePaper() {
    if (_scannedCount > 0) {
      _scannedCount--;
    }

    setState(() {
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paper erased'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );

    _startPreviewCheckLoop();
  }

  void _reviewPaper() {
    if (_lastScanResult == null) return;

    setState(() {
      _showResultOverlay = false;
    });

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScanningResultScreen(
              result: _lastScanResult!,
              quiz: widget.quiz,
              answerSheet: widget.answerSheet,
              scannedImage: _lastScannedImage,
            ),
          ),
        )
        .then((shouldRefresh) {
          if (mounted) {
            _resetState();
            _startPreviewCheckLoop();
            _hasResetAfterReturn = true;
          }
        });
  }

  bool _hasResetAfterReturn = false;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text(
            'SCANNING',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Consumer<ScanningProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCANNING',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (_scannedCount > 0)
                  Text(
                    'Scanned: $_scannedCount papers',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            final scanningProvider = Provider.of<ScanningProvider>(
              context,
              listen: false,
            );
            scanningProvider.clearResults();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // Scan mode toggle button
          Consumer<ScanningProvider>(
            builder: (context, provider, _) {
              final isContinuous = provider.isContinuousMode;
              return Tooltip(
                message: isContinuous
                    ? 'Continuous Mode (ON)'
                    : 'Single Scan Mode',
                child: IconButton(
                  icon: Icon(
                    isContinuous ? Icons.repeat : Icons.looks_one,
                    color: isContinuous ? Colors.yellow : Colors.white,
                  ),
                  onPressed: () {
                    provider.toggleScanMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.isContinuousMode
                              ? 'Continuous Mode: Scan multiple papers'
                              : 'Single Mode: View result after each scan',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              _showSettingsDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_capturedImage != null && _isProcessing)
            Positioned.fill(
              child: Stack(
                children: [
                  // Ảnh đã chụp
                  Image.file(
                    _capturedImage!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Text(
                            'Error loading image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Đang chấm bài...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isProcessing)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isProcessing && _capturedImage == null)
            Positioned.fill(
              child: CustomPaint(
                painter: _MarkerOverlayPainter(
                  markers: _normMarkers,
                  ready: _isReady,
                ),
              ),
            ),

          if (_showResultOverlay && _lastScanResult != null)
            Positioned.fill(
              child: ScanResultOverlay(
                result: _lastScanResult!,
                quiz: widget.quiz,
                onDismiss: _erasePaper,
                onReviewPaper: _reviewPaper,
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkerOverlayPainter extends CustomPainter {
  final List<Map<String, dynamic>> markers;
  final bool ready;

  _MarkerOverlayPainter({required this.markers, required this.ready});

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('Painter: markers=${markers.length}, size=$size, ready=$ready');

    final Set<int> cornerIds = {1, 5, 9, 10};
    for (final m in markers) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null || !cornerIds.contains(id)) continue;
      final xn = (m['x'] as num?)?.toDouble();
      final yn = (m['y'] as num?)?.toDouble();
      if (xn == null || yn == null) continue;

      final cx = xn.clamp(0.0, 1.0) * size.width;
      final cy = yn.clamp(0.0, 1.0) * size.height;
      final rectSize = 50.0;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: rectSize,
        height: rectSize,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.green;

      canvas.drawRRect(rrect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerOverlayPainter oldDelegate) {
    return oldDelegate.markers != markers || oldDelegate.ready != ready;
  }
}
