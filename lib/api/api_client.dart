import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_environment.dart';
import 'api_exception.dart';
import 'auth/session_store.dart';

/// The one HTTP client every service uses.
///
/// - `Accept: application/json` on every request; JSON bodies are encoded,
///   [FormData] bodies go as multipart (dio sets the boundary).
/// - Authenticated calls send `Authorization: Bearer <token>`. With no valid
///   session the request is not sent: the user is signed out instead.
/// - A 401 on an authenticated call clears the session and calls
///   [onUnauthorized] (route to the login screen there).
/// - Nothing is cached. Identical GETs already in flight share one Future,
///   which is forgotten as soon as it completes.
class ApiClient {
  ApiClient({
    required this.env,
    required this.session,
    Dio? dio,
    this.onUnauthorized,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: env.timeout,
              receiveTimeout: env.timeout,
            ));

  final ApiEnvironment env;
  final SessionStore session;
  final Dio _dio;

  /// Called after the session is cleared because of a 401 or a missing /
  /// expired session. Navigate to login here.
  void Function()? onUnauthorized;

  final Map<String, Future<dynamic>> _inFlight = {};

  /// Returns the decoded JSON body, the raw text if it isn't JSON, or null
  /// when the body is empty.
  Future<dynamic> get(String path, {bool auth = true}) {
    final url = env.urlFor(path);
    final key = '$auth $url';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _send('GET', url, auth: auth);
    _inFlight[key] = future;
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return future;
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', env.urlFor(path), body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', env.urlFor(path), body: body, auth: auth);

  Future<dynamic> delete(String path, {Object? body, bool auth = true}) =>
      _send('DELETE', env.urlFor(path), body: body, auth: auth);

  Future<dynamic> _send(
    String method,
    String url, {
    Object? body,
    required bool auth,
  }) async {
    final headers = <String, dynamic>{'Accept': 'application/json'};
    if (auth) {
      final current = session.current;
      if (current == null) {
        await _signOut();
        throw const ApiException(ApiException.sessionExpiredMessage, 401);
      }
      headers['Authorization'] = 'Bearer ${current.bearerToken}';
    }

    Object? data;
    String? contentType;
    if (body is FormData) {
      data = body;
    } else if (body != null) {
      data = jsonEncode(body);
      contentType = Headers.jsonContentType;
    }

    final cancel = CancelToken();
    final timer = Timer(env.timeout, () => cancel.cancel(_timeoutReason));
    final Response<String> res;
    try {
      res = await _dio.request<String>(
        url,
        data: data,
        cancelToken: cancel,
        options: Options(
          method: method,
          headers: headers,
          contentType: contentType,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw _mapTransportError(e);
    } finally {
      timer.cancel();
    }

    final status = res.statusCode ?? 0;
    final parsed = parseResponseBody(res.data);
    if (status >= 200 && status < 300) return parsed;
    if (status == 401 && auth) await _signOut();
    throw ApiException(extractErrorMessage(parsed, status), status);
  }

  Future<void> _signOut() async {
    await session.clear();
    onUnauthorized?.call();
  }

  static const _timeoutReason = 'petwork-timeout';

  static ApiException _mapTransportError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(ApiException.timeoutMessage, 0);
      case DioExceptionType.cancel:
        return e.error == _timeoutReason
            ? const ApiException(ApiException.timeoutMessage, 0)
            : const ApiException('Request cancelled.', 0);
      default:
        return const ApiException(ApiException.networkMessage, 0);
    }
  }
}

/// Empty → null; JSON → decoded; anything else → the text itself.
Object? parseResponseBody(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}
