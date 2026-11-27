import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/domain/entities/models.dart';
import 'package:petcare_services/domain/repositories/admin_module_repository.dart';
import 'package:petcare_services/presentation/home/views/admin_module_screen.dart';

void main() {
  const data = AdminModuleData(
    columns: [AdminModuleColumn('name', 'Name')],
    records: [
      {'name': 'Royal Canin Kibble'},
      {'name': 'Whiskas Tuna'},
    ],
  );

  test('narrows loaded records by name instantly, case-insensitive', () {
    expect(narrowAdminData(data, 'kib').records, [
      {'name': 'Royal Canin Kibble'}
    ]);
    expect(narrowAdminData(data, '  ').records, hasLength(2));
    expect(narrowAdminData(data, 'zzz').records, isEmpty);
  });

  test('narrows product cards with their records', () {
    final products = AdminModuleData(
      columns: data.columns,
      records: data.records,
      products: [
        for (final r in data.records)
          AdminProduct(record: r, product: Product(name: r['name'] as String)),
      ],
    );
    final narrowed = narrowAdminData(products, 'tuna');
    expect(narrowed.products!.single.product.name, 'Whiskas Tuna');
    expect(narrowed.records.single['name'], 'Whiskas Tuna');
  });
}
