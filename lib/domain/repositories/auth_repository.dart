import '../entities/models.dart';

abstract class AuthRepository {
  Future<AppSession> signIn({required String email, required String password});
}
