import '../entities/models.dart';
import '../repositories/catalog_repository.dart';

class GetProductDetailUseCase {
  const GetProductDetailUseCase(this._repository);
  final CatalogRepository _repository;

  Future<Product> call(String bearerToken, String variantId) =>
      _repository.getProductDetail(
        bearerToken: bearerToken,
        variantId: variantId,
      );
}
