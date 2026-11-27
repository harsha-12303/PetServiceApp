import '../../domain/entities/models.dart';
import '../../domain/repositories/admin_module_repository.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';
import '../mappers/product_record_mapper.dart';

class CatalogRepositoryImpl
    implements CatalogRepository, ConfigurableOrderCatalog {
  CatalogRepositoryImpl(this._remote);
  final CatalogRemoteDataSource _remote;

  @override
  CatalogRepository forModule(AdminModuleConfiguration configuration) =>
      CatalogRepositoryImpl(_remote.forModule(configuration));

  @override
  Future<List<Product>> getProducts({
    required String bearerToken,
    ProductFilters filters = const ProductFilters(),
  }) async {
    final records =
        await _remote.getProducts(bearerToken, filters.queryParameters);
    return records
        .whereType<Map>()
        .map(productFromRecord)
        .toList(growable: false);
  }

  @override
  Future<List<String>> getBrandNames({required String bearerToken}) async {
    final records = await _remote.getBrands(bearerToken);
    return records
        .map((record) => record is Map
            ? record['brandName']?.toString()
            : record?.toString())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<Product> getProductDetail({
    required String bearerToken,
    required String variantId,
  }) async =>
      productFromRecord(await _remote.getProductDetail(bearerToken, variantId));

  @override
  Future<void> addToCart({
    required String bearerToken,
    required String variantId,
    required int quantity,
  }) =>
      _remote.addToCart(
        bearerToken: bearerToken,
        variantId: variantId,
        quantity: quantity,
      );

  @override
  Future<void> removeFromCart({
    required String bearerToken,
    required String variantId,
  }) =>
      _remote.removeFromCart(
        bearerToken: bearerToken,
        variantId: variantId,
      );

  @override
  Future<List<CartItem>> getCartItems({required String bearerToken}) async {
    final records = await _remote.getCartItems(bearerToken);
    return records.whereType<Map>().map((record) {
      final item = Map<Object?, Object?>.from(record);
      final nested =
          item['product'] ?? item['productVariant'] ?? item['variant'];
      final productRecord = nested is Map
          ? Map<Object?, Object?>.from(nested)
          : <Object?, Object?>{};
      productRecord.addAll(item);
      final quantity = item['quantity'] ?? item['qty'] ?? item['cartQuantity'];
      return CartItem(
        product: productFromRecord(productRecord),
        quantity:
            quantity is num ? quantity.toInt() : int.tryParse('$quantity') ?? 1,
      );
    }).toList(growable: false);
  }
}
