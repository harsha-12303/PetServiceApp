import '../entities/models.dart';
import 'admin_module_repository.dart';

abstract interface class ConfigurableOrderCatalog {
  CatalogRepository forModule(AdminModuleConfiguration configuration);
}

abstract class CatalogRepository {
  Future<List<Product>> getProducts({
    required String bearerToken,
    ProductFilters filters = const ProductFilters(),
  });

  Future<List<String>> getBrandNames({required String bearerToken});

  Future<Product> getProductDetail({
    required String bearerToken,
    required String variantId,
  });

  Future<void> addToCart({
    required String bearerToken,
    required String variantId,
    required int quantity,
  });

  Future<void> removeFromCart({
    required String bearerToken,
    required String variantId,
  });

  Future<List<CartItem>> getCartItems({required String bearerToken});
}
