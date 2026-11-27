import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/cart_quantity_store.dart';

class CartQuantityLocalDataSource implements CartQuantityStore {
  CartQuantityLocalDataSource({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'petwork_cart_quantities';
  final SharedPreferencesAsync _preferences;

  @override
  Future<Map<String, int>> loadQuantities() async {
    final raw = await _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map<String, int>((key, value) {
        final quantity = value is num ? value.toInt() : int.tryParse('$value');
        return MapEntry(
            '$key', quantity == null || quantity < 1 ? 0 : quantity);
      })
        ..removeWhere((_, quantity) => quantity == 0);
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> saveQuantity(String variantId, int quantity) async {
    final quantities = await loadQuantities();
    if (quantity < 1) {
      quantities.remove(variantId);
    } else {
      quantities[variantId] = quantity;
    }
    await _preferences.setString(_storageKey, jsonEncode(quantities));
  }
}
