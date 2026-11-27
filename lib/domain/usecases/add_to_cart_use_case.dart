import '../repositories/catalog_repository.dart';

class AddToCartUseCase {
  const AddToCartUseCase(this._repository);
  final CatalogRepository _repository;

  Future<void> call({
    required String bearerToken,
    required String variantId,
    required int quantity,
  }) =>
      _repository.addToCart(
        bearerToken: bearerToken,
        variantId: variantId,
        quantity: quantity,
      );
}

class RemoveFromCartUseCase {
  const RemoveFromCartUseCase(this._repository);
  final CatalogRepository _repository;

  Future<void> call({
    required String bearerToken,
    required String variantId,
  }) =>
      _repository.removeFromCart(
        bearerToken: bearerToken,
        variantId: variantId,
      );
}
