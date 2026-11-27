/// PetWork backend service layer (same endpoints and behaviour as the web
/// admin). Create one [PetworkApi] at startup:
///
/// ```dart
/// final api = PetworkApi(onUnauthorized: () => navigatorKey.currentState
///     ?.pushNamedAndRemoveUntil('/login', (_) => false));
/// await api.sessions.restore();
/// ```
library;

import 'api_client.dart';
import 'api_environment.dart';
import 'auth/auth_service.dart';
import 'auth/session_store.dart';
import 'blueprint/blueprint_models.dart';
import 'blueprint/blueprint_service.dart';
import 'menu/menu_service.dart';
import 'orders/cart_service.dart';
import 'orders/checkout_service.dart';
import 'orders/product_service.dart';
import 'records/record_service.dart';

export 'api_client.dart';
export 'api_environment.dart';
export 'api_exception.dart';
export 'auth/auth_service.dart';
export 'auth/session_store.dart';
export 'blueprint/blueprint_models.dart';
export 'blueprint/blueprint_service.dart';
export 'menu/menu_service.dart';
export 'orders/cart_models.dart';
export 'orders/cart_parser.dart' show parseCart, parseLooseNumber;
export 'orders/cart_service.dart';
export 'orders/checkout_service.dart';
export 'orders/product_service.dart';
export 'records/body_builder.dart';
export 'records/form_logic.dart';
export 'records/form_values.dart';
export 'records/record_service.dart';
export 'records/record_utils.dart';

class PetworkApi {
  factory PetworkApi({
    ApiEnvironment? env,
    SessionStore? sessions,
    void Function()? onUnauthorized,
  }) {
    final store = sessions ?? SessionStore();
    final client = ApiClient(
      env: env ?? ApiEnvironment.fromDefines(),
      session: store,
      onUnauthorized: onUnauthorized,
    );
    return PetworkApi._(client, store);
  }

  PetworkApi._(this.client, this.sessions)
      : auth = AuthService(client, sessions),
        menu = MenuService(client),
        blueprints = BlueprintService(client),
        records = RecordService(client),
        products = ProductService(client),
        addresses = AddressStore(),
        checkout = CheckoutService();

  final ApiClient client;
  final SessionStore sessions;
  final AuthService auth;
  final MenuService menu;
  final BlueprintService blueprints;
  final RecordService records;
  final ProductService products;
  final AddressStore addresses;
  final CheckoutService checkout;

  /// A cart service for a Create Order table blueprint.
  CartService cartFor(TableBlueprint table) =>
      CartService(client, CartActions.from(table));
}
