import '../../core/errors/app_exception.dart';
import '../../domain/entities/models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemoteDataSource _remote;

  @override
  Future<AppSession> signIn(
      {required String email, required String password}) async {
    final tokenJson = await _remote.login(email, password);
    final bearerToken = tokenJson['bearerToken'];
    final refreshToken = tokenJson['refreshToken'];
    final expiresIn = tokenJson['expiresIn'];
    if (bearerToken is! String ||
        refreshToken is! String ||
        expiresIn == null) {
      throw const AppException(
          'The server returned incomplete authentication details.');
    }
    return AppSession(
      tokens: AuthTokens(
        bearerToken: bearerToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn.toString(),
      ),
      menuItems: await getMenuItems(bearerToken),
    );
  }

  Future<List<MenuItem>> getMenuItems(String bearerToken) async =>
      (await _remote.getMenuLinks(bearerToken))
          .whereType<Map>()
          .map(_toMenuItem)
          .toList(growable: false);

  MenuItem _toMenuItem(Map record, {bool isSubmenu = false}) {
    final children = record['subMenuList'] is List
        ? (record['subMenuList'] as List)
            .whereType<Map>()
            .map((child) => _toMenuItem(child, isSubmenu: true))
            .toList(growable: false)
        : const <MenuItem>[];
    return MenuItem(
      code:
          record[isSubmenu ? 'subMenuCode' : 'mainMenuCode']?.toString() ?? '',
      name: record[isSubmenu ? 'subMenuName' : 'mainMenuName']?.toString() ??
          'Menu',
      children: children,
      dataTableBlueprintUrl:
          (record['dataTableBluePrintUrl'] ?? record['dataTableBlueprintUrl'])
              ?.toString(),
      dataApi: record['dataApi']?.toString(),
      searchApi: record['searchApi']?.toString(),
      createApi: record['createApi']?.toString(),
      searchBlueprintUrl:
          (record['searchBluePrintUrl'] ?? record['searchBlueprintUrl'])
              ?.toString(),
    );
  }
}
