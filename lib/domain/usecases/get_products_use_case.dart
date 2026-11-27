import '../entities/models.dart';
import '../repositories/catalog_repository.dart';

class GetProductsUseCase {
  const GetProductsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<List<Product>> call(
    String bearerToken, [
    ProductFilters filters = const ProductFilters(),
  ]) =>
      _repository.getProducts(bearerToken: bearerToken, filters: filters);
}
