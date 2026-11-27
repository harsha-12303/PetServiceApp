import '../entities/models.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);
  final AuthRepository _repository;

  Future<AppSession> call(String email, String password) =>
      _repository.signIn(email: email, password: password);
}
