import '../api_client.dart';
import '../api_exception.dart';

class SubMenu {
  const SubMenu({
    required this.code,
    required this.name,
    required this.url,
    required this.order,
    required this.dataTableBlueprintUrl,
    required this.searchBlueprintUrl,
    required this.raw,
  });

  factory SubMenu.fromJson(Map<String, dynamic> json) => SubMenu(
        code: '${json['subMenuCode'] ?? ''}',
        name: '${json['subMenuName'] ?? ''}',
        url: json['url'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        dataTableBlueprintUrl: _nonEmpty(json['dataTableBluePrintUrl']),
        searchBlueprintUrl: _nonEmpty(json['searchBluePrintUrl']),
        raw: json,
      );

  final String code;
  final String name;
  final String? url;
  final int order;

  /// From `dataTableBluePrintUrl` (capital P on the wire).
  final String? dataTableBlueprintUrl;

  /// From `searchBluePrintUrl`; optional.
  final String? searchBlueprintUrl;
  final Map<String, dynamic> raw;
}

class MenuGroup {
  const MenuGroup({
    required this.code,
    required this.name,
    required this.icon,
    required this.subMenus,
  });

  factory MenuGroup.fromJson(Map<String, dynamic> json) {
    final subs = (json['subMenuList'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => SubMenu.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return MenuGroup(
      code: '${json['mainMenuCode'] ?? ''}',
      name: '${json['mainMenuName'] ?? ''}',
      icon: json['icon'] as String?,
      subMenus: subs,
    );
  }

  final String code;
  final String name;
  final String? icon;

  /// Sorted by `order` (null counts as 0).
  final List<SubMenu> subMenus;
}

class MenuService {
  MenuService(this._client);
  final ApiClient _client;

  /// `GET /users/api/menulinks`: the screens this user may open.
  Future<List<MenuGroup>> fetchMenu() async =>
      parseMenu(await _client.get('/users/api/menulinks'));
}

List<MenuGroup> parseMenu(Object? body) {
  final map = body is Map ? body : const {};
  final records = (map['records'] as List? ?? const [])
      .whereType<Map>()
      .map((m) => MenuGroup.fromJson(Map<String, dynamic>.from(m)))
      .toList();
  final errors = map['errorMessages'];
  if (records.isEmpty && errors is List && errors.isNotEmpty) {
    throw ApiException(errors.map((e) => '$e').join('. '), 200);
  }
  return records;
}

String? _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
