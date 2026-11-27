/// Page size used everywhere. Pages start at 0.
const pageSize = 24;

/// A list response is a bare array or `{ "records": [...] }`; anything else
/// is an empty list.
List<Map<String, dynamic>> extractRecords(Object? body) {
  final list = body is List ? body : (body is Map ? body['records'] : null);
  if (list is! List) return [];
  return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

/// Unfiltered-list paging, in priority order: `hasNext` → `totalPages` →
/// `total` → a full page.
bool computeHasNext(Object? body, int page, int recordCount) {
  if (body is Map) {
    final hasNext = body['hasNext'];
    if (hasNext is bool) return hasNext;
    final totalPages = _num(body['totalPages']);
    if (totalPages != null) return page + 1 < totalPages;
    final total = _num(body['total']);
    if (total != null) return (page + 1) * pageSize < total;
  }
  return recordCount == pageSize;
}

/// A single-record response may be bare, `[ {...} ]`, `{records: [...]}`,
/// `{record: {...}}` or `{data: {...}}`.
Map<String, dynamic>? unwrapRecord(Object? body) {
  if (body is List) {
    return body.isNotEmpty && body.first is Map
        ? unwrapRecord(body.first)
        : null;
  }
  if (body is! Map) return null;
  final records = body['records'];
  if (records is List) return unwrapRecord(records);
  for (final key in const ['record', 'data']) {
    final inner = body[key];
    if (inner is Map) return Map<String, dynamic>.from(inner);
  }
  return Map<String, dynamic>.from(body);
}

num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
