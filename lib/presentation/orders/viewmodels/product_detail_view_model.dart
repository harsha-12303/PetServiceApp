import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/usecases/get_product_detail_use_case.dart';

class ProductDetailViewModel extends ChangeNotifier {
  ProductDetailViewModel(this._getProductDetail);
  final GetProductDetailUseCase _getProductDetail;

  bool isLoading = false;
  String? errorMessage;
  Product? product;

  Future<void> load(String bearerToken, String variantId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      product = await _getProductDetail(bearerToken, variantId);
    } on AppException catch (error) {
      errorMessage = error.message;
    } on Exception {
      errorMessage = 'Could not load product details.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
