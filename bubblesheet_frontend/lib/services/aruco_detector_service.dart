import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ArucoDetectorService {
  static const MethodChannel _channel = MethodChannel('aruco_detector');

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
