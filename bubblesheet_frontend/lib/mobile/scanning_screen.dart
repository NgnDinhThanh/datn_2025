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
  File? _capturedImage; // Lưu ảnh đã chụp
  DateTime? _lastCaptureTime; // Thời gian chụp lần cuối để debounce

  static const Duration _captureDebounceDuration = Duration(seconds: 2); // Debounce 2 giây
  
  // Count scanned papers in session
  int _scannedCount = 0;
  
  // Overlay for continuous mode
  bool _showResultOverlay = false;
  ScanningResult? _lastScanResult;
  File? _lastScannedImage;

  @override
  void initState() {
    super.initState();
    // Reset state khi khởi tạo lại screen
    _isReady = false;
    _normMarkers = [];
    _isProcessing = false;
    _isPreviewChecking = false;
    _hasResetAfterReturn = false;
    _scannedCount = 0;
    
    // Clear results từ provider để tránh giữ state cũ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
      scanningProvider.clearResults();
      
      // Preload template for native scanning
      _preloadTemplate();
    });
    
    _initializeCamera();
  }
  
  /// Preload template for native scanning session
  Future<void> _preloadTemplate() async {
    final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token != null) {
      // Load template
      await scanningProvider.loadTemplate(
        answersheetId: widget.answerSheet.id,
        token: token,
      );
    //   Load and cache answer key
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
        // Offline hoặc lỗi mạng - dùng cache cũ
        print('[Sync] Cannot fetch answer key, using cache: $e');
      }
    }
  }
  
  /// Play success sound + vibration (native Android - ZipGrade style)
  Future<void> _playSuccessSound() async {
    try {
      await ArucoDetectorService.playShutterSound();
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }
  
  /// Show settings dialog
  void _showSettingsDialog() {
    final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
    
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
                  subtitle: const Text('Scan multiple papers without viewing results'),
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

      // Initialize camera controller
      // Sử dụng medium thay vì high để giảm kích thước ảnh và tăng tốc độ
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium, // Giảm từ high xuống medium để tối ưu tốc độ
        enableAudio: false,
      );

      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        // Đảm bảo reset state khi camera đã sẵn sàng
        _isReady = false;
        _normMarkers = [];
      });
      // Bắt đầu vòng kiểm tra preview định kỳ
      _startPreviewCheckLoop();
    } catch (e) {
      _showErrorDialog('Error initializing camera: $e');
    }
  }

  void _startPreviewCheckLoop() {
    _previewTimer?.cancel();
    
    // Reset state ngay khi bắt đầu loop
    if (mounted) {
      setState(() {
        _isReady = false;
        _normMarkers = [];
      });
    }
    
    // Giảm interval từ 900ms xuống 600ms để phát hiện nhanh hơn
      // Interval 400ms để phát hiện nhanh hơn (giảm delay)
      _previewTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      // Dừng preview check nếu đang processing hoặc đã có lỗi
      if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
      if (_isProcessing || _isPreviewChecking) return;
      
      // Kiểm tra xem camera có đang busy không
      if (!_controller!.value.isTakingPicture) {
        _isPreviewChecking = true;
        try {
          final XFile shot = await _controller!.takePicture();
          final file = File(shot.path);
          
          // Client-side ArUco detection (native plugin)
          final previewResult = await ArucoDetectorService.detectMarkers(file.path);
          debugPrint('Preview result: $previewResult');
          
          // Nếu native không khả dụng → bỏ qua frame này
          if (previewResult == null) {
            try { await file.delete(); } catch (_) {}
            return;
          }
          
          if (mounted && previewResult != null) {
            final result = previewResult!; // Capture non-null reference
            final isReady = result['ready'] ?? false;
            final markers = List<Map<String, dynamic>>.from(result['markersNorm'] ?? []);
            
            debugPrint('Flutter: isReady=$isReady, markers.length=${markers.length}, _isProcessing=$_isProcessing');
            
            setState(() {
              _isReady = isReady;
              _normMarkers = markers;
            });
            
            // Khi đủ 4 góc → dùng NGAY ảnh preview này để scan (không chụp lại)
            if (isReady && !_isProcessing) {
              debugPrint('Flutter: Ready to capture! Checking debounce...');
              final now = DateTime.now();
              final timeSinceLastCapture = _lastCaptureTime != null 
                  ? now.difference(_lastCaptureTime!) 
                  : null;
              debugPrint('Flutter: timeSinceLastCapture=$timeSinceLastCapture, debounce=$_captureDebounceDuration');
              
              if (_lastCaptureTime == null || 
                  now.difference(_lastCaptureTime!) > _captureDebounceDuration) {
                _lastCaptureTime = now;
                debugPrint('Flutter: Debounce passed! Starting capture...');
                
                // Phát âm thanh + rung khi chụp ảnh (native Android - ZipGrade style)
                try {
                  await ArucoDetectorService.playShutterSound();
                } catch (e) {
                  debugPrint('Error playing shutter sound: $e');
                }
                
                // Dừng preview check loop
                _previewTimer?.cancel();
                await Future.delayed(const Duration(milliseconds: 30));

                // final capturedFile = file;
                // setState(() {
                //   _isProcessing = true;
                //   _isReady = false;
                //   _capturedImage = capturedFile;
                //   // _normMarkers = [];
                // });
                
                // Dùng NGAY ảnh preview (đã có đủ 4 marker) để scan
                // Không chụp ảnh mới → đảm bảo không bị thiếu marker
                _processImage(file.path);
                return; // Không xóa file, sẽ được xóa sau khi process xong
              }
            }
          }
          
          // Chỉ xóa file tạm nếu KHÔNG dùng để scan
          try { await file.delete(); } catch (_) {}
        } catch (e, stackTrace) {
          // Log preview errors để debug
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
    // Kiểm tra điều kiện cơ bản
    if (_isProcessing || 
        _controller == null || 
        !_controller!.value.isInitialized || 
        !_isReady) {
      return;
    }

    // Dừng preview check loop khi đang chụp và xử lý
    _previewTimer?.cancel();
    
    // Đợi preview check hiện tại hoàn thành (nếu có)
    int waitCount = 0;
    while (_isPreviewChecking && waitCount < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    // Kiểm tra lại camera state
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) {
      // Restart preview loop nếu không thể chụp
      _startPreviewCheckLoop();
      return;
    }

    try {
      // Set processing state ngay để hiển thị feedback tức thì
      setState(() {
        _isProcessing = true;
        _isReady = false;
        _normMarkers = [];
      });

      // Take picture
      final XFile image = await _controller!.takePicture();
      
      // Save to app directory (chạy song song với việc hiển thị)
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'answer_sheet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);
      
      // Save file và hiển thị ảnh ngay
      await image.saveTo(filePath);
      final capturedFile = File(filePath);
      
      // Cập nhật UI với ảnh đã chụp
      if (mounted) {
        setState(() {
          _capturedImage = capturedFile;
        });
      }

      // Process the image ngay lập tức (không đợi gì thêm)
      await _processImage(filePath);
    } catch (e) {
      _showErrorDialog('Error taking picture: $e');
      // Restart preview loop sau khi có lỗi
      if (mounted) {
        _startPreviewCheckLoop();
      }
    } finally {
      // Không restart preview loop ở đây vì có thể đang navigate đến result screen
      // Preview loop sẽ được restart khi quay lại screen này
    }
  }

  Future<void> _processImage(String imagePath) async {
    if (!mounted) return;

    try {
      final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('Not authenticated. Please login again.');
      }

      final imageFile = File(imagePath);
      
      // Try native scanning first (faster, no image upload)
      var result = await scanningProvider.nativeScanAndGrade(
        imageFile: imageFile,
        quizId: widget.quiz.id,
        answersheetId: widget.answerSheet.id,
        token: token,
      );
      
      // If native scan failed, show error (no fallback to server)
      if (result == null || !result.success) {
        if (!mounted) return;
        
        final errorMsg = scanningProvider.error ?? result?.error ?? 'Scanning failed';
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
        // Continuous mode: Show/update overlay card, play sound, continue scanning
        // Grade is already queued in nativeScanAndGrade() → will auto-sync if online
        await _playSuccessSound();
        _lastCaptureTime = DateTime.now();
        
        // Update overlay with new result (keep scanning)
        setState(() {
          _showResultOverlay = true;
          _lastScanResult = result;
          _lastScannedImage = imageFile;
        });
        
        // Continue scanning immediately (don't wait for user action)
        await Future.delayed(const Duration(milliseconds: 500));
        _startPreviewCheckLoop();
        
      } else {
        // Single mode: Auto-save first, then navigate to result screen
        // Grade is already queued in nativeScanAndGrade() → will auto-sync if online
        // No need to call _autoSaveGrade() again (would cause duplicate)
        
        // Navigate to result screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScanningResultScreen(
              result: result,
              quiz: widget.quiz,
              answerSheet: widget.answerSheet,
              scannedImage: imageFile,
            ),
          ),
        ).then((shouldRefresh) {
          if (mounted) {
            _resetState();
            _startPreviewCheckLoop();
            _hasResetAfterReturn = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // setState(() {
        //   _isProcessing = false;
        //   _capturedImage = null;
        // });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _startPreviewCheckLoop();
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // Không cho dismiss bằng cách tap outside
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              // Chỉ đóng dialog, KHÔNG pop screen
              Navigator.of(context).pop();
              // Restart preview loop sau khi đóng dialog
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

  /// Reset state về trạng thái ban đầu
  void _resetState() {
    setState(() {
      _isReady = false;
      _normMarkers = [];
      _isProcessing = false;
      _capturedImage = null; // Clear ảnh đã chụp
      _lastCaptureTime = null; // Reset debounce timer
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });
    
    // Clear provider results
    final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
    scanningProvider.clearResults();
  }
  
  /// Dismiss the result overlay and continue scanning (used internally)
  void _dismissOverlay() {
    setState(() {
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });
    _startPreviewCheckLoop();
  }
  
  // Removed _autoSaveGrade() - grades are auto-saved via queue + sync in nativeScanAndGrade()
  // This prevents duplicate saves
  
  /// ERASE PAPER - discard current result and continue scanning
  void _erasePaper() {
    // Decrement count since we're erasing this scan
    if (_scannedCount > 0) {
      _scannedCount--;
    }
    
    // Clear the result and continue scanning
    setState(() {
      _showResultOverlay = false;
      _lastScanResult = null;
      _lastScannedImage = null;
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paper erased'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
    
    _startPreviewCheckLoop();
  }
  
  /// Navigate to result screen from overlay
  void _reviewPaper() {
    if (_lastScanResult == null) return;
    
    setState(() {
      _showResultOverlay = false;
    });
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanningResultScreen(
          result: _lastScanResult!,
          quiz: widget.quiz,
          answerSheet: widget.answerSheet,
          scannedImage: _lastScannedImage,
        ),
      ),
    ).then((shouldRefresh) {
      if (mounted) {
        _resetState();
        _startPreviewCheckLoop();
        _hasResetAfterReturn = true;
      }
    });
  }

  // Track if we've already reset after returning from result screen
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
            final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
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
                message: isContinuous ? 'Continuous Mode (ON)' : 'Single Scan Mode',
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
          // Hiển thị ảnh đã chụp nếu có, nếu không thì hiển thị camera preview
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
                  // Loading overlay khi đang xử lý
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                          ),
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
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            // Fallback: loading overlay nếu không có ảnh
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Markers overlay - hiển thị khi chưa chụp ảnh (vẫn hiện khi có overlay)
          // Hiển thị viền xanh quanh ArUco theo thời gian thực (không cần đợi ready)
          if (!_isProcessing && _capturedImage == null)
            Positioned.fill(
              child: CustomPaint(
                painter: _MarkerOverlayPainter(
                  markers: _normMarkers,
                  ready: _isReady,
                ),
              ),
            ),
          
          // Result overlay for continuous mode
          if (_showResultOverlay && _lastScanResult != null)
            Positioned.fill(
              child: ScanResultOverlay(
                result: _lastScanResult!,
                quiz: widget.quiz,
                onDismiss: _erasePaper, // ERASE PAPER - dismiss and discard
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
    // Debug: kiểm tra painter có được gọi không
    debugPrint('Painter: markers=${markers.length}, size=$size, ready=$ready');
    
    final Set<int> cornerIds = {1, 5, 9, 10};

    // Vẽ viền xanh quanh mỗi ArUco marker được phát hiện (real-time)
    // Không cần đợi ready, hiển thị ngay khi phát hiện
    for (final m in markers) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null || !cornerIds.contains(id)) continue;
      final xn = (m['x'] as num?)?.toDouble();
      final yn = (m['y'] as num?)?.toDouble();
      if (xn == null || yn == null) continue;

      final cx = xn.clamp(0.0, 1.0) * size.width;
      final cy = yn.clamp(0.0, 1.0) * size.height;
      // Kích thước khung nhỏ hơn để không che khuất
      final rectSize = 50.0;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: rectSize, height: rectSize);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

      // Chỉ vẽ viền xanh (không fill) - giống ZipGrade
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.green; // Màu xanh đậm

      canvas.drawRRect(rrect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerOverlayPainter oldDelegate) {
    // Repaint khi markers thay đổi (real-time update)
    return oldDelegate.markers != markers || oldDelegate.ready != ready;
  }
}

