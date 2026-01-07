import 'package:flutter/material.dart';
import '../models/answer_key_model.dart';
import '../services/answer_key_service.dart';

class AnswerKeyProvider extends ChangeNotifier {
  List<AnswerKeyModel> _answerKeys = [];
  bool _isLoading = false;
  String? _error;

  List<AnswerKeyModel> get answerKeys => _answerKeys;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAnswerKeys(BuildContext context, String quizId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _answerKeys = await AnswerKeyService.getAnswerKeys(context: context, quizId: quizId);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _answerKeys = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
} 