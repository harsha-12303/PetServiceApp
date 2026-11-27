import '../api_client.dart';
import '../api_environment.dart';
import '../blueprint/blueprint_models.dart';
import 'body_builder.dart';
import 'form_values.dart';
import 'record_utils.dart';

class PageResult {
  const PageResult(
      {required this.records, required this.page, required this.hasNext});

  final List<Map<String, dynamic>> records;
  final int page;

  /// For filtered searches this means "show Load more".
  final bool hasNext;
}

/// The record behind an edit form: its id, and the table row merged with the
/// freshly fetched record (or the row alone if that fetch failed).
class EditTarget {
  const EditTarget({required this.recordId, required this.record});
  final String? recordId;
  final Map<String, dynamic> record;
}

/// Lists, searches and saves records. Every URL comes from a blueprint.
class RecordService {
  RecordService(this._client);
  final ApiClient _client;

  ApiEnvironment get _env => _client.env;

  /// Unfiltered list: `GET {dataApi}?page=&size=24`.
  Future<PageResult> fetchPage(String dataApi, int page) async {
    final body = await _client.get(withQuery(
      _env.resolveApiPath(dataApi),
      {'page': '$page', 'size': '$pageSize'},
    ));
    final records = extractRecords(body);
    return PageResult(
      records: records,
      page: page,
      hasNext: computeHasNext(body, page, records.length),
    );
  }

  /// Filtered search: every active filter as a query param, plus page/size.
  /// [PageResult.hasNext] is true when a full page came back.
  /// Wrap calls in a [LatestRequestGuard] so stale responses are ignored.
  Future<PageResult> search(
      String dataApi, Map<String, String?> filters, int page) async {
    final params = <String, String>{
      for (final e in activeFilters(filters).entries) e.key: e.value,
      'page': '$page',
      'size': '$pageSize',
    };
    final body =
        await _client.get(withQuery(_env.resolveApiPath(dataApi), params));
    final records = extractRecords(body);
    return PageResult(
        records: records, page: page, hasNext: records.length == pageSize);
  }

  /// Dropdown options: from `api` (used as is, no paging added) or
  /// `staticDropDownValues`. Rows without a code are skipped.
  Future<List<DropdownOption>> fetchOptions(BlueprintField field) async {
    final api = field.api;
    final rows = api != null && api.isNotEmpty
        ? extractRecords(await _client.get(_env.resolveApiPath(api)))
        : field.staticDropDownValues;
    return rows.map(field.optionFrom).whereType<DropdownOption>().toList();
  }

  /// `GET dataApi` with `{recordId}` filled in; the record unwrapped.
  Future<Map<String, dynamic>?> fetchRecord(
          String dataApi, String recordId) async =>
      unwrapRecord(
          await _client.get(_env.resolveRecordPath(dataApi, recordId)));

  /// Prefill for an edit form. The id is `row[form.mappings.recordId]`, else
  /// [tableRecordId].
  Future<EditTarget> loadForEdit(
    FormBlueprint form,
    Map<String, dynamic> row, {
    String? tableRecordId,
  }) async {
    final fromForm =
        form.recordIdField == null ? null : row[form.recordIdField];
    final recordId = (fromForm != null && '$fromForm'.isNotEmpty)
        ? '$fromForm'
        : tableRecordId;
    final dataApi = form.dataApi;
    if (dataApi == null || recordId == null) {
      return EditTarget(recordId: recordId, record: row);
    }
    try {
      final fetched = await fetchRecord(dataApi, recordId);
      return EditTarget(recordId: recordId, record: {...row, ...?fetched});
    } catch (_) {
      return EditTarget(recordId: recordId, record: row);
    }
  }

  /// `POST createApi` (JSON, or multipart when the form has file fields).
  Future<dynamic> create(
    FormBlueprint form,
    FormValues values, {
    List<String> removedImages = const [],
  }) {
    final createApi = form.createApi;
    if (createApi == null) throw StateError('This form has no createApi.');
    return _client.post(
      _env.resolveApiPath(createApi),
      body: buildSaveBody(form, values, removedImages: removedImages),
    );
  }

  /// `PATCH dataApi` with `{recordId}` filled in. Updates are PATCH, not PUT.
  Future<dynamic> update(
    FormBlueprint form,
    String recordId,
    FormValues values, {
    List<String> removedImages = const [],
  }) {
    final dataApi = form.dataApi;
    if (dataApi == null) throw StateError('This form has no dataApi.');
    return _client.patch(
      _env.resolveRecordPath(dataApi, recordId),
      body: buildSaveBody(form, values, removedImages: removedImages),
    );
  }

  /// `DELETE dataApi` with `{recordId}` filled in. Confirm with the user first,
  /// then refresh the list.
  Future<void> delete(String dataApi, String recordId) =>
      _client.delete(_env.resolveRecordPath(dataApi, recordId));
}

/// Trimmed, non-empty filter values only.
Map<String, String> activeFilters(Map<String, String?> filters) => {
      for (final e in filters.entries)
        if ((e.value ?? '').trim().isNotEmpty) e.key: e.value!.trim(),
    };

/// Text filters apply once the trimmed text reaches `rules.minSize` (default 1).
bool textFilterApplies(BlueprintField field, String text) =>
    text.trim().length >= (field.rules.minLength ?? 1);

/// Lets only the newest request's result through: when filters change while
/// a search is in flight, the older response is dropped (returns null).
class LatestRequestGuard {
  int _counter = 0;

  Future<T?> run<T>(Future<T> Function() request) async {
    final id = ++_counter;
    try {
      final result = await request();
      return id == _counter ? result : null;
    } catch (_) {
      if (id != _counter) return null; // a stale failure is ignored too
      rethrow;
    }
  }

  /// Makes any in-flight result stale (e.g. when filters are cleared).
  void invalidate() => _counter++;
}
