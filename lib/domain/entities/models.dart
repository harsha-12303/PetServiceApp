class AuthTokens {
  const AuthTokens({
    required this.bearerToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String bearerToken;
  final String refreshToken;
  final String expiresIn;
}

class AppSession {
  const AppSession({required this.tokens, required this.menuItems});

  final AuthTokens tokens;
  final List<MenuItem> menuItems;
}

class MenuItem {
  const MenuItem(
      {required this.code,
      required this.name,
      this.children = const [],
      this.dataTableBlueprintUrl,
      this.searchBlueprintUrl,
      this.searchApi,
      this.createApi,
      this.dataApi,
      this.icon});

  final String code;
  final String name;

  /// Icon name from the backend menu (usually Font Awesome, e.g. `fa-box`).
  final String? icon;
  final List<MenuItem> children;
  final String? dataTableBlueprintUrl;
  final String? searchBlueprintUrl;
  final String? searchApi;
  final String? createApi;
  final String? dataApi;

  bool get isProductManagement => [code, name].any((value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '')
      .contains('productmanag'));
}

class Product {
  const Product({
    required this.name,
    this.variantId,
    this.mainImage,
    this.imageUrls = const [],
    this.description,
    this.category,
    this.brand,
    this.flavour,
    this.breedSize,
    this.petType,
    this.lifeStage,
    this.unitSize,
    this.unitType,
    this.price,
    this.mrp,
    this.variants = const [],
  });

  final String name;
  final String? variantId;
  final String? mainImage;
  final List<String> imageUrls;
  final String? description;
  final String? category;
  final String? brand;
  final String? flavour;
  final String? breedSize;
  final String? petType;
  final String? lifeStage;
  final String? unitSize;
  final String? unitType;
  final Object? price;

  /// Maximum retail price, shown struck through when above [price].
  final Object? mrp;

  /// Pack sizes the product comes in (from the product details response).
  final List<ProductVariant> variants;

  /// Business-defined product name shown in cards.
  String get cardTitle => [brand, name, flavour, lifeStage, petType, category]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' ');

  /// Card metadata contains only the two remaining display values.
  String get cardMeta => [
        unitLabel,
        if (price != null && price.toString().trim().isNotEmpty) '₹$price',
      ]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join('   ');

  String get unitLabel {
    final size = unitSize?.trim() ?? '';
    final type = unitType?.trim() ?? '';
    if (size.isEmpty) return type;
    if (type.isEmpty || size.toLowerCase().contains(type.toLowerCase())) {
      return size;
    }
    return '$size $type';
  }
}

/// One pack size of a product: its own id, size, price, MRP and images.
class ProductVariant {
  const ProductVariant({
    this.variantId,
    this.unitSize,
    this.unitType,
    this.price,
    this.mrp,
    this.images = const [],
    this.isDefault = false,
  });

  final String? variantId;
  final String? unitSize;
  final String? unitType;
  final Object? price;
  final Object? mrp;
  final List<String> images;
  final bool isDefault;

  String get unitLabel =>
      Product(name: '', unitSize: unitSize, unitType: unitType).unitLabel;
}

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

class ProductFilters {
  const ProductFilters({
    this.query = '',
    this.brandName,
    this.productType,
    this.petType,
    this.additionalParameters = const {},
  });

  final String query;
  final String? brandName;
  final String? productType;
  final String? petType;
  final Map<String, String> additionalParameters;

  Map<String, String> get queryParameters => {
        ...additionalParameters,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (brandName != null && brandName!.isNotEmpty) 'brandName': brandName!,
        if (productType != null && productType!.isNotEmpty)
          'productType': productType!,
        if (petType != null && petType!.isNotEmpty) 'petType': petType!,
      };
}
