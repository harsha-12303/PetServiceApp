import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/usecases/sign_in_use_case.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._signIn);
  final SignInUseCase _signIn;

  bool isLoading = false;
  String? errorMessage;

  Future<AppSession?> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _signIn(email, password);
    } on AppException catch (error) {
      errorMessage = error.message;
    } on Exception {
      errorMessage = 'Could not sign in. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return null;
  }
}
