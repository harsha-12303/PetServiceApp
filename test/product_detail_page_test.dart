import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/data/mappers/product_record_mapper.dart';
import 'package:petcare_services/domain/entities/models.dart';
import 'package:petcare_services/domain/repositories/catalog_repository.dart';
import 'package:petcare_services/presentation/orders/views/product_detail_screen.dart';

class _Catalog implements CatalogRepository {
  _Catalog(this.detail);
  final Product detail;
  final added = <String>[];

  @override
  Future<Product> getProductDetail(
          {required String bearerToken, required String variantId}) async =>
      detail;
  @override
  Future<void> addToCart(
          {required String bearerToken,
          required String variantId,
          required int quantity}) async =>
      added.add(variantId);
  @override
  Future<List<CartItem>> getCartItems({required String bearerToken}) async =>
      const [];
  @override
  Future<void> removeFromCart(
      {required String bearerToken, required String variantId}) async {}
  @override
  Future<List<Product>> getProducts(
          {required String bearerToken,
          ProductFilters filters = const ProductFilters()}) async =>
      const [];
  @override
  Future<List<String>> getBrandNames({required String bearerToken}) async =>
      const [];
}

Future<_Catalog> _open(WidgetTester tester, Product detail) async {
  // A phone-sized screen (400 x 900 logical pixels).
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1200, 2700);
  addTearDown(tester.view.reset);
  final catalog = _Catalog(detail);
  await tester.pumpWidget(MaterialApp(
    home: ProductDetailScreen(
      product: Product(name: detail.name, variantId: 'V1'),
      bearerToken: 't',
      catalogRepository: catalog,
    ),
  ));
  await tester.pumpAndSettle();
  return catalog;
}

void main() {
  testWidgets('short description: no More button', (tester) async {
    await _open(
        tester,
        const Product(
            name: 'Kibble', variantId: 'V1', description: 'Two\nlines.'));
    expect(find.text('About this product'), findsOneWidget);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('long description: More expands, Less collapses',
      (tester) async {
    await _open(
        tester,
        Product(
            name: 'Kibble',
            variantId: 'V1',
            description: List.filled(12, 'A line of text.').join('\n')));
    final text = find.textContaining('A line of text.');
    await tester.scrollUntilVisible(find.text('More'), 200);
    await tester.ensureVisible(find.text('More'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(text).maxLines, 5);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(text).maxLines, isNull);
    expect(find.text('Less'), findsOneWidget);
  });

  testWidgets('images swipe left/right with dots and a counter',
      (tester) async {
    await _open(
        tester,
        const Product(name: 'Kibble', variantId: 'V1', imageUrls: [
          'https://x.test/1.png',
          'https://x.test/2.png',
          'https://x.test/3.png',
        ]));
    expect(find.text('1/3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-250, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(250, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('picking a size switches price, discount and cart variant',
      (tester) async {
    final catalog = await _open(
      tester,
      productFromRecord({
        'productName': 'Kibble',
        'variantId': 'V1',
        'variants': [
          {
            'variantId': 'V1',
            'unitSize': '1',
            'unitType': 'kg',
            'finalPrice': 450,
            'mrpPrice': 500,
            'isDefault': true,
          },
          {
            'variantId': 'V3',
            'unitSize': '3',
            'unitType': 'kg',
            'finalPrice': 1200,
            'mrpPrice': 1600,
          },
        ],
      }),
    );
    expect(find.text('Select size'), findsOneWidget);
    expect(find.text('₹ 450'), findsWidgets);
    expect(find.text('10% off'), findsWidgets);

    await tester.tap(find.text('3 kg'));
    await tester.pumpAndSettle();
    expect(find.text('₹ 1200'), findsWidgets);
    expect(find.text('25% off'), findsWidgets);

    await tester.tap(find.text('Add +'));
    await tester.pumpAndSettle();
    expect(catalog.added, ['V3']);
  });
}
