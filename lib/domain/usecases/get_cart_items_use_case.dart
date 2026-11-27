import '../entities/models.dart';
import '../repositories/catalog_repository.dart';

class GetCartItemsUseCase {
  const GetCartItemsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<List<CartItem>> call(String bearerToken) =>
      _repository.getCartItems(bearerToken: bearerToken);
}
