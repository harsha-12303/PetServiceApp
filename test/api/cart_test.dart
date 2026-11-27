import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/api/petwork_api.dart';

void main() {
  group('variantIdOf', () {
    test('prefers the default variant, then the first, then the record', () {
      expect(
          variantIdOf({
            'variants': [
              {'variantId': 'A'},
              {'variantId': 'B', 'isDefault': true}
            ]
          }),
          'B');
      expect(
          variantIdOf({
            'variants': [
              {'varientId': 'A'},
              {'variantId': 'B'}
            ]
          }),
          'A');
      expect(variantIdOf({'id': 7}), '7');
      expect(variantIdOf({'name': 'x'}), isNull);
    });

    test('fills the first id placeholder, case-insensitively', () {
      expect(
          fillVariantPlaceholder(
              'products/{version}/variants/{VariantId}/x/{id}', 'a b'),
          'products/{version}/variants/a%20b/x/{id}');
    });
  });

  group('parseCart', () {
    test('nested variant, string prices, image and size', () {
      final cart = parseCart({
        'data': {
          'items': [
            {
              'quantity': '2',
              'variant': {
                'id': 'V1',
                'unitSize': '500',
                'unitType': 'g',
                'finalPrice': '₹660',
                'mrp': 'Rs. 700.50',
                'subImages': ['https://x/sub.png'],
                'mainImage': 'https://x/main.png',
                'product': {'productName': 'Kibble'},
              },
            },
            {'variantId': 'V2', 'qty': 0, 'price': 10},
          ],
          'deliveryCharge': '₹40',
          'handlingFee': 0,
          'grandTotal': '1360',
        },
      });
      final line = cart.lines.single;
      expect(line.variantId, 'V1');
      expect(line.quantity, 2);
      expect(line.name, 'Kibble');
      expect(line.size, '500 g');
      expect(line.price, 660);
      expect(line.mrp, 700.5);
      expect(line.imageUrl, 'https://x/main.png');
      expect(cart.quantityOf('V1'), 2);
      expect(cart.quantityOf('V2'), 0);
      expect(cart.charges.map((c) => (c.label, c.amount)),
          [('Delivery charge', 40.0)]);
      expect(cart.grandTotal, 1360);
    });

    test('flat lines under records, top level wins for totals', () {
      final cart = parseCart({
        'records': [
          {
            'cartItems': [
              {
                'varientId': 'A',
                'count': 1,
                'name': 'Toy',
                'size': '1 pc',
                'unit': 'pc',
                'sellingPrice': 99
              },
            ],
            'total': 99,
            'gst': 5,
          }
        ],
        'total': 104,
      });
      expect(cart.lines.single.variantId, 'A');
      expect(cart.lines.single.size, '1 pc');
      expect(cart.grandTotal, 104);
      expect(cart.charges.single.label, 'GST');
    });

    test('a bare list and duplicates', () {
      final cart = parseCart([
        {'variantId': 'A', 'quantity': 1},
        {'variantId': 'A', 'quantity': 1},
      ]);
      expect(cart.lines, hasLength(1));
      expect(cart.grandTotal, isNull);
    });

    test('loose numbers', () {
      expect(parseLooseNumber('₹1,299.00'), 1299);
      expect(parseLooseNumber('-12'), -12);
      expect(parseLooseNumber(null), isNull);
    });
  });

  group('cart actions', () {
    final table = TableBlueprint.fromJson({
      'actions': [
        {'action': 'create', 'blueprintApi': 'x/form', 'dataApi': 'x'},
        {
          'action': 'cart',
          'iconName': 'fa-shopping-cart',
          'dataApi': 'orders/{version}/api/cart'
        },
      ],
      'rowLevelactions': [
        {'action': 'view', 'dataApi': 'x/{variantId}', 'display': false},
        {
          'action': 'add',
          'iconName': 'fa-cart-plus',
          'createApi': 'orders/{version}/api/cart/'
        },
      ],
    });

    test('finds add and header actions', () {
      final a = CartActions.from(table);
      expect(a.addAction!.createApi, 'orders/{version}/api/cart/');
      expect(a.readApi, 'orders/{version}/api/cart');
      expect(a.writeApi, 'orders/{version}/api/cart/');
      expect(ProductService.viewActionOf(table)!.action, 'view');
    });

    test('remove path drops the trailing slash', () {
      expect(removePath('/orders/v1/api/cart/', 'V 1'),
          '/orders/v1/api/cart/V%201');
    });
  });
}
