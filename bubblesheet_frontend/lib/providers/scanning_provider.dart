import 'dart:io';
import 'package:bubblesheet_frontend/services/answer_key_cache_service.dart';
import 'package:bubblesheet_frontend/services/answer_sheet_template_cache_service.dart';
import 'package:bubblesheet_frontend/services/grading_result_queue_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:bubblesheet_frontend/models/scanning_result.dart';
import 'package:bubblesheet_frontend/services/scanning_service.dart';
import 'package:bubblesheet_frontend/services/aruco_detector_service.dart';

class ScanningProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  PreviewCheckResult? _previewResult;
  ScanningResult? _scanResult;
  File? _currentImage;
  bool _isContinuousMode = false;

  Map<String, dynamic>? _cachedTemplate;

  bool get isLoading => _isLoading;

  String? get error => _error;

  PreviewCheckResult? get previewResult => _previewResult;

  ScanningResult? get scanResult => _scanResult;

  File? get currentImage => _currentImage;

  bool get isContinuousMode => _isContinuousMode;

  Map<String, dynamic>? get cachedTemplate => _cachedTemplate;

  void toggleScanMode() {
    _isContinuousMode = !_isContinuousMode;
    notifyListeners();
  }

  void setScanMode(bool continuous) {
    _isContinuousMode = continuous;
    notifyListeners();
  }

  Future<bool> loadTemplate({
    required String answersheetId,
    required String token,
  }) async {
    try {
      _cachedTemplate = AnswerSheetTemplateCacheService.getTemplate(
        answersheetId,
      );

      if (_cachedTemplate != null) {
        print(
          '[AnswerSheetTemplateCache] Loaded template from cache: $answersheetId',
        );

        ScanningService.getTemplateJson(
              answersheetId: answersheetId,
              token: token,
            )
            .then((newTemplate) {
              if (newTemplate != null) {
                AnswerSheetTemplateCacheService.cacheTemplate(
                  answersheetId,
                  newTemplate,
                );
                _cachedTemplate = newTemplate;
                print(
                  '[AnswerSheetTemplateCache] Updated template from server: $answersheetId',
                );
              }
            })
            .catchError((e) {
              print(
                '[AnswerSheetTemplateCache] Cannot update template, using cache: $e',
              );
            });

        return true;
      }
      _cachedTemplate = await ScanningService.getTemplateJson(
        answersheetId: answersheetId,
        token: token,
      );

      if (_cachedTemplate != null) {
        // 4. Cache lại để dùng lần sau
        await AnswerSheetTemplateCacheService.cacheTemplate(
          answersheetId,
          _cachedTemplate!,
        );
        print(
          '[AnswerSheetTemplateCache] Fetched and cached template: $answersheetId',
        );
        return true;
      }

      return false;
    } catch (e) {
      _cachedTemplate = AnswerSheetTemplateCacheService.getTemplate(
        answersheetId,
      );

      if (_cachedTemplate != null) {
        print(
          '[AnswerSheetTemplateCache] Using cached template after fetch error: $answersheetId',
        );
        return true;
      }

      _error = e.toString();
      return false;
    }
  }

  Future<bool> previewCheck(File imageFile, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentImage = imageFile;
      _previewResult = await ScanningService.previewCheck(imageFile, token);
      _isLoading = false;
      notifyListeners();
      return _previewResult?.ready ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<ScanningResult?> scanAndGrade({
    required File imageFile,
    required String quizId,
    required String answersheetId,
    required String token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentImage = imageFile;
      _scanResult = await ScanningService.scanAndGrade(
        imageFile: imageFile,
        quizId: quizId,
        answersheetId: answersheetId,
        token: token,
      );
      _isLoading = false;
      notifyListeners();
      return _scanResult;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<ScanningResult?> nativeScanAndGrade({
    required File imageFile,
    required String quizId,
    required String answersheetId,
    required String token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentImage = imageFile;

      if (_cachedTemplate == null) {
        final loaded = await loadTemplate(
          answersheetId: answersheetId,
          token: token,
        );
        if (!loaded || _cachedTemplate == null) {
          throw Exception('Failed to load template');
        }
      }

      final nativeResult = await ArucoDetectorService.scanAnswerSheet(
        imagePath: imageFile.path,
        template: _cachedTemplate!,
      );

      if (nativeResult == null) {
        throw Exception('Native scanning not available');
      }

      if (nativeResult['success'] != true) {
        throw Exception(nativeResult['error'] ?? 'Native scan failed');
      }

      final studentIdDigits = List<int>.from(
        nativeResult['student_id_digits'] ?? [],
      );
      final quizIdDigits = List<int>.from(nativeResult['quiz_id_digits'] ?? []);
      final classIdDigits = List<int>.from(
        nativeResult['class_id_digits'] ?? [],
      );
      final answersRaw = Map<String, dynamic>.from(
        nativeResult['answers_raw'] ?? {},
      );
      final totalQuestions = nativeResult['total_questions'] as int? ?? 0;
      final blankCount = nativeResult['blank_count'] as int? ?? 0;
      final multipleMarks = nativeResult['multiple_marks'] as int? ?? 0;

      final studentId = studentIdDigits.join('');
      final versionCode = quizIdDigits.join('').padLeft(3, '0');
      final classId = classIdDigits.isNotEmpty ? classIdDigits.join('') : null;

      final answers = <String, dynamic>{};
      for (final entry in answersRaw.entries) {
        final qIdx = int.tryParse(entry.key);
        if (qIdx != null) {
          answers[(qIdx + 1).toString()] = entry.value;
        }
      }

      final offlineResult = AnswerKeyCacheService.gradeOffline(
        quizId: quizId,
        versionCode: versionCode,
        studentAnswers: answers,
      );

      if (offlineResult != null) {
        final errorMsg = offlineResult['error']?.toString();
        final versionNotFound = offlineResult['versionNotFound'] == true;

        _scanResult = ScanningResult(
          success: true,
          score: offlineResult['score'] as int,
          totalQuestions: offlineResult['totalQuestions'] as int,
          percentage: (offlineResult['percentage'] as num).toDouble(),
          studentId: studentId,
          quizId: quizId,
          classId: classId,
          answers: answers,
          correctAnswers: versionNotFound
              ? null
              : Map<String, int>.from(offlineResult['correctAnswers']),
          versionCode: versionCode,
          error: errorMsg,
        );
      } else {
        try {
          _scanResult = await ScanningService.gradeFromJson(
            quizId: quizId,
            answersheetId: answersheetId,
            studentId: studentId,
            versionCode: versionCode,
            classId: classId,
            answers: answers,
            totalQuestions: totalQuestions,
            token: token,
            warpedImageBase64: nativeResult['images']?['warped_image_base64'],
          );

          try {
            final answerKey = await ScanningService.getAnswerKey(
              quizId: quizId,
              token: token,
            );
            if (answerKey != null) {
              await AnswerKeyCacheService.cacheAnswerKey(quizId, answerKey);
              print(
                '[ScanningProvider] Cached answer key after server grading',
              );
            }
          } catch (e) {
            print('[ScanningProvider] Failed to cache answer key: $e');
          }
        } catch (e) {
          throw Exception(
            'Cannot grade offline: Answer key not cached. Please open this quiz while online first to cache the answer key.',
          );
        }
      }

      final warpedImageBase64 =
          nativeResult['images']?['warped_image_base64'] as String?;
      final nativeAnnotated =
          nativeResult['images']?['annotated_image_base64'] as String?;
      final infoSectionBase64 =
          nativeResult['images']?['info_section_base64'] as String?;

      String? finalAnnotatedImage;

      final isVersionError =
          _scanResult?.error != null &&
          _scanResult!.error!.contains('Version code') &&
          _scanResult!.error!.contains('not found in answer key');

      if (_scanResult != null &&
          _scanResult!.correctAnswers != null &&
          warpedImageBase64 != null &&
          !isVersionError) {
        try {
          finalAnnotatedImage = await ArucoDetectorService.createAnnotatedImage(
            warpedImageBase64: warpedImageBase64,
            template: _cachedTemplate!,
            studentAnswers: _scanResult!.answers,
            correctAnswers: _scanResult!.correctAnswers!,
          );
        } catch (e) {
          debugPrint('createAnnotatedImage error: $e');
        }
      }

      if (finalAnnotatedImage == null && nativeAnnotated != null) {
        finalAnnotatedImage = nativeAnnotated;
      }

      if (_scanResult != null) {
        _scanResult = _scanResult!.copyWith(
          annotatedImageBase64:
              finalAnnotatedImage ?? _scanResult!.annotatedImageBase64,
          warpedImageBase64: warpedImageBase64,
          infoSectionBase64: infoSectionBase64,
          blankCount: blankCount,
          multipleMarks: multipleMarks,
        );
      }

      _isLoading = false;
      notifyListeners();

      if (_scanResult != null && _scanResult!.success) {
        await GradingResultQueueService.addToQueue({
          'quizId': quizId,
          'classId': classId,
          'studentId': studentId,
          'versionCode': versionCode,
          'answersheetId': answersheetId,
          'score': _scanResult!.score,
          'totalQuestions': _scanResult!.totalQuestions,
          'percentage': _scanResult!.percentage,
          'answers': _scanResult!.answers,
          'gradedAt': DateTime.now().toIso8601String(),
        });
      }

      SyncService.hasNetworkConnection()
          .then((hasNetwork) {
            if (hasNetwork) {
              SyncService.syncPendingResults(token);
            }
          })
          .catchError((e) {
            print('[Sync] Auto-sync failed: $e');
          });
      return _scanResult;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> saveGrade({
    required String quizId,
    required String studentId,
    required int score,
    required double percentage,
    required Map<String, dynamic> answers,
    required String versionCode,
    required String answersheetId,
    required String token,
    String? classId,
    File? scannedImage,
    File? annotatedImage,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ScanningService.saveGrade(
        quizId: quizId,
        studentId: studentId,
        score: score,
        percentage: percentage,
        answers: answers,
        versionCode: versionCode,
        answersheetId: answersheetId,
        token: token,
        classId: classId,
        scannedImage: scannedImage,
        annotatedImage: annotatedImage,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearResults() {
    _previewResult = null;
    _scanResult = null;
    _currentImage = null;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _error = null;
    _previewResult = null;
    _scanResult = null;
    _currentImage = null;
    notifyListeners();
  }
}
