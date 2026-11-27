import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petcare_services/core/network/api_config.dart';
import 'package:petcare_services/data/datasources/auth_remote_data_source.dart';
import 'package:petcare_services/data/datasources/catalog_remote_data_source.dart';
import 'package:petcare_services/data/repositories/admin_module_repository_impl.dart';
import 'package:petcare_services/data/repositories/auth_repository_impl.dart';
import 'package:petcare_services/data/repositories/catalog_repository_impl.dart';
import 'package:petcare_services/domain/repositories/cart_quantity_store.dart';
import 'package:petcare_services/domain/repositories/admin_module_repository.dart';
import 'package:petcare_services/domain/entities/models.dart';
import 'package:petcare_services/domain/repositories/auth_repository.dart';
import 'package:petcare_services/domain/repositories/catalog_repository.dart';
import 'package:petcare_services/domain/usecases/add_to_cart_use_case.dart';
import 'package:petcare_services/domain/usecases/get_brand_names_use_case.dart';
import 'package:petcare_services/domain/usecases/get_cart_items_use_case.dart';
import 'package:petcare_services/domain/usecases/get_products_use_case.dart';
import 'package:petcare_services/presentation/app.dart';
import 'package:petcare_services/presentation/home/views/admin_module_screen.dart';
import 'package:petcare_services/presentation/shared/widgets/search_filter_panel.dart';
import 'package:petcare_services/presentation/orders/viewmodels/cart_view_model.dart';
import 'package:petcare_services/presentation/orders/viewmodels/create_order_view_model.dart';
import 'package:petcare_services/presentation/orders/views/product_detail_screen.dart';
import 'package:petcare_services/presentation/orders/views/create_order_screen.dart';

void main() {
  testWidgets('Product Create Save posts after form errors are corrected',
      (tester) async {
    final writes = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        writes.add(request);
        if (writes.length == 1) {
          return http.Response(
              jsonEncode({
                'detail': [
                  {
                    'loc': ['body', 'sku'],
                    'msg': 'SKU already exists'
                  },
                ],
              }),
              422);
        }
        return http.Response('', 201);
      }
      final body = switch (request.url.path) {
        '/products/api/blueprint/productsDataTable' => {
            'dataApi': '/products-list',
            'rowLevelActions': [
              {'action': 'edit', 'blueprintApi': '/product-form'},
            ],
          },
        '/products-list' => {'records': []},
        '/product-form' => {
            'createApi': 'products/platform/{version}/api/products',
            'editForm': [
              {'field': 'sku', 'displayName': 'Product SKU', 'required': true},
              {
                'field': 'hsnCode',
                'displayName': 'HSN Code',
                'rules': [
                  {'mandatory': true, 'minSize': '8', 'maxSize': '8'},
                ],
              },
            ],
          },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response(jsonEncode(body), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const item =
        MenuItem(code: 'productManagement', name: 'Product Management');
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: item,
        load: () => repository.load('token', item),
        loadCreateForm: (config) => repository.loadCreateForm('token', config),
        createRecord: (form, values) =>
            repository.createRecord('token', form, values),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('Enter Product SKU'), findsOneWidget);

    final sku = find.byType(TextFormField).first;
    await tester.enterText(sku, 'FISH-1');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes.single.url.path, '/products/platform/v1/api/products');
    expect(writes.single.body, contains('name="sku"\r\n\r\nFISH-1'));
    expect(writes.single.body, isNot(contains('name="hsnCode"')));
    expect(find.text('sku: SKU already exists'), findsOneWidget);

    await tester.enterText(sku, 'FISH-2');
    await tester.enterText(find.byType(TextFormField).last, '2309');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes.last.body, contains('name="hsnCode"\r\n\r\n2309'));
    expect(find.text('Record saved'), findsOneWidget);
  });

  test('Product Create posts multipart variant metadata and images', () async {
    final writes = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        writes.add(request);
        return http.Response('', 201);
      }
      final body = switch (request.url.path) {
        '/products/api/blueprint/productsDataTable' => {
            'rowLevelActions': [
              {'action': 'edit', 'blueprintApi': '/product-form'},
            ],
          },
        '/product-form' => {
            'createApi': 'products/platform/{version}/api/products',
            'dataApi': 'products/platform/{version}/api/products/{recordId}',
            'editForm': [
              {'field': 'productName'},
              {
                'field': 'variants',
                'fieldType': 'repeatableGroup',
                'childFields': [
                  {'field': 'sku'},
                  {'field': 'mainImage', 'fieldType': 'fileUpload'},
                  {
                    'field': 'subImages',
                    'fieldType': 'fileUpload',
                    'rules': [
                      {'multiple': true, 'maxSize': '5MB'}
                    ],
                  },
                ],
              },
            ],
          },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response(jsonEncode(body), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    final configuration = await repository.loadConfiguration(
      'token',
      const MenuItem(code: 'productManagement', name: 'Product Management'),
    );
    final form = await repository.loadCreateForm('token', configuration);
    expect(form.multipart, isTrue);
    expect(form.groups.single.fields.last.multipleFiles, isTrue);
    expect(form.groups.single.fields.last.maxFileBytes, 5 * 1024 * 1024);
    ModuleFormFile image(String name) =>
        ModuleFormFile(name, Uint8List.fromList([1, 2, 3]), 'image/png');
    await repository.createRecord('token', form, {
      'productName': 'Ocean Fish',
      'variants': <Map<String, Object?>>[
        {
          'sku': 'FISH-100',
          'mainImage': [image('front.png')],
          'subImages': [image('side.png'), image('back.png')],
        },
        {
          'sku': 'FISH-200',
          'mainImage': [image('large.png')]
        },
      ],
    });
    final request = writes.single;
    expect(request.url.path, '/products/platform/v1/api/products');
    expect(request.headers['authorization'], 'Bearer token');
    expect(request.headers['content-type'], startsWith('multipart/form-data;'));
    expect(request.body, contains('name="productName"\r\n\r\nOcean Fish'));
    expect(request.body, contains('[{"sku":"FISH-100"},{"sku":"FISH-200"}]'));
    expect(request.body,
        contains('name="variants[0][mainImage]"; filename="front.png"'));
    expect(request.body,
        contains('name="variants[0][subImages]"; filename="side.png"'));
    expect(request.body,
        contains('name="variants[0][subImages]"; filename="back.png"'));
    expect(request.body,
        contains('name="variants[1][mainImage]"; filename="large.png"'));
    expect(request.body, contains('content-type: image/png'));
  });

  testWidgets('Order Management posts to the mapped Create endpoint',
      (tester) async {
    final writes = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        writes.add(request);
        return http.Response('', 201);
      }
      final payload = switch (request.url.path) {
        '/order-table' => {
            'dataApi': '/order-list',
            'actions': [
              {'action': 'createOrder', 'blueprintApi': '/order-create-form'},
            ],
            'rowLevelActions': [
              {'action': 'Add Item', 'blueprintApi': '/row-only-form'},
            ],
          },
        '/order-list' => {'records': []},
        '/order-create-form' => {
            'createApi': '/orders/platform/{version}/api/orders/{recordId}',
            'mappings': {'recordId': 'orderNumber'},
            'createForm': [
              {'field': 'orderNumber', 'displayName': 'Order number'},
            ],
          },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response(jsonEncode(payload), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const item = MenuItem(
      code: 'orderManagement',
      name: 'Order Management',
      dataTableBlueprintUrl: '/order-table',
    );
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: item,
        load: () => repository.load('token', item),
        loadCreateForm: (config) => repository.loadCreateForm('token', config),
        createRecord: (form, values) =>
            repository.createRecord('token', form, values),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(
        find.text(
            'Enter the record identifier required by the Create endpoint.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ORD 42');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final request = writes.single;
    expect(request.url.path, '/orders/platform/v1/api/orders/ORD%2042');
    expect(request.headers['authorization'], 'Bearer token');
    expect(jsonDecode(request.body), {'orderNumber': 'ORD 42'});
    expect(find.text('Record saved'), findsOneWidget);
  });

  testWidgets('Product Management renders and runs its configured row actions',
      (tester) async {
    final requests = <String>[];
    const image = 'https://storage.googleapis.com/example/variant.webp';
    var productName = 'Ocean Fish';
    var deleted = false;
    final client = MockClient((request) async {
      final route = '${request.method} ${request.url.path}';
      requests.add(route);
      expect(request.headers['authorization'], 'Bearer token');
      final Object response;
      switch (route) {
        case 'GET /products/api/blueprint/productsDataTable':
          response = {
            'dataApi': '/management-products',
            'dataGrid': [
              {'field': 'productName', 'displayName': 'Product'},
            ],
            'rowLevelActions': [
              {
                'action': 'view',
                'displayName': 'View Product',
                'dataApi': '/management-detail/{variantId}'
              },
              {
                'action': 'edit',
                'displayName': 'Edit Product',
                'blueprintApi': '/management-form'
              },
              {
                'action': 'delete',
                'displayName': 'Remove Product',
                'dataApi': '/management-products/{recordId}',
                'mappings': {'recordId': 'sku'},
              },
            ],
          };
        case 'GET /management-products':
          response = [
            if (!deleted)
              {
                'productName': productName,
                'sku': 'SKU-42',
                'variants': [
                  {'variantId': 'VAR-41'},
                  {'variantId': 'VAR-42'},
                ],
              },
          ];
        case 'GET /management-detail/VAR-42':
          response = {'productName': 'Detail from API'};
        case 'GET /management-form':
          response = {
            'dataApi': 'products/platform/{version}/api/products/{recordId}',
            'mappings': {'recordId': 'sku'},
            'updateApi': '/legacy-product-updates/{recordId}',
            'updateMethod': 'PUT',
            'editForm': [
              {
                'field': 'productName',
                'displayName': 'Product name',
                'fieldType': 'textBox'
              },
              {
                'field': 'petType',
                'fieldType': 'radioButton',
                'values': [
                  {'radioValue': 'Cat'},
                  {'radioValue': 'Dog'}
                ],
              },
              for (final (pet, stage) in [('Cat', 'Kitten'), ('Dog', 'Puppy')])
                {
                  'field': 'lifeStage',
                  'fieldType': 'radioButton',
                  'valuesDependOnField': 'petType',
                  'visibilityCriteria': "field.petType == '$pet'",
                  'values': [
                    {'radioValue': stage}
                  ],
                },
              {
                'field': 'variants',
                'displayName': 'Sizes / Variants',
                'fieldType': 'repeatableGroup',
                'addButtonLabel': 'Add Size',
                'rules': [
                  {'minItems': '1', 'singleTrueField': 'isDefault'}
                ],
                'childFields': [
                  {'field': 'unitSize', 'displayName': 'Unit Size'},
                  {'field': 'mrpPrice'},
                  {
                    'field': 'finalPrice',
                    'displayName': 'Price',
                    'rules': [
                      {'maxValueField': 'mrpPrice'}
                    ],
                  },
                  {'field': 'isDefault', 'fieldType': 'checkBox'},
                  {'field': 'mainImage', 'fieldType': 'fileUpload'},
                ],
              },
            ],
          };
        case 'GET /products/platform/v1/api/products/SKU-42':
          response = {
            'productName': productName == 'Ocean Fish'
                ? 'Ocean Fish from API'
                : productName,
            'petType': 'Cat',
            'lifeStage': 'Kitten',
            'variants': [
              {
                'variantId': 'VAR-41',
                'unitSize': '100',
                'mrpPrice': 120,
                'finalPrice': 100,
                'isDefault': true,
                'mainImage': image,
              }
            ],
          };
        case 'POST /products/platform/v1/api/products/SKU-42':
          final payload = jsonDecode(request.body) as Map;
          productName = payload['productName'] as String;
          expect(payload['lifeStage'], 'Puppy');
          expect(payload['variants'], [
            {
              'variantId': 'VAR-41',
              'unitSize': '100',
              'mrpPrice': 120,
              'finalPrice': 90.5,
              'isDefault': true,
              'mainImage': image,
            }
          ]);
          return http.Response('', 204);
        case 'DELETE /management-products/SKU-42':
          deleted = true;
          return http.Response('', 204);
        default:
          throw StateError('Unexpected request: $route');
      }
      return http.Response(jsonEncode(response), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const item =
        MenuItem(code: 'productmanagements', name: 'Product Management');
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: item,
        load: () => repository.load('token', item),
        loadRecordDetails: (config, record, action) => repository
            .loadRecordDetails('token', config, record, rowAction: action),
        loadRowForm: (config, record, action) => repository
            .loadCreateForm('token', config, record: record, rowAction: action),
        createRecord: (form, values) =>
            repository.createRecord('token', form, values),
        runRowAction: (config, record, action) =>
            repository.runRowAction('token', config, record, action),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VAR-42'));
    await tester.pumpAndSettle();
    expect(find.text('Detail from API'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ocean Fish'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Product'), findsOneWidget);
    expect(find.text('Ocean Fish from API'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Product'));
    await tester.pumpAndSettle();
    expect(find.text('Ocean Fish from API'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Updated Fish');
    expect(find.text('Kitten'), findsOneWidget);
    expect(find.text('Puppy'), findsNothing);
    await tester.tap(find.text('Dog'));
    await tester.pumpAndSettle();
    expect(find.text('Kitten'), findsNothing);
    await tester.tap(find.text('Puppy'));
    final priceField = find.widgetWithText(TextFormField, 'Price');
    await tester.ensureVisible(priceField);
    await tester.enterText(priceField, '90.5');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Updated Fish'), findsOneWidget);
    expect(
        requests.where((request) =>
            request == 'GET /products/platform/v1/api/products/SKU-42'),
        hasLength(2));

    await tester.tap(find.byTooltip('Remove Product'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No records found.'), findsOneWidget);
    expect(
        requests,
        containsAllInOrder([
          'GET /management-detail/VAR-42',
          'GET /products/platform/v1/api/products/SKU-42',
          'POST /products/platform/v1/api/products/SKU-42',
          'DELETE /management-products/SKU-42',
        ]));
  });

  testWidgets('Vouchers runs non-CRUD blueprint actions on the selected row',
      (tester) async {
    var archived = false;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      final Object payload;
      switch ('${request.method} ${request.url.path}') {
        case 'GET /vouchers-table':
          payload = {
            'dataApi': '/vouchers-list',
            'dataGrid': [
              {'field': 'status', 'displayName': 'Status'},
            ],
            'actions': [
              {
                'action': 'archive',
                'displayName': 'Wrong scope',
                'deleteApi': '/wrong'
              },
            ],
            'rowActions': [
              {
                'action': 'archive',
                'displayName': 'Archive voucher',
                'dataApi': '/vouchers/{recordId}/archive',
                'httpMethod': 'PATCH',
                'mappings': {'recordId': 'voucherCode'},
                'payload': {'status': 'Archived'},
                'payloadMapping': {'code': 'voucherCode'},
              },
              {
                'action': 'view',
                'displayName': 'Inspect voucher',
                'blueprintApi': '/voucher-view'
              },
              {
                'action': 'delete',
                'displayName': 'Hidden action',
                'dataApi': '/hidden',
                'display': false
              },
            ],
          };
        case 'GET /vouchers-list':
          payload = [
            {
              'id': 1,
              'voucherCode': 'SAVE42',
              'status': archived ? 'Archived' : 'Active'
            },
          ];
        case 'GET /voucher-view':
          payload = {
            'viewForm': [
              {
                'field': 'voucherCode',
                'displayName': 'Voucher',
                'editable': false
              },
            ],
          };
        case 'PATCH /vouchers/SAVE42/archive':
          expect(jsonDecode(request.body),
              {'status': 'Archived', 'code': 'SAVE42'});
          archived = true;
          return http.Response('', 204);
        default:
          throw StateError(
              'Unexpected request: ${request.method} ${request.url}');
      }
      return http.Response(jsonEncode(payload), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const voucherMenu = MenuItem(
      code: 'vouchers',
      name: 'Vouchers',
      dataTableBlueprintUrl: '/vouchers-table',
    );
    await tester.pumpWidget(PetCareApp(
      authRepository: _FakeAuthRepository(),
      catalogRepository: _FakeCatalogRepository(),
      cartQuantityStore: _FakeCartQuantityStore(),
      adminModuleRepository: repository,
      initialSession: const AppSession(
        tokens:
            AuthTokens(bearerToken: 'token', refreshToken: '', expiresIn: ''),
        menuItems: [
          MenuItem(
              code: 'discounts', name: 'Discounts', children: [voucherMenu]),
        ],
      ),
    ));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vouchers'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Wrong scope'), findsNothing);
    expect(find.byTooltip('Hidden action'), findsNothing);
    await tester.tap(find.byTooltip('Inspect voucher'));
    await tester.pumpAndSettle();
    expect(find.text('SAVE42'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive voucher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(archived, isFalse);
    await tester.tap(find.byTooltip('Archive voucher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('Offers loads dependent choices and saves a numeric discount',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final optionRequests = <String>[];
    final listQueries = <Map<String, String>>[];
    Map? saved;
    List<Map<String, Object?>> fields({required bool editing}) => [
          for (final (field, label, choices) in [
            ('productType', 'Product Type', ['Food']),
            ('petType', 'Pet Type', ['Cat', 'Dog']),
          ])
            {
              'field': field,
              'displayName': label,
              'fieldType': editing ? 'radioButton' : 'dropDown',
              'values': [
                for (final choice in choices) {'radioValue': choice}
              ],
              'staticDropDownValues': [
                for (final choice in choices) {field: choice},
              ],
              'rules': [
                {'mandatory': true}
              ],
            },
          for (final pet in ['Cat', 'Dog'])
            for (final (field, label, endpoint) in [
              ('brandCode', 'Brand', 'brands'),
              ('categoryCode', 'Category', 'categories'),
            ])
              {
                'field': field,
                'displayName': label,
                'fieldType': 'cascadeDropDown',
                'quickSearchFilter': false,
                'visibilityCriteria':
                    ' field.petType ==\'$pet\' && field.productType == \'Food\'',
                'valuesDependOnField': 'petType,productType',
                'api': '/options/$endpoint?petType=$pet&productType=Food',
                'rules': [
                  {'mandatory': editing}
                ],
              },
          if (editing)
            {
              'field': 'discountPercent',
              'displayName': 'Discount %',
              'fieldType': 'textBox',
              'rules': [
                {'mandatory': true, 'maxSize': '6'}
              ],
            },
        ];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST') {
        expect(path, '/offer-writes');
        saved = jsonDecode(request.body) as Map;
        return http.Response('', 201);
      }
      final pet = request.url.queryParameters['petType'];
      if (path.startsWith('/options/')) {
        optionRequests.add('$path:$pet');
      }
      if (path == '/offer-list') listQueries.add(request.url.queryParameters);
      final Object response = switch (path) {
        '/offer-table' => {
            'dataApi': '/offer-list',
            'defaultDisplayMode': 'table',
            'dataGrid': [
              {'field': 'discountPercent', 'displayName': 'Discount %'},
            ],
            'actions': [
              {
                'action': 'Add Offer',
                'displayName': 'Create Offer',
                'blueprintApi': '/offer-form'
              },
            ],
          },
        '/offer-search' => {'searchForm': fields(editing: false)},
        '/offer-form' => {
            'editForm': fields(editing: true),
            'createApi': '/offer-writes',
          },
        '/options/brands' => [
            {'brandCode': '$pet-brand'},
          ],
        '/options/categories' => [
            {'categoryCode': '$pet-category'},
          ],
        '/offer-list' => {
            'records': [if (saved != null) saved],
          },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response(jsonEncode(response), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const item = MenuItem(
      code: 'offers',
      name: 'Offers',
      dataTableBlueprintUrl: '/offer-table',
      searchBlueprintUrl: '/offer-search',
    );
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: item,
        load: () => repository.load('token', item),
        loadFiltered: (filters) =>
            repository.load('token', item, filters: filters),
        loadSearchFields: () => repository.loadSearchFilters('token', item),
        loadCreateForm: (config) => repository.loadCreateForm('token', config),
        createRecord: (form, values) =>
            repository.createRecord('token', form, values),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(optionRequests, isEmpty);
    expect(find.text('Nothing here yet.'), findsOneWidget);

    Future<void> select(Finder dropdown, String option) async {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await select(find.byKey(const ValueKey('productType')), 'Food');
    await select(find.byKey(const ValueKey('petType')), 'Cat');
    expect(optionRequests, isEmpty);
    await tester.tap(find.byTooltip('Advanced search'));
    await tester.pumpAndSettle();
    expect(optionRequests, ['/options/brands:Cat', '/options/categories:Cat']);
    await select(
      find
          .descendant(
            of: find.byType(SearchFilterPanel),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .at(2),
      'Cat-brand',
    );
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(listQueries.last['brandCode'], 'Cat-brand');
    await select(find.byKey(const ValueKey('petType')), 'Dog');
    expect(listQueries.last.containsKey('brandCode'), isFalse);

    await tester.tap(find.text('Create Offer'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Food'));
    await tester.tap(find.text('Dog'));
    await tester.pumpAndSettle();
    expect(optionRequests.sublist(optionRequests.length - 2),
        ['/options/brands:Dog', '/options/categories:Dog']);
    await select(
        find.byType(DropdownButtonFormField<String>).first, 'Dog-brand');
    await select(
        find.byType(DropdownButtonFormField<String>).last, 'Dog-category');
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, {
      'productType': 'Food',
      'petType': 'Dog',
      'brandCode': 'Dog-brand',
      'categoryCode': 'Dog-category',
      'discountPercent': 12.5,
    });
    expect(find.text('12.5'), findsOneWidget);
  });

  testWidgets('Categories uses configured list, search, create and row routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    var added = false;
    var removed = false;
    var categoryCode = 'DRY-DETAIL';
    final client = MockClient((request) async {
      requests.add(request);
      final Object payload;
      switch (request.url.path) {
        case '/category-table':
          payload = {
            'dataApi': '/category-rows',
            'defaultDisplayMode': 'table',
            'mappings': {'recordId': 'id'},
            'dataGrid': [
              {'field': 'id', 'display': false},
              {'field': 'petType', 'displayName': 'Pet Type'},
              {'field': 'categoryName', 'displayName': 'Category'},
              {'field': 'categoryCode', 'displayName': 'Category Code'},
            ],
            'actions': [
              {
                'action': 'Add Category',
                'displayName': 'Create',
                'blueprintApi': '/category-form'
              },
            ],
            'rowLevelactions': [
              {
                'action': 'edit',
                'displayName': 'Update',
                'blueprintApi': '/category-form'
              },
              {'action': 'delete', 'dataApi': '/category-record/{recordId}'},
            ],
          };
        case '/category-search':
          payload = {
            'searchForm': [
              {
                'field': 'petType',
                'displayName': 'Pet Type',
                'fieldType': 'dropDown',
                'staticDropDownValues': [
                  {'petType': 'Reptile'},
                ],
              },
              {'field': 'categoryName', 'displayName': 'Category Name'},
            ],
          };
        case '/category-form':
          payload = {
            'dataApi': '/category-record/{recordId}',
            'createApi': '/category-create',
            'editForm': [
              {
                'field': 'categoryCode',
                'displayName': 'Category Code',
                'required': true
              },
            ],
          };
        case '/category-create':
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'categoryCode': 'RE-01'});
          added = true;
          return http.Response('', 201);
        case '/category-record/42':
          if (request.method == 'DELETE') {
            removed = true;
            return http.Response('', 204);
          }
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {'categoryCode': 'DRY-UPDATED'});
            categoryCode = 'DRY-UPDATED';
            return http.Response('', 204);
          }
          expect(request.method, 'GET');
          payload = {'categoryCode': categoryCode};
        case '/category-rows':
          payload = {
            'records': [
              if (!removed)
                {
                  'id': 42,
                  'petType': 'Dog',
                  'categoryName': 'Dry Food',
                  'categoryCode': categoryCode
                },
              if (added)
                {
                  'id': 43,
                  'petType': 'Reptile',
                  'categoryName': 'Reptile Food',
                  'categoryCode': 'RE-01'
                },
            ],
          };
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
      return http.Response(jsonEncode(payload), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const categories = MenuItem(
      code: 'categories',
      name: 'Categories',
      dataTableBlueprintUrl: '/category-table',
      searchBlueprintUrl: '/category-search',
    );
    await tester.pumpWidget(PetCareApp(
      authRepository: _FakeAuthRepository(),
      catalogRepository: _FakeCatalogRepository(),
      cartQuantityStore: _FakeCartQuantityStore(),
      adminModuleRepository: repository,
      initialSession: const AppSession(
        tokens:
            AuthTokens(bearerToken: 'token', refreshToken: '', expiresIn: ''),
        menuItems: [
          MenuItem(
              code: 'inventory', name: 'Inventory', children: [categories]),
        ],
      ),
    ));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('CATEGORY CODE'), findsOneWidget);
    expect(find.text('42'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('categoryName')), 'food');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['categoryName'], 'food');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'RE-01');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Reptile Food'), findsOneWidget);

    await tester.tap(find.byTooltip('Update').first);
    await tester.pumpAndSettle();
    expect(find.text('DRY-DETAIL'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'DRY-UPDATED');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('DRY-UPDATED'), findsOneWidget);
    expect(
        requests.where((request) => request.method == 'PATCH').single.url.path,
        '/category-record/42');

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(removed, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(find.text('Dry Food'), findsNothing);
  });

  testWidgets(
      'Brands Create loads the action blueprint and refreshes after saving',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    var created = false;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      calls.add('${request.method} ${request.url.path}');
      final Object payload;
      switch (request.url.path) {
        case '/products/api/blueprint/brandsDataTable':
          payload = {
            'dataApi': 'catalog/platform/{version}/api/brands',
            'actions': [
              {
                'action': 'Add Brand',
                'displayName': 'Create',
                'blueprintApi': 'products/blueprint/{version}/brandsEditForm',
              },
            ],
          };
        case '/products/blueprint/v1/brandsEditForm':
          return http.Response('', 404);
        case '/products/api/blueprint/brandsEditForm':
          payload = {
            'createApi': 'products/platform/{version}/api/brands',
            'dataApi': 'products/platform/{version}/api/brands/{recordId}',
            'resetButton': true,
            'editForm': [
              {
                'field': 'brandCode',
                'displayName': 'Brand Code',
                'fieldType': 'textBox',
                'rules': [
                  {'mandatory': true, 'minSize': '1', 'maxSize': '255'},
                ],
              },
              {
                'field': 'brandName',
                'displayName': 'Brand Name',
                'fieldType': 'textBox',
                'rules': [
                  {'mandatory': false, 'maxSize': '100'},
                ],
              },
              {
                'field': 'productType',
                'displayName': 'Product Type',
                'fieldType': 'radioButton',
                'values': [
                  {'radioValue': 'Food'},
                  {'radioValue': 'Medicine'},
                  {'radioValue': 'Treats'},
                  {'radioValue': 'Accessories'},
                ],
                'rules': [
                  {'mandatory': true},
                ],
              },
              {
                'field': 'petType',
                'displayName': 'Pet Type',
                'fieldType': 'radioButton',
                'values': [
                  {'radioValue': 'Cat'},
                  {'radioValue': 'Dog'},
                ],
                'rules': [
                  {'mandatory': true},
                ],
              },
            ],
          };
        case '/products/platform/v1/api/brands':
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'brandCode': 'EX-001',
            'brandName': 'Example Brand',
            'productType': 'Treats',
            'petType': 'Dog',
          });
          created = true;
          return http.Response('', 201);
        case '/catalog/platform/v1/api/brands':
          payload = {
            'records': [
              if (created) {'brandName': 'Example Brand'},
            ],
          };
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
      return http.Response(jsonEncode(payload), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    const item = MenuItem(
      code: 'brands',
      name: 'Brands',
      dataTableBlueprintUrl: '/products/api/blueprint/brandsDataTable',
    );
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: item,
        load: () => repository.load('token', item),
        loadCreateForm: (config) => repository.loadCreateForm('token', config),
        createRecord: (form, values) =>
            repository.createRecord('token', form, values),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(calls.sublist(2), [
      'GET /products/blueprint/v1/brandsEditForm',
      'GET /products/api/blueprint/brandsEditForm',
    ]);
    final general = tester.getTopLeft(find.text('General Information'));
    final organize = tester.getTopLeft(find.text('Organize'));
    expect(organize.dx, greaterThan(general.dx));
    expect(organize.dy, general.dy);
    final createAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(createAppBar.backgroundColor, const Color(0xFF2D518F));
    expect(createAppBar.foregroundColor, Colors.white);
    await tester.binding.setSurfaceSize(const Size(390, 850));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Organize')).dy,
        greaterThan(tester.getTopLeft(find.text('General Information')).dy));
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Brand Code'), findsOneWidget);
    expect(find.text('Select Product Type'), findsOneWidget);
    expect(find.text('Select Pet Type'), findsOneWidget);
    expect(created, isFalse);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'EX-001');
    await tester.enterText(fields.last, 'Example Brand');
    await tester.tap(find.text('Food'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((choice) => choice.selected),
      isEmpty,
    );
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        isEmpty);
    await tester.enterText(fields.first, 'EX-001');
    await tester.enterText(fields.last, 'Example Brand');
    await tester.tap(find.text('Treats'));
    await tester.tap(find.text('Dog'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(find.text('Example Brand'), findsOneWidget);
    expect(calls.last, 'GET /catalog/platform/v1/api/brands');
  });

  testWidgets('Brands shows inline dropdowns and searches with their values',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = AdminModuleData(
      columns: [AdminModuleColumn('brandName', 'Brand')],
      records: [
        {'brandName': 'Royal Canin'}
      ],
    );
    final queries = <Map<String, String>>[];
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
        item: const MenuItem(code: 'brands', name: 'Brands'),
        load: () async => data,
        loadFiltered: (filters) async {
          queries.add(filters);
          return data;
        },
        loadSearchFields: () async => const [
          SearchFilterField(field: 'q', label: 'Brand name'),
          SearchFilterField(
            field: 'productType',
            label: 'Product Type',
            options: {'FOOD': 'Food'},
          ),
          SearchFilterField(
            field: 'petType',
            label: 'Pet Type',
            options: {'DOG': 'Dog'},
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    final productType = find.byKey(const ValueKey('productType'));
    final petType = find.byKey(const ValueKey('petType'));
    final search = find.byKey(const ValueKey('q'));
    expect(tester.getTopLeft(productType).dy, tester.getTopLeft(search).dy);
    expect(tester.getTopLeft(petType).dx,
        greaterThan(tester.getTopLeft(productType).dx));
    await tester.tap(productType);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.tap(petType);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'royal');
    await tester.pumpAndSettle();
    expect(
        queries.last, {'productType': 'FOOD', 'petType': 'DOG', 'q': 'royal'});

    await tester.binding.setSurfaceSize(const Size(390, 650));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(search).dy,
        greaterThan(tester.getTopLeft(productType).dy));
  });

  test('Create Order uses endpoints discovered in its module blueprints',
      () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      requests.add('${request.method} ${request.url.path}');
      final Object payload = switch (request.url.path) {
        '/order-table' => {
            'dataApi': '/catalog/{version}/configured-products',
            'rowLevelactions': [
              {
                'action': 'view',
                'dataApi': '/catalog/{version}/view/{variantId}'
              },
              {
                'action': 'addToCart',
                'createApi': '/orders/{version}/configured-add'
              },
            ],
            'pageLevelActions': [
              {
                'action': 'Cart',
                'dataApi': '/orders/{version}/configured-cart'
              },
            ],
          },
        '/order-search' => {
            'searchApi': '/catalog/{version}/configured-search'
          },
        '/catalog/v1/view/DOG-001' => {'productName': 'Kibble'},
        _ => [],
      };
      if (request.url.path == '/catalog/v1/configured-search') {
        expect(request.url.queryParameters['q'], 'k');
      }
      if (request.url.path == '/orders/v1/configured-add') {
        expect(
            jsonDecode(request.body), {'variantId': 'DOG-001', 'quantity': 1});
      }
      return http.Response(jsonEncode(payload), 200);
    });
    final modules = AdminModuleRepositoryImpl((_) async => [], client: client);
    final configuration = await modules.loadConfiguration(
      'token',
      const MenuItem(
        code: 'orderCreate',
        name: 'Create Order',
        dataTableBlueprintUrl: '/order-table',
        searchBlueprintUrl: '/order-search',
      ),
      includeSearchEndpoint: true,
    );
    expect(configuration.createApi, '/orders/{version}/configured-add');
    final catalog =
        CatalogRepositoryImpl(CatalogRemoteDataSource(client: client))
            .forModule(configuration);
    await catalog.getProducts(bearerToken: 'token');
    await catalog.getProducts(
        bearerToken: 'token', filters: const ProductFilters(query: 'k'));
    await catalog.getProductDetail(bearerToken: 'token', variantId: 'DOG-001');
    await catalog.addToCart(
        bearerToken: 'token', variantId: 'DOG-001', quantity: 1);
    await catalog.getCartItems(bearerToken: 'token');
    expect(requests, [
      'GET /order-table',
      'GET /order-search',
      'GET /catalog/v1/configured-products',
      'GET /catalog/v1/configured-search',
      'GET /catalog/v1/view/DOG-001',
      'POST /orders/v1/configured-add',
      'GET /orders/v1/configured-cart',
    ]);
  });

  testWidgets(
      'Product Management uses shared product cards and default variant data',
      (tester) async {
    const item = MenuItem(
      code: 'productManagement',
      name: 'Product Management',
      dataTableBlueprintUrl: '/products/api/blueprint/productsDataTable',
    );
    const cloudUrl =
        'https://storage.googleapis.com/petcare/treats.png?signature=test%2Bvalue';
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aGZkAAAAASUVORK5CYII=';
    final requests = <String>[];
    final client = MockClient((request) async {
      expect(request.url.host, Uri.parse(ApiConfig.baseUrl).host);
      expect(request.headers['authorization'], 'Bearer token');
      requests.add(request.url.path);
      final Object payload = switch (request.url.path) {
        '/products/api/blueprint/productsDataTable' => {
            'dataApi': '/product-records',
            'dataGrid': [
              {
                'field': 'mainImage',
                'displayName': 'Image',
                'imageApi': '/products/api/images/{variantId}',
                'mobileDisplay': true,
              },
              {'field': 'productName', 'displayName': 'Product'},
            ],
          },
        '/product-records' => {
            'records': [
              {
                'productName': 'Kibble',
                'mainImage': {'base64': png}
              },
              {
                'productName': 'Treats',
                'brandName': 'Pet Brand',
                'flavour': 'Chicken',
                'lifeStage': 'Adult',
                'petType': 'Cat',
                'categoryName': 'Jerky',
                'sku': 'TREAT-01',
                'variants': [
                  {
                    'variantId': 'other-variant',
                    'isActive': true,
                    'isDefault': false,
                    'unitSize': '500g',
                    'finalPrice': 225,
                    'mainImage':
                        'https://storage.googleapis.com/petcare/other.webp',
                  },
                  {
                    'variantId': 'default-variant',
                    'isActive': true,
                    'isDefault': true,
                    'unitSize': '100g',
                    'unitType': 'g',
                    'finalPrice': 99,
                    'mainImage': cloudUrl,
                    'subImages': [
                      'https://storage.googleapis.com/petcare/side.webp'
                    ],
                  },
                ],
              },
              {
                'productName': 'No direct photo',
                'mainImage': '/products/api/images/internal.png',
                'imageUrl':
                    '${ApiConfig.baseUrl}/products/api/images/internal.png',
              },
            ],
          },
        _ => throw StateError('Unexpected backend request: ${request.url}'),
      };
      return http.Response(jsonEncode(payload), 200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    await tester.pumpWidget(MaterialApp(
      home: AdminModuleScreen(
          item: item, load: () => repository.load('token', item)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(
        find.text('Pet Brand Treats Chicken Adult Cat Jerky'), findsOneWidget);
    expect(find.text('100g'), findsOneWidget);
    expect(find.text('\u20B999'), findsOneWidget);
    expect(find.text('500g'), findsNothing);
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image);
    expect(images.whereType<MemoryImage>(), hasLength(1));
    final directImage = images.whereType<NetworkImage>().single;
    expect(directImage.url, cloudUrl);
    expect(directImage.headers, isNull);
    expect(requests,
        ['/products/api/blueprint/productsDataTable', '/product-records']);
    expect(find.byIcon(Icons.pets_outlined), findsWidgets);

    int columns() =>
        (tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    expect(columns(), 3);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpAndSettle();
    expect(columns(), 2);
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await tester.pumpAndSettle();
    expect(columns(), 4);
  });

  testWidgets('Create Order refreshes backend filters and submits option codes',
      (tester) async {
    var optionsRequests = 0;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      if (request.url.path == '/search-blueprint') {
        return http.Response(
            jsonEncode({
              'searchForm': [
                {'field': 'q', 'fieldType': 'textBox'},
                {
                  'field': 'categoryCode',
                  'fieldType': 'cascadeDropDown',
                  'displayName': 'Catalog category',
                  'api': '/catalog/platform/{version}/api/categories',
                  'dropdownCode': 'code',
                  'dropdownValue': 'name',
                },
              ],
            }),
            200);
      }
      expect(request.url.path, '/catalog/platform/v1/api/categories');
      optionsRequests++;
      return http.Response(
          jsonEncode({
            'records': [
              {
                'code': 'category-$optionsRequests',
                'name': optionsRequests == 1 ? 'Dry food' : 'Wet food',
              },
            ],
          }),
          200);
    });
    final repository =
        AdminModuleRepositoryImpl((_) async => [], client: client);
    final catalog = _FakeCatalogRepository();
    await tester.pumpWidget(MaterialApp(
      home: CreateOrderScreen(
        bearerToken: 'token',
        catalogRepository: catalog,
        cartQuantityStore: _FakeCartQuantityStore(),
        loadSearchFilters: () => repository.loadSearchFilters(
          'token',
          const MenuItem(
            code: 'createOrder',
            name: 'Create Order',
            searchBlueprintUrl: '/search-blueprint',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final filters = find.byTooltip('Filters');
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.tap(filters);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dry food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(catalog.lastProductQuery['categoryCode'], 'category-1');

    await tester.tap(filters);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(optionsRequests, 2);
    expect(find.text('Wet food'), findsWidgets);
    expect(find.text('Dry food'), findsNothing);
  });

  testWidgets('admin submenu restores a cached data link and shows records',
      (tester) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      paths.add(request.url.path);
      final Object payload = switch (request.url.path) {
        '/users/api/menulinks' => {
            'records': [
              {
                'mainMenuCode': 'orders',
                'mainMenuName': 'Orders',
                'subMenuList': [
                  {
                    'subMenuCode': 'orderManagement',
                    'subMenuName': 'Order Management',
                    'dataTableBluePrintUrl': '/products/api/blueprint/orders',
                    'searchBluePrintUrl':
                        '/products/api/blueprint/ordersSearch',
                  },
                ],
              },
            ],
          },
        '/products/api/blueprint/orders' => {
            'dataApi': '/orders/platform/{version}/api/orders',
            'dataGrid': [
              {'field': 'orderNumber', 'displayName': 'Order number'},
              {'field': 'internalId', 'display': false},
            ],
          },
        '/products/api/blueprint/ordersSearch' => {
            'searchApi': '/orders/platform/{version}/api/search',
            'searchForm': [
              {
                'field': 'q',
                'displayName': 'Order search',
                'fieldType': 'textBox'
              },
            ],
          },
        '/orders/platform/v1/api/search' => {
            'records': [
              {'orderNumber': 'FILTERED-456'},
            ],
          },
        '/orders/platform/v1/api/orders' => {
            'data': {
              'records': [
                {'orderNumber': 'ORDER-123', 'internalId': 'hidden-value'},
              ],
            },
          },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response(jsonEncode(payload), 200);
    });
    final auth = AuthRepositoryImpl(AuthRemoteDataSource(client: client));
    await tester.pumpWidget(PetCareApp(
      authRepository: auth,
      catalogRepository: _FakeCatalogRepository(),
      cartQuantityStore: _FakeCartQuantityStore(),
      adminModuleRepository:
          AdminModuleRepositoryImpl(auth.getMenuItems, client: client),
      initialSession: const AppSession(
        tokens: AuthTokens(
          bearerToken: 'token',
          refreshToken: 'refresh',
          expiresIn: '3600',
        ),
        menuItems: [
          MenuItem(code: 'orders', name: 'Orders', children: [
            MenuItem(code: 'orderManagement', name: 'Order Management'),
          ]),
        ],
      ),
    ));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order Management'));
    await tester.pumpAndSettle();

    expect(find.text('Order number'), findsOneWidget);
    expect(find.text('ORDER-123'), findsOneWidget);
    expect(find.text('hidden-value'), findsNothing);
    expect(paths, [
      '/users/api/menulinks',
      '/products/api/blueprint/orders',
      '/orders/platform/v1/api/orders',
    ]);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '456');
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('FILTERED-456'), findsOneWidget);
    expect(paths.last, '/orders/platform/v1/api/search');
  });

  testWidgets('back from product search restores the original product details',
      (tester) async {
    final catalog = _FakeCatalogRepository()
      ..products = const [
        Product(name: 'Kibble', variantId: 'DOG-001'),
        Product(name: 'Treats', variantId: 'DOG-002'),
      ];
    await tester.pumpWidget(MaterialApp(
      home: CreateOrderScreen(
        bearerToken: 'token',
        catalogRepository: catalog,
        cartQuantityStore: _FakeCartQuantityStore(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kibble'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search products'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 't');
    await tester.pumpAndSettle();
    expect(find.text('Treats'), findsOneWidget);
    expect(find.text('Kibble'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Product Details'), findsOneWidget);
    expect(find.text('Kibble'), findsWidgets);
    expect(find.text('Treats'), findsNothing);
  });

  testWidgets('typing one letter filters products without submitting',
      (tester) async {
    final catalog = _FakeCatalogRepository()
      ..products = const [
        Product(name: 'Kibble'),
        Product(name: 'Treats'),
      ];
    await tester.pumpWidget(MaterialApp(
      home: CreateOrderScreen(
        bearerToken: 'token',
        catalogRepository: catalog,
        cartQuantityStore: _FakeCartQuantityStore(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.enterText(search, 'k');
    await tester.pumpAndSettle();
    expect(find.text('Kibble'), findsOneWidget);
    expect(find.text('Treats'), findsNothing);

    await tester.enterText(search, 'tr');
    await tester.pumpAndSettle();
    expect(find.text('Treats'), findsOneWidget);
    expect(find.text('Kibble'), findsNothing);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.text('Kibble'), findsOneWidget);
    expect(find.text('Treats'), findsOneWidget);
  });

  testWidgets('a pending details add updates the catalog and cart count',
      (tester) async {
    final pendingAdd = Completer<void>();
    final catalog = _FakeCatalogRepository()
      ..products = const [Product(name: 'Test kibble', variantId: 'DOG-001')]
      ..pendingAdd = pendingAdd.future;
    await tester.pumpWidget(MaterialApp(
      home: CreateOrderScreen(
        bearerToken: 'token',
        catalogRepository: catalog,
        cartQuantityStore: _FakeCartQuantityStore(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test kibble'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add +'));
    await tester.pump();
    expect(find.text('Cart (1)'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Cart (1)'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Add +'), findsNothing);

    pendingAdd.completeError(Exception('Cart update rejected'));
    await tester.pumpAndSettle();
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Add +'), findsOneWidget);
  });

  testWidgets('wide product details scroll independently of the gallery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ProductDetailScreen(
        product: Product(
          name: 'Test product',
          unitSize: '3 kg',
          price: 3494,
          imageUrls: const [
            'https://example.test/main.png',
            'https://example.test/side.png',
          ],
          description: List.filled(24, 'Product description line.').join('\n'),
        ),
        bearerToken: 'token',
        catalogRepository: _FakeCatalogRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final gallery = find.byType(PageView);
    final thumbnails = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(tester.getTopLeft(thumbnails).dy,
        greaterThan(tester.getBottomLeft(gallery).dy));
    await tester.tapAt(tester.getTopLeft(thumbnails) + const Offset(80, 25));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(gallery).controller!.page, 1);
    final title = find.text('Test product').first;
    final galleryPosition = tester.getTopLeft(gallery);
    final titlePosition = tester.getTopLeft(title);
    expect(titlePosition.dx, greaterThan(galleryPosition.dx));
    final details = find.byKey(
      const PageStorageKey('product-details-information'),
    );
    expect(find.descendant(of: details, matching: find.text('Add +')),
        findsOneWidget);
    final priceCenter = tester.getCenter(find.text('\u20B9\u00A03494'));
    final addCenter = tester.getCenter(
      find.widgetWithText(FilledButton, 'Add +'),
    );
    expect(addCenter.dx, greaterThan(priceCenter.dx));
    expect(addCenter.dy, closeTo(priceCenter.dy, 1));
    final addButton = find.widgetWithText(FilledButton, 'Add +');
    expect(tester.getTopRight(addButton).dx,
        closeTo(tester.getTopRight(details).dx - 24, 1));
    await tester.drag(details, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(gallery), galleryPosition);
    expect(tester.getTopLeft(title).dy, lessThan(titlePosition.dy));
    final description = find.textContaining('Product description line.');
    expect(tester.widget<Text>(description).maxLines, 5);
    expect(find.text('More'), findsOneWidget);

    final specificationLabel = find.text('Product name');
    await tester.scrollUntilVisible(
      specificationLabel,
      150,
      scrollable:
          find.descendant(of: details, matching: find.byType(Scrollable)),
    );
    expect(specificationLabel, findsOneWidget);
  });

  testWidgets('signs in and opens PetWork navigation', (tester) async {
    await tester.pumpWidget(PetCareApp(
      authRepository: _FakeAuthRepository(),
      catalogRepository: _FakeCatalogRepository(),
      cartQuantityStore: _FakeCartQuantityStore(),
    ));
    await tester.enterText(
        find.byType(TextFormField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('PetWork'), findsOneWidget);
  });

  testWidgets('logs out from the drawer to the sign-in screen', (tester) async {
    await tester.pumpWidget(PetCareApp(
      authRepository: _FakeAuthRepository(),
      catalogRepository: _FakeCatalogRepository(),
      cartQuantityStore: _FakeCartQuantityStore(),
    ));
    await tester.enterText(
        find.byType(TextFormField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  test('auth data source sends the login request and bearer token', () async {
    final requests = <http.Request>[];
    final source = AuthRemoteDataSource(client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/login')) {
        return http.Response(
            jsonEncode({
              'bearerToken': 'token',
              'refreshToken': 'refresh',
              'expiresIn': '3600'
            }),
            200);
      }
      return http.Response(jsonEncode({'records': []}), 200);
    }));
    await source.login('admin@example.com', 'password123');
    await source.getMenuLinks('token');
    expect(requests.first.url.path, '/users/api/login');
    expect(requests.last.headers['authorization'], 'Bearer token');
  });

  test('catalog data source calls the configured data API', () async {
    http.Request? request;
    final source = CatalogRemoteDataSource(client: MockClient((value) async {
      request = value;
      return http.Response(
          jsonEncode([
            {'productName': 'Healthy Dog Food'}
          ]),
          200);
    }));
    await source.getProducts(
      'token',
      const {'q': 'food', 'brandName': 'PetWork', 'petType': 'Dog'},
    );
    expect(request!.url.path, '/catalog/platform/v1/api/product');
    expect(request!.headers['authorization'], 'Bearer token');
    expect(request!.url.queryParameters['q'], 'food');
    expect(request!.url.queryParameters['brandName'], 'PetWork');
    expect(request!.url.queryParameters['petType'], 'Dog');
  });

  test('maps backend image fields for base-url image loading', () async {
    final repository = CatalogRepositoryImpl(
      CatalogRemoteDataSource(
          client: MockClient((_) async => http.Response(
                jsonEncode([
                  {
                    'productName': 'Healthy Dog Food',
                    'imageUrl': '/product-images/dog-food.png',
                  },
                ]),
                200,
              ))),
    );
    final products = await repository.getProducts(bearerToken: 'token');
    expect(products.single.mainImage, '/product-images/dog-food.png');
    expect(
      ApiConfig.resolveImageUrl(products.single.mainImage),
      '${ApiConfig.baseUrl}/product-images/dog-food.png',
    );
  });

  test('maps JSON-encoded backend image metadata for base-url loading',
      () async {
    final repository = CatalogRepositoryImpl(
      CatalogRemoteDataSource(
          client: MockClient((_) async => http.Response(
                jsonEncode([
                  {
                    'productName': 'Healthy Dog Food',
                    'mainImage': '/product-images/dog-food.png',
                    'subImages': [
                      {'mediaUrl': '/product-images/dog-food-side.png'},
                      {'mediaUrl': '/product-images/dog-food-back.png'},
                    ],
                  },
                ]),
                200,
              ))),
    );
    final products = await repository.getProducts(bearerToken: 'token');
    expect(
      ApiConfig.resolveImageUrl(products.single.mainImage),
      '${ApiConfig.baseUrl}/product-images/dog-food.png',
    );
    expect(products.single.imageUrls, [
      '/product-images/dog-food.png',
      '/product-images/dog-food-side.png',
      '/product-images/dog-food-back.png',
    ]);
  });

  test('preserves full cloud image URLs without routing through the backend',
      () {
    const cloudUrl = 'https://storage.googleapis.com/pet-images/dog-food.png';
    expect(ApiConfig.resolveImageUrl(cloudUrl), cloudUrl);
  });

  test('view product request uses variantId and bearer token', () async {
    http.Request? request;
    final source = CatalogRemoteDataSource(client: MockClient((value) async {
      request = value;
      return http.Response(
          jsonEncode({
            'data': {
              'productName': 'Healthy Dog Food',
              'productDetails': 'Complete nutrition for dogs',
            },
          }),
          200);
    }));
    final detail = await source.getProductDetail('token', 'DOG-001');
    expect(request!.url.path, '/catalog/platform/v1/api/product/DOG-001');
    expect(request!.headers['authorization'], 'Bearer token');
    expect(detail['productDetails'], 'Complete nutrition for dogs');
  });

  test('Add + posts variantId and quantity to the cart API', () async {
    http.Request? request;
    final source = CatalogRemoteDataSource(client: MockClient((value) async {
      request = value;
      return http.Response(jsonEncode({'message': 'Added'}), 201);
    }));
    await source.addToCart(
      bearerToken: 'token',
      variantId: 'DOG-001',
      quantity: 1,
    );
    expect(request!.method, 'POST');
    expect(request!.url.path, '/orders/platform/v1/api/cart');
    expect(request!.headers['authorization'], 'Bearer token');
    expect(jsonDecode(request!.body), {'variantId': 'DOG-001', 'quantity': 1});
  });

  test('cart data source fetches cart products with bearer token', () async {
    http.Request? request;
    final source = CatalogRemoteDataSource(client: MockClient((value) async {
      request = value;
      return http.Response(jsonEncode({'records': []}), 200);
    }));
    await source.getCartItems('token');
    expect(request!.method, 'GET');
    expect(request!.url.path, '/orders/platform/v1/api/cart');
    expect(request!.headers['authorization'], 'Bearer token');
  });

  test('cart removal sends DELETE with variantId and bearer token', () async {
    http.Request? request;
    final source = CatalogRemoteDataSource(client: MockClient((value) async {
      request = value;
      return http.Response('', 204);
    }));
    await source.removeFromCart(bearerToken: 'token', variantId: 'DOG-001');
    expect(request!.method, 'DELETE');
    expect(request!.url.path, '/orders/platform/v1/api/cart/DOG-001');
    expect(request!.headers['authorization'], 'Bearer token');
  });

  test('uses backend image URLs and concise product card metadata', () {
    const product = Product(
      name: 'Adult Kibble',
      brand: 'PetWork',
      flavour: 'Chicken',
      lifeStage: 'Adult',
      petType: 'Dog',
      category: 'Food',
      unitSize: '0.5 kg',
      unitType: 'kg',
      price: 197.0,
    );
    expect(product.cardTitle, 'PetWork Adult Kibble Chicken Adult Dog Food');
    expect(product.cardMeta, '0.5 kg   ₹197.0');
    expect(
      ApiConfig.resolveImageUrl('/images/dog-food.png'),
      '${ApiConfig.baseUrl}/images/dog-food.png',
    );
  });

  test('cart quantity is restored and positive adjustments are sent to the API',
      () async {
    final catalog = _FakeCatalogRepository()
      ..cartItems = [
        CartItem(
          product: Product(name: 'Kibble', variantId: 'DOG-001'),
          quantity: 2,
        ),
      ];
    final store = _FakeCartQuantityStore()..quantities['DOG-001'] = 2;
    final viewModel = CreateOrderViewModel(
      GetProductsUseCase(catalog),
      GetBrandNamesUseCase(catalog),
      GetCartItemsUseCase(catalog),
      AddToCartUseCase(catalog),
      RemoveFromCartUseCase(catalog),
      store,
    );

    await viewModel.load('token');
    expect(viewModel.quantityFor('DOG-001'), 2);

    await viewModel.changeQuantity(
      bearerToken: 'token',
      variantId: 'DOG-001',
      quantity: 3,
    );

    expect(store.quantities['DOG-001'], 3);
    expect(catalog.cartUpdates, [
      {'variantId': 'DOG-001', 'quantity': 3},
    ]);

    await viewModel.changeQuantity(
      bearerToken: 'token',
      variantId: 'DOG-001',
      quantity: 0,
    );

    expect(store.quantities.containsKey('DOG-001'), isFalse);
    expect(catalog.removedVariantIds, ['DOG-001']);
  });

  test('a local cart-cache error does not prevent an API cart update',
      () async {
    final catalog = _FakeCatalogRepository();
    final viewModel = CreateOrderViewModel(
      GetProductsUseCase(catalog),
      GetBrandNamesUseCase(catalog),
      GetCartItemsUseCase(catalog),
      AddToCartUseCase(catalog),
      RemoveFromCartUseCase(catalog),
      _FailingCartQuantityStore(),
    );

    final error = await viewModel.changeQuantity(
      bearerToken: 'token',
      variantId: 'DOG-001',
      quantity: 1,
    );

    expect(error, isNull);
    expect(viewModel.quantityFor('DOG-001'), 1);
    expect(catalog.cartUpdates, [
      {'variantId': 'DOG-001', 'quantity': 1},
    ]);
  });

  test('product card add action posts createApi quantity one', () async {
    final catalog = _FakeCatalogRepository();
    final viewModel = CreateOrderViewModel(
      GetProductsUseCase(catalog),
      GetBrandNamesUseCase(catalog),
      GetCartItemsUseCase(catalog),
      AddToCartUseCase(catalog),
      RemoveFromCartUseCase(catalog),
      _FakeCartQuantityStore(),
    );

    final error = await viewModel.addProductToCart(
      bearerToken: 'token',
      variantId: 'DOG-001',
    );

    expect(error, isNull);
    expect(catalog.cartUpdates, [
      {'variantId': 'DOG-001', 'quantity': 1},
    ]);
  });

  test('cart quantity controls post the selected positive quantity', () async {
    final catalog = _FakeCatalogRepository()
      ..cartItems = [
        CartItem(
          product: Product(name: 'Kibble', variantId: 'DOG-001'),
          quantity: 1,
        ),
      ];
    final viewModel = CartViewModel(
      GetCartItemsUseCase(catalog),
      AddToCartUseCase(catalog),
      RemoveFromCartUseCase(catalog),
    )..items = const [
        CartItem(
          product: Product(name: 'Kibble', variantId: 'DOG-001'),
          quantity: 1,
        ),
      ];

    final error = await viewModel.changeQuantity(
      bearerToken: 'token',
      item: viewModel.items.single,
      quantity: 2,
    );

    expect(error, isNull);
    expect(viewModel.items.single.quantity, 2);
    expect(catalog.cartUpdates, [
      {'variantId': 'DOG-001', 'quantity': 2},
    ]);

    final removeError = await viewModel.changeQuantity(
      bearerToken: 'token',
      item: viewModel.items.single,
      quantity: 0,
    );

    expect(removeError, isNull);
    expect(viewModel.items, isEmpty);
    expect(catalog.removedVariantIds, ['DOG-001']);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AppSession> signIn(
          {required String email, required String password}) async =>
      const AppSession(
        tokens: AuthTokens(
            bearerToken: 'token', refreshToken: 'refresh', expiresIn: '3600'),
        menuItems: [],
      );
}

class _FakeCatalogRepository implements CatalogRepository {
  Map<String, String> lastProductQuery = {};
  final cartUpdates = <Map<String, Object>>[];
  final removedVariantIds = <String>[];
  List<CartItem> cartItems = [];
  List<Product> products = const [];
  Future<void>? pendingAdd;
  @override
  Future<List<Product>> getProducts({
    required String bearerToken,
    ProductFilters filters = const ProductFilters(),
  }) async {
    lastProductQuery = filters.queryParameters;
    final query = lastProductQuery['q']?.toLowerCase() ?? '';
    return products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Future<List<String>> getBrandNames({required String bearerToken}) async =>
      const [];

  @override
  Future<Product> getProductDetail({
    required String bearerToken,
    required String variantId,
  }) async =>
      products.where((product) => product.variantId == variantId).firstOrNull ??
      const Product(name: 'Test product');

  @override
  Future<void> addToCart({
    required String bearerToken,
    required String variantId,
    required int quantity,
  }) async {
    cartUpdates.add({'variantId': variantId, 'quantity': quantity});
    await pendingAdd;
    final index =
        cartItems.indexWhere((item) => item.product.variantId == variantId);
    final product = index >= 0
        ? cartItems[index].product
        : Product(name: 'Test product', variantId: variantId);
    if (index >= 0) {
      cartItems[index] = CartItem(product: product, quantity: quantity);
    } else {
      cartItems = [
        ...cartItems,
        CartItem(product: product, quantity: quantity)
      ];
    }
  }

  @override
  Future<void> removeFromCart({
    required String bearerToken,
    required String variantId,
  }) async {
    removedVariantIds.add(variantId);
    cartItems = cartItems
        .where((item) => item.product.variantId != variantId)
        .toList(growable: false);
  }

  @override
  Future<List<CartItem>> getCartItems({required String bearerToken}) async =>
      List.of(cartItems);
}

class _FakeCartQuantityStore implements CartQuantityStore {
  final quantities = <String, int>{};

  @override
  Future<Map<String, int>> loadQuantities() async => Map.of(quantities);

  @override
  Future<void> saveQuantity(String variantId, int quantity) async {
    if (quantity < 1) {
      quantities.remove(variantId);
    } else {
      quantities[variantId] = quantity;
    }
  }
}

class _FailingCartQuantityStore implements CartQuantityStore {
  @override
  Future<Map<String, int>> loadQuantities() async => {};

  @override
  Future<void> saveQuantity(String variantId, int quantity) =>
      Future.error(Exception('Local storage is unavailable.'));
}
