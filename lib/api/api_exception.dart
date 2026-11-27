/// Any failed backend call. [statusCode] is 0 for timeouts and network errors.
class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  static const timeoutMessage =
      'The server took too long to respond. Please try again.';
  static const networkMessage =
      'Unable to reach the server. Check your connection and try again.';
  static const sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

const _fieldLabels = {
  'name': 'Name',
  'email': 'Email',
  'phone': 'Phone',
  'password': 'Password',
  'profileCode': 'Profile',
};

/// Turns a FastAPI / gateway error body into a readable message.
String extractErrorMessage(Object? body, int status) {
  if (body is Map) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      final msgs = <String>[];
      for (final item in detail) {
        if (item is! Map) continue;
        final msg = item['msg'];
        if (msg is! String || msg.isEmpty) continue;
        final loc = item['loc'];
        final last = loc is List && loc.isNotEmpty ? loc.last : null;
        final label = last is String ? _fieldLabels[last] : null;
        msgs.add(label != null ? '$label: $msg' : msg);
      }
      if (msgs.isNotEmpty) return msgs.join('. ');
    }
    final errorMessages = body['errorMessages'];
    if (errorMessages is List && errorMessages.isNotEmpty) {
      return errorMessages.map((e) => '$e').join('. ');
    }
    final message = body['message'];
    if (message is String) return message;
  }
  return 'Request failed ($status)';
}
