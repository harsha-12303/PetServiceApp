class CartLine {
  const CartLine({
    required this.variantId,
    required this.quantity,
    this.name,
    this.size,
    this.price,
    this.mrp,
    this.imageUrl,
    this.raw = const {},
  });

  final String variantId;
  final int quantity;
  final String? name;

  /// e.g. "500 g": unitSize plus unitType when not already in the text.
  final String? size;
  final double? price;
  final double? mrp;
  final String? imageUrl;
  final Map<String, dynamic> raw;

  double? get lineTotal => price == null ? null : price! * quantity;
}

class CartCharge {
  const CartCharge(this.label, this.amount);
  final String label;
  final double amount;
}

class Cart {
  const Cart({
    this.lines = const [],
    this.charges = const [],
    this.grandTotal,
    this.raw,
  });

  static const empty = Cart();

  final List<CartLine> lines;

  /// Only the non-zero ones (delivery, handling, tax, GST, discount).
  final List<CartCharge> charges;
  final double? grandTotal;
  final Object? raw;

  int quantityOf(String variantId) {
    for (final l in lines) {
      if (l.variantId == variantId) return l.quantity;
    }
    return 0;
  }

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  double get subtotal => lines.fold(0, (sum, l) => sum + (l.lineTotal ?? 0));

  bool get isEmpty => lines.isEmpty;
}
