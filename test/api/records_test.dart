import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/api/petwork_api.dart';

void main() {
  group('extractRecords', () {
    test('bare array or {records}', () {
      expect(
          extractRecords([
            {'a': 1}
          ]),
          [
            {'a': 1}
          ]);
      expect(
          extractRecords({
            'records': [
              {'a': 1},
              'junk'
            ]
          }),
          [
            {'a': 1}
          ]);
    });

    test('anything else is empty', () {
      expect(extractRecords({'items': []}), isEmpty);
      expect(extractRecords('text'), isEmpty);
      expect(extractRecords(null), isEmpty);
    });
  });

  group('computeHasNext', () {
    final full = List.generate(24, (i) => {'i': i});

    test('hasNext bool wins', () {
      expect(
          computeHasNext({'hasNext': false, 'totalPages': 9}, 0, 24), isFalse);
      expect(computeHasNext({'hasNext': true}, 0, 3), isTrue);
    });

    test('then totalPages', () {
      expect(computeHasNext({'totalPages': 3}, 1, 24), isTrue);
      expect(computeHasNext({'totalPages': 3}, 2, 24), isFalse);
    });

    test('then total', () {
      expect(computeHasNext({'total': 49}, 1, 24), isTrue);
      expect(computeHasNext({'total': 48}, 1, 24), isFalse);
    });

    test('then a full page', () {
      expect(computeHasNext(full, 0, full.length), isTrue);
      expect(computeHasNext({'records': []}, 0, 23), isFalse);
    });
  });

  group('unwrapRecord', () {
    const product = {'productId': 'P1', 'name': 'Kibble'};

    test('all supported shapes', () {
      expect(unwrapRecord(product), product);
      expect(unwrapRecord([product]), product);
      expect(
          unwrapRecord({
            'records': [product]
          }),
          product);
      expect(unwrapRecord({'record': product}), product);
      expect(unwrapRecord({'data': product}), product);
    });

    test('empty shapes', () {
      expect(unwrapRecord([]), isNull);
      expect(unwrapRecord({'records': []}), isNull);
      expect(unwrapRecord(null), isNull);
    });
  });

  group('filters', () {
    test('only trimmed, non-empty values', () {
      expect(activeFilters({'q': '  dog ', 'brandName': '', 'petType': null}),
          {'q': 'dog'});
    });

    test('text applies from rules.minSize', () {
      final f = BlueprintField.fromJson({
        'field': 'q',
        'fieldType': 'textBox',
        'rules': [
          {'minSize': '2', 'maxSize': '100'}
        ],
      });
      expect(textFilterApplies(f, ' a '), isFalse);
      expect(textFilterApplies(f, 'ab'), isTrue);
    });

    test('LatestRequestGuard drops stale responses', () async {
      final guard = LatestRequestGuard();
      final slow = guard.run(
          () => Future.delayed(const Duration(milliseconds: 20), () => 'old'));
      final fast = guard.run(() async => 'new');
      expect(await fast, 'new');
      expect(await slow, isNull);
    });
  });

  group('blueprint models', () {
    test('action blueprint key casing and labels', () {
      final a = BlueprintAction.fromJson({
        'action': 'edit',
        'displayName': 'fa-edit',
        'iconToolTip': 'Edit product',
        'bluePrintAPI': 'products/blueprint/{version}/productEditForm',
        'display': 'false',
      });
      expect(a.blueprintApi, 'products/blueprint/{version}/productEditForm');
      expect(a.label, 'Edit product');
      expect(a.faIcon, 'fa-edit');
      expect(a.isEdit, isTrue);
      expect(a.display, isFalse);
    });

    test('dropdown option mapping skips rows without a code', () {
      final f = BlueprintField.fromJson({
        'field': 'productType',
        'fieldType': 'dropDown',
        'dropdownCode': 'productType',
        'dropdownValue': 'productTypeName',
      });
      expect(
          f.optionFrom(
              {'productType': 'Food', 'productTypeName': 'Pet food'})!.label,
          'Pet food');
      expect(f.optionFrom({'productType': 'Toy'})!.label, 'Toy');
      expect(f.optionFrom({'productTypeName': 'x'}), isNull);
    });

    test('search fields split into quick and more filters', () {
      final s = SearchBlueprint.fromJson({
        'searchForm': [
          {'field': 'q', 'fieldType': 'textBox', 'quickSearchFilter': true},
          {'field': 'brandName', 'fieldType': 'cascadeDropDown'},
          {'field': 'newField', 'fieldType': 'textBox'},
        ]
      });
      expect(s.quickFields.map((f) => f.field), ['q']);
      expect(s.moreFields.map((f) => f.field), ['brandName', 'newField']);
    });

    test('byte sizes', () {
      expect(parseByteSize('2MB'), 2 * 1024 * 1024);
      expect(parseByteSize('500 kb'), 500 * 1024);
      expect(parseByteSize('100'), 100);
      expect(parseByteSize('big'), isNull);
    });
  });
}
