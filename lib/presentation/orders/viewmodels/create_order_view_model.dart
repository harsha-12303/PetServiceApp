import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_products_use_case.dart';
import '../../../domain/usecases/get_brand_names_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import 'cart_view_model.dart';

class CreateOrderViewModel extends ChangeNotifier {
  CreateOrderViewModel(
    this._getProducts,
    this._getBrandNames,
    GetCartItemsUseCase getCartItems,
    AddToCartUseCase addToCart,
    RemoveFromCartUseCase removeFromCart,
    CartQuantityStore cartQuantityStore, {
    CartViewModel? cartViewModel,
  })  : _ownsCart = cartViewModel == null,
        cart = cartViewModel ??
            CartViewModel(getCartItems, addToCart, removeFromCart,
                quantityStore: cartQuantityStore);

  final GetProductsUseCase _getProducts;
  final GetBrandNamesUseCase _getBrandNames;
  final CartViewModel cart;
  final bool _ownsCart;

  bool isLoading = false;
  String? errorMessage;
  List<Product> products = const [];
  Future<List<String>> loadBrandNames(String bearerToken) =>
      _getBrandNames(bearerToken);
  ProductFilters filters = const ProductFilters();
  int _productRequest = 0;

  /// Last product list loaded without filters, for instant narrowing.
  List<Product>? _unfiltered;

  /// Instant feedback while typing a name: narrow the unfiltered list
  /// locally; the server search (debounced) replaces it shortly after.
  void narrowInstantly(String text) {
    final base = _unfiltered;
    if (base == null || _disposed) return;
    // Drop any older search still in flight so it can't overwrite this.
    _productRequest++;
    isLoading = false;
    final q = text.trim().toLowerCase();
    products = q.isEmpty
        ? base
        : base
            .where((p) => p.name.toLowerCase().contains(q))
            .toList(growable: false);
    errorMessage = null;
    notifyListeners();
  }

  bool _disposed = false;
  int quantityFor(String? variantId) => cart.quantityFor(variantId);
  int get cartItemCount => cart.itemCount;

  Future<void> load(String bearerToken) async {
    final request = ++_productRequest;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _getProducts(bearerToken, filters),
        if (_ownsCart) cart.load(bearerToken),
      ]);
      if (_disposed) return;
      if (request == _productRequest) {
        products = results[0] as List<Product>;
        if (filters.queryParameters.isEmpty) _unfiltered = products;
      }
    } on AppException catch (error) {
      if (request == _productRequest) errorMessage = error.message;
    } on Exception {
      if (request == _productRequest) {
        errorMessage = 'Could not load products. Please try again.';
      }
    } finally {
      if (request == _productRequest) isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> applyFilters(
    String bearerToken,
    ProductFilters value, {
    Duration debounce = Duration.zero,
  }) async {
    final request = ++_productRequest;
    filters = value;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (debounce != Duration.zero) await Future<void>.delayed(debounce);
      if (request != _productRequest) return;
      final results = await _getProducts(bearerToken, value);
      if (request == _productRequest) {
        products = results;
        if (value.queryParameters.isEmpty) _unfiltered = results;
      }
    } on AppException catch (error) {
      if (request == _productRequest) errorMessage = error.message;
    } on Exception {
      if (request == _productRequest) {
        errorMessage = 'Could not filter products. Please try again.';
      }
    } finally {
      if (request == _productRequest) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _productRequest++;
    super.dispose();
  }

  Future<String?> addProductToCart({
    required String bearerToken,
    required String variantId,
  }) =>
      changeQuantity(
        bearerToken: bearerToken,
        variantId: variantId,
        quantity: 1,
      );

  Future<String?> changeQuantity({
    required String bearerToken,
    required String variantId,
    required int quantity,
  }) {
    final product = products
            .where((product) => product.variantId == variantId)
            .firstOrNull ??
        Product(name: variantId, variantId: variantId);
    return cart.changeQuantity(
      bearerToken: bearerToken,
      item: CartItem(product: product, quantity: quantityFor(variantId)),
      quantity: quantity,
    );
  }
}
