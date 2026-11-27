import '../api_client.dart';
import '../api_exception.dart';
import 'blueprint_models.dart';

/// Loads blueprints. Always fetched fresh; never cached.
class BlueprintService {
  BlueprintService(this._client);
  final ApiClient _client;

  Future<TableBlueprint> table(String url) async =>
      TableBlueprint.fromJson(await loadRaw(url));

  Future<FormBlueprint> form(String url) async =>
      FormBlueprint.fromJson(await loadRaw(url));

  Future<SearchBlueprint> search(String url) async =>
      SearchBlueprint.fromJson(await loadRaw(url));

  /// Like [search], but null when it can't load: the list still shows,
  /// just without search.
  Future<SearchBlueprint?> searchOrNull(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      return await search(url);
    } catch (_) {
      return null;
    }
  }

  /// `service/blueprint/{version}/name` URLs try `/api/...` first and fall
  /// back to `/service/api/blueprint/name` on 404. Others are fetched as is.
  Future<Json> loadRaw(String url) async {
    final paths = blueprintPaths(url, _client.env.resolveApiPath);
    for (var i = 0; i < paths.length; i++) {
      try {
        return _asObject(await _client.get(paths[i]));
      } on ApiException catch (e) {
        if (!e.isNotFound || i == paths.length - 1) rethrow;
      }
    }
    throw StateError('unreachable');
  }

  static Json _asObject(Object? body) {
    if (body is Map) return Map<String, dynamic>.from(body);
    if (body is List && body.isNotEmpty && body.first is Map) {
      return Map<String, dynamic>.from(body.first as Map);
    }
    throw const ApiException('The screen definition could not be read.', 0);
  }
}

final _shortBlueprint = RegExp(r'^/?([\w-]+)/blueprint/\{version\}/([\w-]+)$');

/// The paths to try, in order, for a blueprint URL.
List<String> blueprintPaths(
    String url, String Function(String) resolveApiPath) {
  final m = _shortBlueprint.firstMatch(url.trim());
  if (m == null) return [resolveApiPath(url)];
  return [
    '/api${resolveApiPath(url)}',
    '/${m.group(1)}/api/blueprint/${m.group(2)}',
  ];
}
