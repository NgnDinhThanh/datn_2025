import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service để detect ArUco markers ở client (native plugin)
class ArucoDetectorService {
  static const MethodChannel _channel = MethodChannel('aruco_detector');

  /// Detect ArUco markers trong ảnh
  /// 
  /// [imagePath]: Đường dẫn đến file ảnh
  /// 
  /// Returns: {
  ///   'ready': bool,  // true nếu đủ 4 điểm (1, 5, 9, 10)
  ///   'markersNorm': List<Map<String, dynamic>>,  // [{id: int, x: double, y: double}]
  /// }
  static Future<Map<String, dynamic>?> detectMarkers(String imagePath) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint('ArucoService: Platform not supported');
        return null;
      }

      debugPrint('ArucoService: Calling detectMarkers for $imagePath');
      
      final result = await _channel.invokeMethod('detectMarkers', {
        'imagePath': imagePath,
        'arucoType': 'DICT_4X4_50',
        'cornerIds': [1, 5, 9, 10],
      });

      debugPrint('ArucoService: Raw result type: ${result.runtimeType}');
      debugPrint('ArucoService: Raw result: $result');

      if (result == null) {
        debugPrint('ArucoService: Result is null');
        return null;
      }

      // Safely convert markersNorm
      List<Map<String, dynamic>> markers = [];
      final rawMarkers = result['markersNorm'];
      if (rawMarkers is List) {
        for (var m in rawMarkers) {
          if (m is Map) {
            markers.add(Map<String, dynamic>.from(m));
          }
        }
      }
      
      final processedResult = {
        'ready': result['ready'] ?? false,
        'markersNorm': markers,
      };
      
      debugPrint('ArucoService: Processed result: $processedResult');
      return processedResult;
    } catch (e, stackTrace) {
      debugPrint('ArucoService: Error in detectMarkers: $e');
      debugPrint('ArucoService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Scan full answer sheet trên client (native OpenCV)
  ///
  /// [imagePath]: đường dẫn ảnh đã chụp
  /// [template]: JSON template của phiếu (lấy từ backend)
  ///
  /// Kỳ vọng native trả về:
  /// {
  ///   success: bool,
  ///   error: String?,
  ///   student_id_digits: List<int>,
  ///   quiz_id_digits: List<int>,
  ///   class_id_digits: List<int>,
  ///   answers_raw: Map<String, int>,   // "0": 2, "1": 0, "2": -1, ...
  ///   total_questions: int,
  ///   metadata: Map<String, dynamic>?,
  ///   images: {
  ///     warped_image_base64: String?,
  ///     annotated_image_base64: String?,
  ///   }
  /// }
  static Future<Map<String, dynamic>?> scanAnswerSheet({
    required String imagePath,
    required Map<String, dynamic> template,
  }) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return null;
      }

      final result = await _channel.invokeMethod('scanAnswerSheet', {
        'imagePath': imagePath,
        'template': template,
      });

      if (result == null) {
        return null;
      }

      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('scanAnswerSheet error: $e');
      return null;
    }
  }
  
  /// Play camera shutter sound + vibration (native Android)
  static Future<bool> playShutterSound() async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }
      final result = await _channel.invokeMethod('playShutterSound');
      return result == true;
    } catch (e) {
      debugPrint('playShutterSound error: $e');
      return false;
    }
  }
  
  /// Create annotated image with grading results
  /// Uses warped image from scanAnswerSheet and grading results from server
  /// 
  /// Colors:
  /// - Green: Correct answer
  /// - Red: Wrong answer (student's answer)
  /// - Cyan: Show correct answer (when student is wrong)
  /// - Yellow: Blank (no answer)
  static Future<String?> createAnnotatedImage({
    required String warpedImageBase64,
    required Map<String, dynamic> template,
    required Map<String, dynamic> studentAnswers,
    required Map<String, dynamic> correctAnswers,
  }) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return null;
      }
      
      final result = await _channel.invokeMethod('createAnnotatedImage', {
        'warpedImageBase64': warpedImageBase64,
        'template': template,
        'studentAnswers': studentAnswers,
        'correctAnswers': correctAnswers,
      });
      
      if (result == null) {
        return null;
      }
      
      return result['annotated_image_base64'] as String?;
    } catch (e) {
      debugPrint('createAnnotatedImage error: $e');
      return null;
    }
  }
}

