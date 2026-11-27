/// Persists the product quantities selected for the current device.
///
/// The backend remains the source of truth for the cart itself; this store
/// keeps the selected quantities available when the product list is rebuilt.
abstract class CartQuantityStore {
  Future<Map<String, int>> loadQuantities();

  /// Saves [quantity] for [variantId]. A quantity of zero removes it.
  Future<void> saveQuantity(String variantId, int quantity);
}
