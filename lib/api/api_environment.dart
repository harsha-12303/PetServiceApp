/// Backend configuration shared by every service.
///
/// Override at build time, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com --dart-define=API_VERSION=v1`.
/// Use the same value as `VITE_API_BASE_URL` in the web admin's `.env`.
class ApiEnvironment {
  ApiEnvironment({
    required String baseUrl,
    this.version = 'v1',
    this.timeout = const Duration(seconds: 30),
  }) : baseUrl = _stripTrailingSlashes(baseUrl.trim());

  factory ApiEnvironment.fromDefines() => ApiEnvironment(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBaseUrl,
        ),
        version:
            const String.fromEnvironment('API_VERSION', defaultValue: 'v1'),
        timeout: const Duration(
          seconds: int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 30),
        ),
      );

  static const _defaultBaseUrl =
      'https://preservation-owners-felt-feedback.trycloudflare.com';

  /// No trailing slash.
  final String baseUrl;

  /// Replaces `{version}` in every blueprint path.
  final String version;

  /// Applies to each request as a whole.
  final Duration timeout;

  /// `products/platform/{version}/api/products` → `/products/platform/v1/api/products`.
  String resolveApiPath(String path) {
    final p = path.trim().replaceAll('{version}', version);
    return p.startsWith('/') ? p : '/$p';
  }

  /// Like [resolveApiPath], with `{recordId}` replaced by the url-encoded id.
  String resolveRecordPath(String path, String recordId) => resolveApiPath(
        path.replaceAll('{recordId}', Uri.encodeComponent(recordId)),
      );

  /// Full URL for an already resolved path. Absolute URLs pass through.
  String urlFor(String resolvedPath) {
    if (resolvedPath.startsWith('http://') ||
        resolvedPath.startsWith('https://')) {
      return resolvedPath;
    }
    return '$baseUrl${resolvedPath.startsWith('/') ? '' : '/'}$resolvedPath';
  }

  static String _stripTrailingSlashes(String url) {
    var u = url;
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

/// Appends query parameters, using `&` when [path] already has a query.
String withQuery(String path, Map<String, String> params) {
  if (params.isEmpty) return path;
  final query = params.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '$path${path.contains('?') ? '&' : '?'}$query';
}
