import 'package:flutter/widgets.dart';

import 'data/datasources/auth_remote_data_source.dart';
import 'data/datasources/catalog_remote_data_source.dart';
import 'data/datasources/cart_quantity_local_data_source.dart';
import 'data/datasources/saved_credentials_store.dart';
import 'data/datasources/session_local_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/admin_module_repository_impl.dart';
import 'data/repositories/catalog_repository_impl.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionCache = SessionLocalDataSource();
  final cachedSession = await sessionCache.read();
  final authRepository = AuthRepositoryImpl(AuthRemoteDataSource());
  runApp(
    PetCareApp(
      authRepository: authRepository,
      adminModuleRepository:
          AdminModuleRepositoryImpl(authRepository.getMenuItems),
      catalogRepository: CatalogRepositoryImpl(CatalogRemoteDataSource()),
      cartQuantityStore: CartQuantityLocalDataSource(),
      initialSession: cachedSession,
      sessionCache: sessionCache,
      credentialsStore: DeviceCredentialsStore(),
    ),
  );
}
