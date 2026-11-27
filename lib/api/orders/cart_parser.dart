import 'cart_models.dart';
import 'product_service.dart' show variantIdKeys, firstIdIn;

// The cart response has no fixed shape: walk it and treat every object with a
// variant id and a quantity > 0 as a line.

const _maxDepth = 6;
const _lineIdKeys = ['variantId', 'varientId', 'variant_id'];
const _qtyKeys = ['quantity', 'qty', 'cartQuantity', 'count'];
const _nameKeys = ['productName', 'name', 'title', 'displayName'];
const _sizeKeys = ['unitSize', 'size', 'packSize', 'weight'];
const _unitKeys = ['unitType', 'unit'];
const _priceKeys = [
  'finalPrice',
  'unitPrice',
  'sellingPrice',
  'salePrice',
  'price'
];
const _mrpKeys = ['mrp', 'mrpPrice', 'maximumRetailPrice'];
const _totalKeys = ['grandTotal', 'totalAmount', 'total', 'payableAmount'];
const _chargeKeys = [
  ('Delivery charge', ['deliveryCharge', 'deliveryFee']),
  ('Handling charge', ['handlingCharge', 'handlingFee']),
  ('Tax', ['tax']),
  ('GST', ['gst']),
  ('Discount', ['discount']),
];
final _imageKey = RegExp('image|img|photo|picture|thumb', caseSensitive: false);

Cart parseCart(Object? body) {
  final lines = <CartLine>[];
  final seen = <String>{};
  void walk(Object? node, int depth) {
    if (depth > _maxDepth) return;
    if (node is List) {
      for (final item in node) {
        walk(item, depth + 1);
      }
    } else if (node is Map) {
      final line = _lineFrom(node);
      if (line != null) {
        if (seen.add(line.variantId)) lines.add(line);
        return;
      }
      for (final v in node.values) {
        walk(v, depth + 1);
      }
    }
  }

  walk(body, 0);

  final summary = _summarySource(body);
  final charges = <CartCharge>[];
  for (final (label, keys) in _chargeKeys) {
    final amount = parseLooseNumber(_first(summary, keys));
    if (amount != null && amount != 0) charges.add(CartCharge(label, amount));
  }
  return Cart(
    lines: lines,
    charges: charges,
    grandTotal: parseLooseNumber(_first(summary, _totalKeys)),
    raw: body,
  );
}

/// The top level merged over the first object among `data`, `cart` and
/// `records[0]` (top-level values win).
Map _summarySource(Object? body) {
  if (body is! Map) return const {};
  Map? nested;
  for (final candidate in [
    body['data'],
    body['cart'],
    _firstOf(body['records'])
  ]) {
    if (candidate is Map) {
      nested = candidate;
      break;
    }
  }
  return {...?nested, ...body};
}

Object? _firstOf(Object? v) => v is List && v.isNotEmpty ? v.first : null;

CartLine? _lineFrom(Map obj) {
  final variant = obj['variant'] is Map ? obj['variant'] as Map : null;
  final id = firstIdIn(obj, _lineIdKeys) ??
      (variant == null ? null : firstIdIn(variant, variantIdKeys));
  if (id == null) return null;
  final qty = parseLooseNumber(_first(obj, _qtyKeys))?.toInt() ?? 0;
  if (qty <= 0) return null;

  final product = obj['product'] is Map
      ? obj['product'] as Map
      : (variant?['product'] is Map ? variant!['product'] as Map : null);
  final sources = <Map>[
    obj,
    if (variant != null) variant,
    if (product != null) product
  ];

  Object? lookup(List<String> keys) {
    for (final s in sources) {
      final v = _first(s, keys);
      if (v != null) return v;
    }
    return null;
  }

  return CartLine(
    variantId: id,
    quantity: qty,
    name: _text(lookup(_nameKeys)),
    size: _sizeText(_text(lookup(_sizeKeys)), _text(lookup(_unitKeys))),
    price: parseLooseNumber(lookup(_priceKeys)),
    mrp: parseLooseNumber(lookup(_mrpKeys)),
    imageUrl: _imageIn(sources),
    raw: Map<String, dynamic>.from(obj),
  );
}

String? _sizeText(String? size, String? unit) {
  if (size == null) return null;
  if (unit == null || size.toLowerCase().contains(unit.toLowerCase())) {
    return size;
  }
  return '$size $unit';
}

/// First URL under an image-like key, preferring keys containing "main".
String? _imageIn(List<Map> sources) {
  for (final preferMain in [true, false]) {
    for (final s in sources) {
      for (final e in s.entries) {
        final key = '${e.key}';
        if (!_imageKey.hasMatch(key)) continue;
        if (preferMain && !key.toLowerCase().contains('main')) continue;
        final url = _urlIn(e.value);
        if (url != null) return url;
      }
    }
  }
  return null;
}

String? _urlIn(Object? v) {
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is List) {
    for (final item in v) {
      final url = _urlIn(item);
      if (url != null) return url;
    }
  }
  if (v is Map) return _urlIn(v['url'] ?? v['src'] ?? v['imageUrl']);
  return null;
}

Object? _first(Map map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v != null && (v is! String || v.trim().isNotEmpty)) return v;
  }
  return null;
}

String? _text(Object? v) => v == null ? null : '$v'.trim();

/// Numbers may arrive as strings like "₹660", "₹1,299.00" or "Rs. 700.50":
/// keep only digits, `.` and `-`; if that isn't a number (a currency dot
/// like "Rs." leaves a stray `.`), take the first number in the text.
double? parseLooseNumber(Object? v) {
  if (v is num) return v.toDouble();
  if (v is! String) return null;
  final stripped = double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (stripped != null) return stripped;
  final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(v.replaceAll(',', ''));
  return m == null ? null : double.tryParse(m.group(0)!);
}
