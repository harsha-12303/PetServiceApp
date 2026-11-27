import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/api/petwork_api.dart';

PickedFile _file(String name) =>
    PickedFile(name: name, size: 3, bytes: [1, 2, 3]);

void main() {
  final form = FormBlueprint.fromJson({
    'editForm': [
      {'field': 'name', 'fieldType': 'textBox'},
      {'field': 'inStock', 'fieldType': 'checkBox'},
      {
        'field': 'brochure',
        'fieldType': 'fileUpload',
        'rules': [
          {'multiple': 'true'}
        ]
      },
      {
        'field': 'variants',
        'fieldType': 'repeatableGroup',
        'rules': [
          {
            'minItems': '1',
            'singleTrueField': 'isDefault',
            'uniqueBy': 'unitSize'
          }
        ],
        'childFields': [
          {
            'field': 'unitSize',
            'fieldType': 'textBox',
            'rules': [
              {'mandatory': 'true'}
            ]
          },
          {'field': 'isDefault', 'fieldType': 'checkBox'},
          {'field': 'mainImage', 'fieldType': 'fileUpload'},
          {
            'field': 'subImages',
            'fieldType': 'fileUpload',
            'rules': [
              {'multiple': 'true'}
            ]
          },
        ],
      },
      {
        'field': 'seo',
        'fieldType': 'nonrepeatableGroup',
        'childFields': [
          {'field': 'title', 'fieldType': 'textBox'},
          {'field': 'banner', 'fieldType': 'fileUpload'},
        ],
      },
    ],
  });

  FormValues values() => {
        'name': '  Kibble ',
        'inStock': true,
        'brochure': FileFieldValue(newFiles: [_file('a.pdf'), _file('b.pdf')]),
        'variants': [
          GroupRow(fromServer: true, values: {
            'unitSize': '500g',
            'isDefault': true,
            'mainImage': FileFieldValue(keptUrls: ['https://x/main.png']),
            'subImages': FileFieldValue(
                keptUrls: ['https://x/s1.png'], newFiles: [_file('s2.png')]),
          }),
          GroupRow(values: {
            'unitSize': '1kg',
            'isDefault': false,
            'mainImage': FileFieldValue(newFiles: [_file('m.png')]),
            'subImages':
                FileFieldValue(newFiles: [_file('x.png'), _file('y.png')]),
          }),
        ],
        'seo': GroupRow(values: {
          'title': ' Best ',
          'banner': FileFieldValue(newFiles: [_file('ban.jpg')])
        }),
      };

  test('a form with any file field is multipart', () {
    expect(form.usesMultipart, isTrue);
    expect(buildSaveBody(form, values()), isNot(isA<Map>()));
  });

  test('multipart part names', () {
    final data = buildMultipartBody(form.fields, values(),
        removedImages: ['https://x/old1.png', 'https://x/old2.png']);
    expect(data.files.map((e) => e.key), [
      'brochure',
      'brochure',
      'variants[0][subImages]',
      'variants[1][mainImage]',
      'variants[1][subImages]',
      'variants[1][subImages]',
      'seo[banner]',
    ]);
    final fields = data.fields;
    expect(fields.where((e) => e.key == 'removeImages').map((e) => e.value),
        ['https://x/old1.png', 'https://x/old2.png']);
    expect(fields.firstWhere((e) => e.key == 'name').value, 'Kibble');
    expect(fields.firstWhere((e) => e.key == 'inStock').value, 'true');
  });

  test('group JSON strings: kept URLs for server rows, no files for new rows',
      () {
    final data = buildMultipartBody(form.fields, values());
    final rows =
        jsonDecode(data.fields.firstWhere((e) => e.key == 'variants').value)
            as List;
    expect(rows[0], {
      'unitSize': '500g',
      'isDefault': true,
      'mainImage': 'https://x/main.png',
      'subImages': ['https://x/s1.png'],
    });
    expect(rows[1], {'unitSize': '1kg', 'isDefault': false});
    final seo = jsonDecode(data.fields.firstWhere((e) => e.key == 'seo').value);
    expect(seo, {'title': 'Best'});
  });

  test('server row with the single image removed sends null', () {
    final v = values();
    (v['variants'] as List<GroupRow>)[0].values['mainImage'] = FileFieldValue();
    final rows = jsonDecode(buildMultipartBody(form.fields, v)
        .fields
        .firstWhere((e) => e.key == 'variants')
        .value);
    expect((rows as List)[0]['mainImage'], isNull);
  });

  test('JSON body: trimmed text, nulls, no file fields, removeImages', () {
    final jsonForm = FormBlueprint.fromJson({
      'editForm': [
        {'field': 'name', 'fieldType': 'textBox'},
        {'field': 'note', 'fieldType': 'textBox'},
        {'field': 'brand', 'fieldType': 'dropDown'},
        {'field': 'active', 'fieldType': 'checkBox'},
      ],
    });
    expect(jsonForm.usesMultipart, isFalse);
    final body = buildSaveBody(
        jsonForm, {'name': ' A ', 'note': '', 'active': false},
        removedImages: ['https://x/1.png']);
    expect(body, {
      'name': 'A',
      'note': '',
      'brand': null,
      'active': false,
      'removeImages': ['https://x/1.png'],
    });
  });

  group('form logic', () {
    test('visibility criteria', () {
      bool vis(String c, Map<String, Object?> v) =>
          evaluateVisibility(c, (k) => v[k]);
      const c = "field.petType =='Cat' && field.productType == 'Food'";
      expect(vis(c, {'petType': 'Cat', 'productType': 'Food'}), isTrue);
      expect(vis(c, {'petType': 'Dog', 'productType': 'Food'}), isFalse);
      expect(vis("field.a == 'x' || field.b != 'y'", {'a': 'z', 'b': 'q'}),
          isTrue);
      expect(vis('petType > 3', {}), isFalse, reason: 'unparseable → hidden');
      expect(evaluateVisibility(null, (_) => null), isTrue);
    });

    test('dependent fields reset to their default', () {
      final fields = [
        BlueprintField.fromJson({'field': 'petType', 'fieldType': 'dropDown'}),
        BlueprintField.fromJson({
          'field': 'breed',
          'fieldType': 'dropDown',
          'valuesDependOnField': 'petType'
        }),
        BlueprintField.fromJson({
          'field': 'size',
          'fieldType': 'dropDown',
          'valuesDependOnField': 'breed',
          'rules': [
            {'default': 'M'}
          ]
        }),
      ];
      final next = applyFieldChange(fields,
          {'petType': 'Dog', 'breed': 'Pug', 'size': 'S'}, 'petType', 'Cat');
      expect(next, {'petType': 'Cat', 'breed': null, 'size': 'M'});
    });

    test('single true field', () {
      final group = form.fields.firstWhere((f) => f.field == 'variants');
      final rows = values()['variants'] as List<GroupRow>;
      setGroupChild(group, rows, 1, 'isDefault', true);
      expect(rows.map((r) => r.values['isDefault']), [false, true]);
    });

    test('validation keys group children as group.index.child', () {
      final v = values();
      final rows = v['variants'] as List<GroupRow>;
      rows[1].values['unitSize'] = '500G';
      rows.add(
          newGroupRow(form.fields.firstWhere((f) => f.field == 'variants')));
      final errors = validateForm(form.fields, v);
      expect(errors['variants.1.unitSize'], contains('unique'));
      expect(errors['variants.2.unitSize'], contains('required'));
    });

    test('prefill from a server record', () {
      final v = initialValues(form.fields, {
        'name': 'Kibble',
        'inStock': 'true',
        'variants': [
          {
            'unitSize': '500g',
            'mainImage': 'https://x/m.png',
            'subImages': ['https://x/a.png']
          },
        ],
      });
      final row = (v['variants'] as List<GroupRow>).single;
      expect(row.fromServer, isTrue);
      expect((row.values['subImages'] as FileFieldValue).keptUrls,
          ['https://x/a.png']);
      expect(v['inStock'], isTrue);
      expect((v['seo'] as GroupRow).fromServer, isFalse);
    });
  });
}
