import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/api/petwork_api.dart';

void main() {
  final env =
      ApiEnvironment(baseUrl: 'https://api.example.com//', version: 'v1');

  group('path resolution', () {
    test('strips trailing slashes from the base URL', () {
      expect(env.baseUrl, 'https://api.example.com');
    });

    test('replaces {version} and adds a leading slash', () {
      expect(env.resolveApiPath('products/platform/{version}/api/products'),
          '/products/platform/v1/api/products');
      expect(
          env.resolveApiPath('/users/api/menulinks'), '/users/api/menulinks');
    });

    test('fills {recordId} url-encoded', () {
      expect(
        env.resolveRecordPath(
            'products/platform/{version}/api/products/{recordId}', 'SKU 1/A'),
        '/products/platform/v1/api/products/SKU%201%2FA',
      );
    });

    test('urlFor joins base and path', () {
      expect(env.urlFor('/users/api/login'),
          'https://api.example.com/users/api/login');
    });

    test('withQuery uses ? or & as needed', () {
      expect(withQuery('/a', {'page': '0', 'size': '24'}), '/a?page=0&size=24');
      expect(
          withQuery('/a?size=50', {'q': 'dog food'}), '/a?size=50&q=dog+food');
    });

    test('short blueprint URLs try /api first, then the service fallback', () {
      expect(
          blueprintPaths('products/blueprint/{version}/productEditForm',
              env.resolveApiPath),
          [
            '/api/products/blueprint/v1/productEditForm',
            '/products/api/blueprint/productEditForm',
          ]);
      expect(
          blueprintPaths('/products/blueprint/{version}/productEditForm',
                  env.resolveApiPath)
              .first,
          '/api/products/blueprint/v1/productEditForm');
    });

    test('other blueprint URLs are fetched as is', () {
      expect(
          blueprintPaths('products/platform/{version}/api/blueprint/table',
              env.resolveApiPath),
          ['/products/platform/v1/api/blueprint/table']);
    });
  });

  group('error messages', () {
    test('detail string', () {
      expect(extractErrorMessage({'detail': 'Invalid credentials'}, 400),
          'Invalid credentials');
    });

    test('FastAPI validation list with field labels', () {
      final body = {
        'detail': [
          {
            'loc': ['body', 'email'],
            'msg': 'value is not a valid email'
          },
          {
            'loc': ['body', 'profileCode'],
            'msg': 'field required'
          },
          {
            'loc': ['body', 'other'],
            'msg': 'bad value'
          },
        ]
      };
      expect(extractErrorMessage(body, 422),
          'Email: value is not a valid email. Profile: field required. bad value');
    });

    test('errorMessages list', () {
      expect(
          extractErrorMessage({
            'errorMessages': ['One', 'Two']
          }, 400),
          'One. Two');
    });

    test('message string', () {
      expect(extractErrorMessage({'message': 'Nope'}, 500), 'Nope');
    });

    test('fallback', () {
      expect(extractErrorMessage(null, 502), 'Request failed (502)');
      expect(extractErrorMessage('<html>', 502), 'Request failed (502)');
      expect(extractErrorMessage({'errorMessages': []}, 400),
          'Request failed (400)');
    });
  });

  group('expiresIn', () {
    test('seconds as a string or number', () {
      expect(parseExpiresInMs('3600'), 3600000);
      expect(parseExpiresInMs(120), 120000);
    });

    test('missing or invalid → 1 hour', () {
      expect(parseExpiresInMs(null), 3600000);
      expect(parseExpiresInMs('soon'), 3600000);
      expect(parseExpiresInMs('0'), 3600000);
    });
  });

  group('menu', () {
    test('sorts sub-menus by order (null = 0) and reads BluePrint keys', () {
      final menu = parseMenu({
        'records': [
          {
            'mainMenuCode': 'INVENTORY',
            'mainMenuName': 'Inventory',
            'subMenuList': [
              {'subMenuName': 'B', 'order': 2},
              {
                'subMenuName': 'A',
                'order': null,
                'dataTableBluePrintUrl': 'x/table',
                'searchBluePrintUrl': ''
              },
              {'subMenuName': 'C', 'order': 1},
            ],
          }
        ],
        'errorMessages': null,
      });
      expect(menu.single.subMenus.map((s) => s.name), ['A', 'C', 'B']);
      expect(menu.single.subMenus.first.dataTableBlueprintUrl, 'x/table');
      expect(menu.single.subMenus.first.searchBlueprintUrl, isNull);
    });

    test('errorMessages with no records throws', () {
      expect(
        () => parseMenu({
          'records': [],
          'errorMessages': ['No access']
        }),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'No access')),
      );
    });
  });
}
