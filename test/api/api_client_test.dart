import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/api/petwork_api.dart';

class _MemoryStorage implements SecureKeyValue {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final (int, String) Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final (status, body) = handler(options);
    return ResponseBody.fromString(body, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAdapter adapter;
  late SessionStore sessions;
  late ApiClient client;
  var signedOut = 0;

  void setUpClient((int, String) Function(RequestOptions) handler) {
    adapter = _FakeAdapter(handler);
    sessions = SessionStore(storage: _MemoryStorage());
    final dio = Dio()..httpClientAdapter = adapter;
    signedOut = 0;
    client = ApiClient(
      env: ApiEnvironment(baseUrl: 'https://api.test'),
      session: sessions,
      dio: dio,
      onUnauthorized: () => signedOut++,
    );
  }

  Future<void> signIn() => sessions.save(
        Session(
          email: 'a@b.c',
          bearerToken: 'T0K',
          refreshToken: null,
          expiresAt: DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        ),
        remember: false,
      );

  test('login stores the session and sends no auth header', () async {
    setUpClient((_) => (
          200,
          jsonEncode(
              {'bearerToken': 'abc', 'refreshToken': 'r', 'expiresIn': '60'})
        ));
    final session = await AuthService(client, sessions)
        .login(email: ' a@b.c ', password: 'pw');
    expect(session.bearerToken, 'abc');
    expect(sessions.current?.email, 'a@b.c');
    final req = adapter.requests.single;
    expect(req.path, 'https://api.test/users/api/login');
    expect(req.method, 'POST');
    expect(req.headers.containsKey('Authorization'), isFalse);
  });

  test('login without a token fails', () async {
    setUpClient((_) => (200, '{}'));
    expect(
      AuthService(client, sessions).login(email: 'a', password: 'b'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'm', contains('did not return a token'))),
    );
  });

  test('authenticated GET sends the bearer token', () async {
    setUpClient((_) => (200, '{"records": []}'));
    await signIn();
    await client.get('/users/api/menulinks');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer T0K');
    expect(adapter.requests.single.headers['Accept'], 'application/json');
  });

  test('no session → request not sent, user signed out', () async {
    setUpClient((_) => (200, '{}'));
    await expectLater(client.get('/x'), throwsA(isA<ApiException>()));
    expect(adapter.requests, isEmpty);
    expect(signedOut, 1);
  });

  test('401 clears the session', () async {
    setUpClient((_) => (401, '{"detail": "Token expired"}'));
    await signIn();
    await expectLater(
        client.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'm', 'Token expired')));
    expect(sessions.current, isNull);
    expect(signedOut, 1);
  });

  test('identical in-flight GETs share one request, then are forgotten',
      () async {
    setUpClient((_) => (200, '[1]'));
    await signIn();
    final a = client.get('/same');
    final b = client.get('/same');
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);
    expect(adapter.requests, hasLength(1));
    await client.get('/same');
    expect(adapter.requests, hasLength(2));
  });

  test('plain-text and empty bodies', () async {
    setUpClient((o) => o.path.endsWith('/text') ? (200, 'OK done') : (204, ''));
    await signIn();
    expect(await client.get('/text'), 'OK done');
    expect(await client.delete('/empty'), isNull);
  });

  test('blueprint falls back on 404', () async {
    setUpClient((o) => o.path.contains('/api/products/blueprint/')
        ? (404, '{"detail": "Not Found"}')
        : (200, jsonEncode({'displayName': 'Update Product', 'editForm': []})));
    await signIn();
    final form = await BlueprintService(client)
        .form('products/blueprint/{version}/productEditForm');
    expect(form.displayName, 'Update Product');
    expect(adapter.requests.map((r) => r.path), [
      'https://api.test/api/products/blueprint/v1/productEditForm',
      'https://api.test/products/api/blueprint/productEditForm',
    ]);
  });

  test('update uses PATCH with JSON, delete uses DELETE', () async {
    setUpClient((_) => (200, '{}'));
    await signIn();
    final records = RecordService(client);
    final form = FormBlueprint.fromJson({
      'editForm': [
        {'field': 'name', 'fieldType': 'textBox'}
      ],
      'dataApi': 'products/platform/{version}/api/products/{recordId}',
    });
    await records.update(form, 'P 1', {'name': ' X '});
    await records.delete(form.dataApi!, 'P 1');
    expect(adapter.requests[0].method, 'PATCH');
    expect(adapter.requests[0].path,
        'https://api.test/products/platform/v1/api/products/P%201');
    expect(jsonDecode(adapter.requests[0].data as String), {'name': 'X'});
    expect(adapter.requests[1].method, 'DELETE');
  });

  test('fetchPage sends page and size', () async {
    setUpClient((_) => (200, jsonEncode({'records': [], 'totalPages': 3})));
    await signIn();
    final page = await RecordService(client)
        .fetchPage('products/{version}/api/products', 1);
    expect(adapter.requests.single.path,
        'https://api.test/products/v1/api/products?page=1&size=24');
    expect(page.hasNext, isTrue);
  });

  test('cart: quantity 0 deletes, otherwise POSTs the new total', () async {
    setUpClient((_) => (200, '{}'));
    await signIn();
    final cart = CartService(
      client,
      CartActions(
          addAction: BlueprintAction(
              action: 'add', createApi: 'orders/{version}/api/cart/')),
    );
    await cart.setQuantity('V1', 3);
    await cart.setQuantity('V1', 0);
    expect(adapter.requests[0].method, 'POST');
    expect(jsonDecode(adapter.requests[0].data as String),
        {'variantId': 'V1', 'quantity': 3});
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].path, 'https://api.test/orders/v1/api/cart/V1');
  });
}
