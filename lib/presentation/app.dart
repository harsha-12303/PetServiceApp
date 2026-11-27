import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../data/datasources/saved_credentials_store.dart';
import '../data/datasources/session_local_data_source.dart';
import '../domain/entities/models.dart';
import '../domain/repositories/admin_module_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/cart_quantity_store.dart';
import '../domain/usecases/sign_in_use_case.dart';
import 'auth/views/login_screen.dart';
import 'auth/viewmodels/login_view_model.dart';
import 'home/views/petwork_home_screen.dart';

class PetCareApp extends StatelessWidget {
  const PetCareApp({
    super.key,
    required this.authRepository,
    required this.catalogRepository,
    required this.cartQuantityStore,
    this.initialSession,
    this.sessionCache,
    this.adminModuleRepository,
    this.credentialsStore,
  });

  final CredentialsStore? credentialsStore;

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final CartQuantityStore cartQuantityStore;
  final AppSession? initialSession;
  final SessionLocalDataSource? sessionCache;
  final AdminModuleRepository? adminModuleRepository;

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.dmSansTextTheme();
    LoginScreen buildLoginScreen() => LoginScreen(
          viewModel: LoginViewModel(SignInUseCase(authRepository)),
          catalogRepository: catalogRepository,
          cartQuantityStore: cartQuantityStore,
          adminModuleRepository: adminModuleRepository,
          sessionCache: sessionCache,
          loginScreenBuilder: buildLoginScreen,
          credentialsStore: credentialsStore,
        );
    return MaterialApp(
      title: 'PetCareServices',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(textTheme),
      home: initialSession == null
          ? buildLoginScreen()
          : PetWorkHomeScreen(
              session: initialSession!,
              catalogRepository: catalogRepository,
              cartQuantityStore: cartQuantityStore,
              adminModuleRepository: adminModuleRepository,
              onLogout: sessionCache?.clear,
              loginScreenBuilder: buildLoginScreen,
            ),
    );
  }
}
