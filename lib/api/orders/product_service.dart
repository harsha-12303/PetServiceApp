import '../api_client.dart';
import '../blueprint/blueprint_models.dart';
import '../records/record_utils.dart';

/// Keys a variant id may live under (`varientId` is a real backend spelling).
const variantIdKeys = [
  'variantId',
  'varientId',
  'variant_id',
  'id',
  '_id',
  'variantCode'
];

/// The variant id of a product row: the default variant (`isDefault`),
/// else the first variant, else the record itself.
String? variantIdOf(Map record) {
  final variants = record['variants'];
  Map? target;
  if (variants is List) {
    final maps = variants.whereType<Map>().toList();
    for (final v in maps) {
      if (v['isDefault'] == true ||
          '${v['isDefault']}'.toLowerCase() == 'true') {
        target = v;
        break;
      }
    }
    target ??= maps.isEmpty ? null : maps.first;
  }
  return firstIdIn(target ?? record, variantIdKeys);
}

String? firstIdIn(Map map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
  }
  return null;
}

final _idPlaceholder =
    RegExp(r'\{(variantId|varientId|recordId|id)\}', caseSensitive: false);

/// Fills the first `{variantId}` / `{varientId}` / `{recordId}` / `{id}`
/// placeholder with the url-encoded [variantId].
String fillVariantPlaceholder(String dataApi, String variantId) =>
    dataApi.replaceFirst(_idPlaceholder, Uri.encodeComponent(variantId));

class ProductService {
  ProductService(this._client);
  final ApiClient _client;

  /// Runs the row's "view" action (usually `display: false`, triggered when a
  /// product card is tapped). Returns the product with its variants.
  Future<Map<String, dynamic>?> fetchVariantDetails(
    BlueprintAction viewAction,
    Map<String, dynamic> record,
  ) async {
    final dataApi = viewAction.dataApi;
    if (dataApi == null) throw StateError('The view action has no dataApi.');
    final id = variantIdOf(record);
    if (id == null) throw StateError('This product has no variant id.');
    final path =
        _client.env.resolveApiPath(fillVariantPlaceholder(dataApi, id));
    return unwrapRecord(await _client.get(path));
  }

  /// The row action that opens a product, if the blueprint has one.
  static BlueprintAction? viewActionOf(TableBlueprint table) {
    for (final a in table.rowActions) {
      if (a.isView && a.dataApi != null) return a;
    }
    return null;
  }
}
