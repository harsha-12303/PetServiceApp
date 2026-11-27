import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petcare_services/data/repositories/admin_module_repository_impl.dart';
import 'package:petcare_services/domain/entities/models.dart';

void main() {
  test('searching an open page reuses its blueprint: one request per search',
      () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      final Object body = switch (request.url.path) {
        '/table' => {
            'dataApi': '/rows',
            'dataGrid': [
              {'field': 'name', 'displayName': 'Name'}
            ],
          },
        '/search' => {'searchApi': '/rows/search'},
        _ => {
            'records': [
              {'name': 'A'}
            ]
          },
      };
      return http.Response(jsonEncode(body), 200);
    });
    final repo = AdminModuleRepositoryImpl((_) async => [], client: client);
    const item = MenuItem(
      code: 'things',
      name: 'Things',
      dataTableBlueprintUrl: '/table',
      searchBlueprintUrl: '/search',
    );

    final first = await repo.load('t', item);
    expect(paths, ['/table', '/rows']);

    paths.clear();
    await repo.load('t', item,
        filters: {'q': 'a'}, configuration: first.configuration);
    // The search URL is read once while the page is open...
    expect(paths, ['/search', '/rows/search']);

    paths.clear();
    await repo.load('t', item,
        filters: {'q': 'ab'}, configuration: first.configuration);
    // ...after that every search is a single request.
    expect(paths, ['/rows/search']);

    paths.clear();
    await repo.load('t', item); // refresh: everything fresh again
    expect(paths, ['/table', '/rows']);
  });
}
