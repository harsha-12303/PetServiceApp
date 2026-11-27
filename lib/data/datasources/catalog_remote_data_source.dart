import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/network/api_config.dart';
import '../../domain/repositories/admin_module_repository.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(
      {http.Client? client, AdminModuleConfiguration? configuration})
      : _configuration = configuration,
        _client = client ?? http.Client();
  final http.Client _client;
  final AdminModuleConfiguration? _configuration;

  CatalogRemoteDataSource forModule(AdminModuleConfiguration configuration) =>
      CatalogRemoteDataSource(client: _client, configuration: configuration);

  String? _actionEndpoint(String action, String key, {bool row = true}) {
    final configured =
        row ? _configuration?.rowAction(action, includeHidden: true) : null;
    final path = (configured ?? _configuration?.action(action))?[key];
    return path is String && path.trim().isNotEmpty ? path : null;
  }

  Uri _endpoint(String? path, String fallback, {String? variantId}) {
    final base = Uri.parse(ApiConfig.baseUrl);
    var value = (path ?? fallback)
        .trim()
        .replaceAll('{version}', ApiConfig.platformVersion);
    if (variantId != null) {
      value = value.replaceAll('{variantId}', Uri.encodeComponent(variantId));
    }
    final parsed = Uri.tryParse(value);
    final uri = parsed == null ? null : base.resolveUri(parsed);
    if (uri == null ||
        uri.scheme != base.scheme ||
        uri.host != base.host ||
        uri.port != base.port ||
        uri.userInfo.isNotEmpty ||
        value.contains('{') ||
        value.contains('}')) {
      throw const AppException('The order module has an invalid API endpoint.');
    }
    return uri;
  }

  Future<http.Response> _request(String method, Uri uri, String bearerToken,
      {Map<String, Object>? body}) {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $bearerToken';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
  }

  Future<List<dynamic>> getProducts(
    String bearerToken,
    Map<String, String> filters,
  ) async {
    final endpoint = _endpoint(
      filters.isEmpty
          ? _configuration?.dataApi
          : _configuration?.searchApi ?? _configuration?.dataApi,
      '/catalog/platform/{version}/api/product',
    );
    final uri = endpoint.replace(queryParameters: {
      'size': '50',
      ...endpoint.queryParameters,
      ...filters,
    });
    final response = await _request('GET', uri, bearerToken);
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const AppException(
          'The product data returned by the server is invalid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (payload is Map && payload['detail'] is String) {
        throw AppException(payload['detail'] as String);
      }
      throw AppException(
          'Could not load products (HTTP ${response.statusCode}).');
    }
    if (payload is List) {
      return payload;
    }
    if (payload is Map && payload['records'] is List) {
      return payload['records'] as List;
    }
    throw const AppException('The server returned an invalid product list.');
  }

  Future<List<dynamic>> getBrands(String bearerToken) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/catalog/platform/${ApiConfig.platformVersion}/api/brands',
    ).replace(queryParameters: const {'size': '50', 'page': '0'});
    final response = await _request('GET', uri, bearerToken);
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const AppException(
          'The brand data returned by the server is invalid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
          'Could not load brands (HTTP ${response.statusCode}).');
    }
    if (payload is List) {
      return payload;
    }
    if (payload is Map && payload['records'] is List) {
      return payload['records'] as List;
    }
    if (payload is Map && payload['data'] is List) {
      return payload['data'] as List;
    }
    throw const AppException('The server returned an invalid brand list.');
  }

  Future<Map<String, dynamic>> getProductDetail(
    String bearerToken,
    String variantId,
  ) async {
    final uri = _endpoint(
      _actionEndpoint('view', 'dataApi'),
      '/catalog/platform/{version}/api/product/{variantId}',
      variantId: variantId,
    );
    final response = await _request('GET', uri, bearerToken);
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const AppException(
          'The product details returned by the server are invalid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (payload is Map && payload['detail'] is String) {
        throw AppException(payload['detail'] as String);
      }
      throw AppException(
          'Could not load product details (HTTP ${response.statusCode}).');
    }
    if (payload is Map && payload['data'] is Map) {
      return Map<String, dynamic>.from(payload['data'] as Map);
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const AppException('The server returned invalid product details.');
  }

  Future<void> addToCart({
    required String bearerToken,
    required String variantId,
    required int quantity,
  }) async {
    final uri = _endpoint(
      _actionEndpoint('addToCart', 'createApi'),
      '/orders/platform/{version}/api/cart',
    );
    final response = await _request(
      'POST',
      uri,
      bearerToken,
      body: {'variantId': variantId, 'quantity': quantity},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['detail'] is String) {
        throw AppException(payload['detail'] as String);
      }
    } on FormatException {
      // Fall through to a status-based message.
    }
    throw AppException(
        'Could not add the product to cart (HTTP ${response.statusCode}).');
  }

  Future<void> removeFromCart({
    required String bearerToken,
    required String variantId,
  }) async {
    final uri = _endpoint(
      _actionEndpoint('removeFromCart', 'deleteApi'),
      '/orders/platform/{version}/api/cart/{variantId}',
      variantId: variantId,
    );
    final response = await _request('DELETE', uri, bearerToken);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['detail'] is String) {
        throw AppException(payload['detail'] as String);
      }
    } on FormatException {
      // Fall through to a status-based message.
    }
    throw AppException(
        'Could not remove the product from cart (HTTP ${response.statusCode}).');
  }

  Future<List<dynamic>> getCartItems(String bearerToken) async {
    final uri = _endpoint(
      _actionEndpoint('cart', 'dataApi', row: false),
      '/orders/platform/{version}/api/cart',
    );
    final response = await _request('GET', uri, bearerToken);
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const AppException(
          'The cart data returned by the server is invalid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (payload is Map && payload['detail'] is String) {
        throw AppException(payload['detail'] as String);
      }
      throw AppException('Could not load cart (HTTP ${response.statusCode}).');
    }
    final records = _cartRecords(payload);
    if (records != null) return records;
    throw const AppException('The server returned an invalid cart.');
  }

  List<dynamic>? _cartRecords(Object? payload) {
    if (payload is List) return payload;
    if (payload is! Map) return null;
    for (final key in const ['records', 'items', 'cartItems', 'data']) {
      final value = payload[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _cartRecords(value);
        if (nested != null) return nested;
      }
    }
    return null;
  }
}
