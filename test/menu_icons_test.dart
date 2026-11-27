import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/domain/entities/models.dart';
import 'package:petcare_services/presentation/shared/widgets/menu_icons.dart';

void main() {
  IconData icon(String name, {String? backend, bool sub = false}) =>
      menuIconFor(MenuItem(code: name, name: name, icon: backend),
          isSubmenu: sub);

  test('a recognised backend icon wins', () {
    expect(icon('Inventory', backend: 'fas fa-paw'), Icons.pets_rounded);
  });

  test('otherwise the menu name picks the icon', () {
    expect(icon('Inventory', backend: 'fa-unknown-thing'),
        Icons.inventory_2_rounded);
    expect(icon('Product Management'), Icons.shopping_bag_rounded);
    expect(icon('Create Order'), Icons.add_shopping_cart_rounded);
    expect(icon('Order Management'), Icons.receipt_long_rounded);
    expect(icon('Brands'), Icons.verified_rounded);
    expect(icon('Categories'), Icons.category_rounded);
    expect(icon('Offers'), Icons.local_offer_rounded);
    expect(icon('Vouchers'), Icons.confirmation_number_rounded);
  });

  test('unknown names fall back', () {
    expect(icon('Zzz'), Icons.folder_rounded);
    expect(icon('Zzz', sub: true), Icons.label_outline_rounded);
  });
}
