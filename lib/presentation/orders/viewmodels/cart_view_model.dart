import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';

class CartViewModel extends ChangeNotifier {
  CartViewModel(this._getCartItems, this._addToCart, this._removeFromCart,
      {CartQuantityStore? quantityStore})
      : _quantityStore = quantityStore;
  final GetCartItemsUseCase _getCartItems;
  final AddToCartUseCase _addToCart;
  final RemoveFromCartUseCase _removeFromCart;
  final CartQuantityStore? _quantityStore;

  bool isLoading = false;
  String? errorMessage;
  List<CartItem> items = const [];
  final Set<String> updatingVariantIds = {};

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  int quantityFor(String? variantId) => variantId == null
      ? 0
      : items
          .where((item) => item.product.variantId == variantId)
          .fold(0, (total, item) => total + item.quantity);

  bool isUpdating(String? variantId) =>
      variantId != null && updatingVariantIds.contains(variantId);

  Future<void> load(String bearerToken) async {
    if (isLoading || updatingVariantIds.isNotEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _getCartItems(bearerToken);
    } on AppException catch (error) {
      errorMessage = error.message;
    } on Exception {
      errorMessage = 'Could not load cart. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> changeQuantity({
    required String bearerToken,
    required CartItem item,
    required int quantity,
  }) async {
    final variantId = item.product.variantId;
    if (variantId == null || variantId.isEmpty) {
      return 'This product cannot be updated because it has no variant ID.';
    }
    if (quantity < 0 || isLoading || isUpdating(variantId)) return null;
    if (errorMessage != null) return errorMessage;
    final previousItem = items
        .where((entry) => entry.product.variantId == variantId)
        .firstOrNull;
    if ((previousItem?.quantity ?? 0) == quantity) return null;

    updatingVariantIds.add(variantId);
    final product = previousItem?.product ?? item.product;
    _setItem(
        variantId,
        quantity == 0
            ? null
            : CartItem(
                product: product,
                quantity: quantity,
              ));
    notifyListeners();
    try {
      if (quantity == 0) {
        await _removeFromCart(
          bearerToken: bearerToken,
          variantId: variantId,
        );
      } else {
        await _addToCart(
          bearerToken: bearerToken,
          variantId: variantId,
          quantity: quantity,
        );
      }
      try {
        await _quantityStore?.saveQuantity(variantId, quantity);
      } on Exception {
        // A device cache failure does not undo a confirmed cart update.
      }
      return null;
    } on AppException catch (error) {
      _setItem(variantId, previousItem);
      return error.message;
    } on Exception {
      _setItem(variantId, previousItem);
      return 'Could not update the cart quantity.';
    } finally {
      updatingVariantIds.remove(variantId);
      notifyListeners();
    }
  }

  void _setItem(String variantId, CartItem? replacement) {
    final updatedItems = List<CartItem>.of(items);
    final index =
        updatedItems.indexWhere((item) => item.product.variantId == variantId);
    if (index >= 0) {
      if (replacement == null) {
        updatedItems.removeAt(index);
      } else {
        updatedItems[index] = replacement;
      }
    } else if (replacement != null) {
      updatedItems.add(replacement);
    }
    items = updatedItems;
  }
}
