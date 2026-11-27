import '../api_client.dart';
import '../blueprint/blueprint_models.dart';
import 'cart_models.dart';
import 'cart_parser.dart';

/// The cart actions found in the Create Order table blueprint.
class CartActions {
  const CartActions({this.addAction, this.headerAction});

  /// Add-to-cart: a row action with a `createApi` that mentions "cart".
  /// Cart header: a header action that mentions "cart", with a `dataApi` and
  /// no `blueprintApi`.
  factory CartActions.from(TableBlueprint table) {
    BlueprintAction? add;
    for (final a in table.rowActions) {
      if (a.createApi != null && a.mentionsCart) {
        add = a;
        break;
      }
    }
    BlueprintAction? header;
    for (final a in table.actions) {
      if (a.mentionsCart && a.dataApi != null && a.blueprintApi == null) {
        header = a;
        break;
      }
    }
    return CartActions(addAction: add, headerAction: header);
  }

  final BlueprintAction? addAction;
  final BlueprintAction? headerAction;

  /// Where the cart is read from.
  String? get readApi => headerAction?.dataApi ?? addAction?.createApi;

  /// Where quantities are set / removed (falls back to the header's dataApi).
  String? get writeApi => addAction?.createApi ?? headerAction?.dataApi;

  bool get isAvailable => readApi != null && writeApi != null;
}

class CartService {
  CartService(this._client, this.actions);

  final ApiClient _client;
  final CartActions actions;

  /// Load on screen open (so cards show quantities) and when the cart opens.
  Future<Cart> fetchCart() async {
    final api = actions.readApi;
    if (api == null) return Cart.empty;
    return parseCart(await _client.get(_client.env.resolveApiPath(api)));
  }

  /// Sends the NEW TOTAL quantity (not a delta). 0 or less removes the line,
  /// because the POST does not accept 0.
  Future<void> setQuantity(String variantId, int quantity) async {
    if (quantity <= 0) return remove(variantId);
    await _client.post(
      _client.env.resolveApiPath(_writeApi),
      body: {'variantId': variantId, 'quantity': quantity},
    );
  }

  /// `DELETE {createApi}/{variantId}`.
  Future<void> remove(String variantId) async {
    await _client
        .delete(removePath(_client.env.resolveApiPath(_writeApi), variantId));
  }

  String get _writeApi {
    final api = actions.writeApi;
    if (api == null) throw StateError('This screen has no cart action.');
    return api;
  }
}

/// The resolved createApi without its trailing `/`, plus `/<encoded id>`.
String removePath(String resolvedCreateApi, String variantId) {
  var base = resolvedCreateApi;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return '$base/${Uri.encodeComponent(variantId)}';
}
