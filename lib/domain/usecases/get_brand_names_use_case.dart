import '../repositories/catalog_repository.dart';

class GetBrandNamesUseCase {
  const GetBrandNamesUseCase(this._repository);
  final CatalogRepository _repository;

  Future<List<String>> call(String bearerToken) =>
      _repository.getBrandNames(bearerToken: bearerToken);
}
