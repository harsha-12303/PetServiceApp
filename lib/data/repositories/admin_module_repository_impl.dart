import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/api_config.dart';
import '../../domain/entities/models.dart';
import '../../domain/repositories/admin_module_repository.dart';
import '../mappers/product_image_paths.dart';
import '../mappers/product_record_mapper.dart';

class AdminModuleRepositoryImpl implements AdminModuleRepository {
  static const _productTableBlueprint =
      '/products/api/blueprint/productsDataTable';

  AdminModuleRepositoryImpl(this._getMenuItems, {http.Client? client})
      : _client = client ?? http.Client();

  final Future<List<MenuItem>> Function(String bearerToken) _getMenuItems;
  final http.Client _client;

  /// Search URL read from a page's search blueprint, kept only while that
  /// page is open (cleared whenever its configuration is loaded afresh), so
  /// each search costs one request instead of two.
  final _searchApiByPage = <String, String?>{};

  String _pageKey(MenuItem item) =>
      '${item.code}|${item.searchBlueprintUrl ?? ''}';

  @override
  Future<AdminModuleConfiguration> loadConfiguration(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    bool includeSearchEndpoint = false,
  }) async {
    // A fresh configuration (page opened or refreshed) also forgets the
    // page's remembered search URL.
    _searchApiByPage.remove(_pageKey(item));
    if (!item.isProductManagement &&
        _link(item.dataTableBlueprintUrl) == null &&
        _link(item.dataApi) == null) {
      // Sessions saved by older builds only stored menu labels and codes.
      item = await _resolveMenuItem(bearerToken, item, parentCode);
    }

    final blueprintUrl = item.isProductManagement
        ? _productTableBlueprint
        : _link(item.dataTableBlueprintUrl);
    Map<String, dynamic> blueprint = {};
    if (blueprintUrl != null) {
      final payload = await _get(bearerToken, blueprintUrl);
      if (payload is! Map) {
        throw const AppException(
            'The server returned an invalid table layout.');
      }
      blueprint = {
        ...Map<String, dynamic>.from(payload),
        if (payload['data'] is Map)
          ...Map<String, dynamic>.from(payload['data'] as Map),
      };
    }

    final actionGroups = {
      for (final entry in blueprint.entries)
        if (entry.key.toLowerCase().endsWith('actions') && entry.value is List)
          entry.key.toLowerCase(): (entry.value as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from),
    };
    final searchApi = _link(blueprint['searchApi']) ?? _link(item.searchApi);
    final searchBlueprint = includeSearchEndpoint &&
            searchApi == null &&
            _link(item.searchBlueprintUrl) != null
        ? await _readSearchBlueprint(bearerToken, item, parentCode)
        : null;
    return AdminModuleConfiguration(
      item: item,
      blueprint: blueprint,
      actions: [
        for (final group in actionGroups.entries)
          if (group.key != 'rowlevelactions' && group.key != 'rowactions')
            ...group.value,
      ],
      dataApi: _link(blueprint['dataApi']) ?? _link(item.dataApi),
      searchApi: searchApi ?? _link(searchBlueprint?['searchApi']),
      createApi: _link(blueprint['createApi']) ??
          _link(item.createApi) ??
          actionGroups.values
              .expand((actions) => actions)
              .map((action) => _link(action['createApi']))
              .whereType<String>()
              .firstOrNull,
    );
  }

  @override
  Future<AdminModuleData> load(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    Map<String, String> filters = const {},
    AdminModuleConfiguration? configuration,
  }) async {
    final config = configuration ??
        await loadConfiguration(bearerToken, item, parentCode: parentCode);
    item = config.item;
    final isProductManagement = item.isProductManagement;
    final blueprintRecords =
        isProductManagement ? _records(config.blueprint) : null;
    final useBlueprintRecords = filters.isEmpty && blueprintRecords != null;
    final rawRecords = useBlueprintRecords
        ? blueprintRecords
        : await _loadRecords(bearerToken, config, filters, parentCode);
    final blueprintImagesById = {
      for (final row in (blueprintRecords ?? const []).whereType<Map>())
        if (_recordId(row) case final id?) id: row,
    };
    if (rawRecords == null || rawRecords.any((record) => record is! Map)) {
      throw const AppException('The server returned an invalid record list.');
    }
    final records = rawRecords
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList(growable: false);
    final grid = config.blueprint['dataGrid'];
    final columns = grid is List && grid.isNotEmpty
        ? [
            for (final entry in grid.whereType<Map>())
              if (entry['display'] != false && entry['field'] is String)
                AdminModuleColumn(
                  entry['field'] as String,
                  entry['displayName']?.toString() ?? entry['field'] as String,
                  showOnMobile: entry['mobileDisplay'] != false,
                  isImage: _isImageColumn(entry),
                ),
          ]
        : [
            for (final field in records.expand((row) => row.keys).toSet())
              AdminModuleColumn(
                field,
                field,
                isImage: ProductImagePaths.isImageField(field),
              ),
          ];
    if (isProductManagement &&
        !columns.any((column) => column.isImage) &&
        !(grid is List && grid.whereType<Map>().any(_isImageColumn)) &&
        records.any((row) {
          final blueprintRow = blueprintImagesById[_recordId(row)];
          return _productImageSource(row, 'mainImage') != null ||
              (blueprintRow != null &&
                  _productImageSource(blueprintRow, 'mainImage') != null);
        })) {
      columns.insert(
          0,
          const AdminModuleColumn(
            'mainImage',
            'Image',
            isImage: true,
          ));
    }
    for (final column in columns.where((column) => column.isImage)) {
      for (final record in records) {
        final field = column.field;
        if (!isProductManagement) {
          record[field] =
              ProductImagePaths.fromValue(_fieldValue(record, field));
          continue;
        }
        final blueprintRow = blueprintImagesById[_recordId(record)];
        record[field] = _productImageSource(record, field) ??
            (blueprintRow == null
                ? null
                : _productImageSource(blueprintRow, field));
      }
    }
    return AdminModuleData(
      columns: columns,
      records: records,
      configuration: config,
      products: isProductManagement
          ? [
              for (final record in records)
                _adminProduct(
                  record,
                  columns,
                  blueprintImagesById[_recordId(record)],
                ),
            ]
          : null,
    );
  }

  AdminProduct _adminProduct(
    Map<String, dynamic> record,
    List<AdminModuleColumn> columns,
    Map? blueprintRow,
  ) {
    final variant = _orderedVariants(record).firstOrNull;
    final image = columns
            .where((column) => column.isImage)
            .map((column) => record[column.field])
            .nonNulls
            .firstOrNull ??
        _productImageSource(record, 'mainImage') ??
        (blueprintRow == null
            ? null
            : _productImageSource(blueprintRow, 'mainImage'));
    return AdminProduct(
      record: record,
      product: productFromRecord(
        {
          ...record,
          if (variant != null)
            for (final field in ['unitSize', 'unitType', 'finalPrice'])
              if (variant[field] != null) field: variant[field],
        },
        imageUrls: [if (image is String) image],
      ),
      imageBytes: image is Uint8List ? image : null,
    );
  }

  Future<List?> _loadRecords(
    String bearerToken,
    AdminModuleConfiguration config,
    Map<String, String> filters,
    String? parentCode,
  ) async {
    final key = _pageKey(config.item);
    final dataApi = filters.isEmpty
        ? config.dataApi
        : config.searchApi ??
            (_searchApiByPage.containsKey(key)
                ? _searchApiByPage[key]
                : _searchApiByPage[key] = _link((await _readSearchBlueprint(
                    bearerToken, config.item, parentCode))?['searchApi'])) ??
            config.dataApi;
    if (dataApi == null) {
      throw const AppException('This menu has no data endpoint configured.');
    }
    return _records(await _get(bearerToken, dataApi, query: filters));
  }

  String? _recordId(Map record) => (record['variantId'] ??
          record['variant_id'] ??
          record['id'] ??
          record['sku'])
      ?.toString();

  Object? _fieldValue(Map record, String field) => record.containsKey(field)
      ? record[field]
      : field.split('.').fold<Object?>(
          record, (value, key) => value is Map ? value[key] : null);

  Uint8List? _productImage(Map record, String field) =>
      _inlineImage(_fieldValue(record, field)) ??
      _inlineImage(record['imageData']) ??
      record.entries
          .where((entry) =>
              entry.key is String && ProductImagePaths.isImageField(entry.key))
          .map((entry) => _inlineImage(entry.value))
          .whereType<Uint8List>()
          .firstOrNull;

  Object? _productImageSource(Map record, String field) {
    final backendHost = Uri.parse(ApiConfig.baseUrl).host;
    final sources = [record, ..._orderedVariants(record)];
    for (final source in sources) {
      final paths = {
        ...ProductImagePaths.fromValue(_fieldValue(source, field)),
        ...ProductImagePaths.fromRecord(source),
      };
      for (final path in paths) {
        final uri = Uri.tryParse(path);
        if (uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            uri.host != backendHost &&
            uri.userInfo.isEmpty) {
          return path;
        }
      }
    }
    return sources
        .map((source) => _productImage(source, field))
        .whereType<Uint8List>()
        .firstOrNull;
  }

  Iterable<Map> _orderedVariants(Map record) sync* {
    final rawVariants = record['variants'];
    final variants =
        rawVariants is List ? rawVariants.whereType<Map>() : const <Map>[];
    yield* variants.where((variant) =>
        variant['isDefault'] == true && variant['isActive'] != false);
    yield* variants.where((variant) =>
        variant['isDefault'] != true && variant['isActive'] != false);
    yield* variants.where((variant) => variant['isActive'] == false);
  }

  bool _isImageColumn(Map entry) {
    final field = entry['field'];
    final type =
        (entry['fieldType'] ?? entry['type'])?.toString().toLowerCase();
    return (field is String && ProductImagePaths.isImageField(field)) ||
        type == 'image' ||
        type == 'thumbnail';
  }

  Uint8List? _inlineImage(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) {
      return value.map(_inlineImage).whereType<Uint8List>().firstOrNull;
    }
    if (value is Map) {
      for (final key in const ['base64', 'imageData', 'data']) {
        final bytes = _inlineImage(value[key]);
        if (bytes != null) return bytes;
      }
      return null;
    }
    if (value is! String) return null;
    final raw = value.trim();
    try {
      if (raw.startsWith('data:image/')) {
        return UriData.parse(raw).contentAsBytes();
      }
      if (raw.startsWith('{')) return _inlineImage(jsonDecode(raw));
      if (const ['iVBOR', '/9j/', 'R0lGOD', 'UklGR'].any(raw.startsWith)) {
        return base64Decode(raw);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Future<List<SearchFilterField>?> loadSearchFilters(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    bool includeQuickSearch = false,
  }) async {
    final blueprint = await _readSearchBlueprint(bearerToken, item, parentCode);
    if (blueprint == null) return null;
    final form = blueprint['searchForm'];
    if (form is! List) {
      throw const AppException('The server returned invalid search filters.');
    }
    return Future.wait([
      for (final entry in form.whereType<Map>())
        if (entry['field'] is String &&
            (entry['field'] as String).isNotEmpty &&
            (includeQuickSearch || entry['field'] != 'q') &&
            entry['display'] != false &&
            entry['editable'] != false)
          _loadSearchField(bearerToken, entry),
    ]);
  }

  Future<Map?> _readSearchBlueprint(
    String bearerToken,
    MenuItem item,
    String? parentCode,
  ) async {
    var url = _link(item.searchBlueprintUrl);
    if (url == null) {
      final freshItem = await _resolveMenuItem(bearerToken, item, parentCode);
      url = _link(freshItem.searchBlueprintUrl);
    }
    if (url == null) return null;

    final payload = await _get(bearerToken, url);
    final blueprint =
        payload is Map && payload['data'] is Map ? payload['data'] : payload;
    if (blueprint is! Map) {
      throw const AppException('The server returned invalid search filters.');
    }
    return blueprint;
  }

  Future<SearchFilterField> _loadSearchField(
    String bearerToken,
    Map entry,
  ) async {
    final field = entry['field'] as String;
    final fieldType = entry['fieldType']?.toString().toLowerCase() ?? '';
    final isDropdown = fieldType.endsWith('dropdown');
    final radioValues = entry['values'];
    final optionApi = _link(entry['api']);
    final dependencies = (entry['valuesDependOnField']?.toString() ?? '')
        .split(',')
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toList(growable: false);
    final criteria = _link(entry['visibilityCriteria']);
    final isConditional = dependencies.isNotEmpty || criteria != null;
    Future<Map<String, String>> readOptions(Map<String, String> values) async {
      var endpoint = optionApi;
      if (endpoint != null) {
        for (final field in dependencies) {
          endpoint = endpoint!.replaceAll(
            '{$field}',
            Uri.encodeComponent(values[field] ?? ''),
          );
        }
      }
      final rawOptions = optionApi == null
          ? entry['staticDropDownValues']
          : _records(await _get(bearerToken, endpoint!));
      if (optionApi != null && rawOptions == null) {
        throw const AppException('The server returned invalid filter options.');
      }
      final codeKey = entry['dropdownCode'] ?? field;
      final labelKey = entry['dropdownValue'] ?? codeKey;
      final options = <String, String>{};
      if (rawOptions is List) {
        for (final option in rawOptions) {
          final code = option is Map ? option[codeKey] : option;
          if (code == null || code.toString().isEmpty) continue;
          final label = option is Map ? option[labelKey] ?? code : code;
          options[code.toString()] = label.toString();
        }
      }
      return options;
    }

    return SearchFilterField(
      field: field,
      label: entry['displayName']?.toString().trim() ?? field,
      placeholder: entry['placeholder']?.toString(),
      options: fieldType == 'radiobutton'
          ? {
              if (radioValues is List)
                for (final choice in radioValues.whereType<Map>())
                  if (_link(choice['radioValue']) case final value?)
                    value: choice['displayName']?.toString() ?? value,
            }
          : isDropdown && !isConditional
              ? await readOptions(const {})
              : null,
      loadOptions: isDropdown && isConditional ? readOptions : null,
      dependencies: dependencies,
      visibilityCriteria: criteria,
      // Only `quickSearchFilter: true` is inline; everything else (including
      // fields the backend adds later) goes in the Filters box.
      quickSearch: entry['quickSearchFilter'] == true ||
          entry['quickSearchFilter']?.toString().toLowerCase() == 'true',
      minLength: int.tryParse('${_formRules(entry)['minSize'] ?? ''}') ?? 1,
    );
  }

  @override
  Future<ModuleRecordForm> loadCreateForm(
    String bearerToken,
    AdminModuleConfiguration configuration, {
    Map<String, dynamic>? record,
    AdminRowAction? rowAction,
  }) async {
    final isEditing = record != null;
    final readOnly = rowAction?.isView == true;
    final action = rowAction?.definition ??
        (isEditing
            ? configuration.rowAction('edit') ??
                configuration.rowAction('update')
            : configuration.createAction);
    final blueprintTemplate = _link(action?['blueprintApi']);
    final blueprintApi = blueprintTemplate == null || record == null
        ? blueprintTemplate
        : configuration.recordEndpoint(blueprintTemplate, record,
            actionMappings: action?['mappings']);
    if (blueprintApi == null) {
      throw const AppException(
          'This table has no form configured for this action.');
    }
    final legacyPath = RegExp(r'^/products/blueprint/[^/]+/([\w-]+)$')
        .firstMatch(_backendUri(blueprintApi)?.path ?? '');
    final payload = await _get(
      bearerToken,
      blueprintApi,
      fallbackOnNotFound: legacyPath == null
          ? null
          : '/products/api/blueprint/${legacyPath[1]}',
      operation: 'load the record form',
    );
    if (payload is! Map) {
      throw const AppException('The server returned an invalid record form.');
    }
    final blueprint = {
      ...payload,
      if (payload['data'] is Map) ...(payload['data'] as Map),
    };
    final form = (readOnly
            ? blueprint['viewForm']
            : isEditing
                ? blueprint['editForm']
                : blueprint['createForm']) ??
        blueprint['editForm'] ??
        blueprint['formFields'] ??
        blueprint['form'] ??
        blueprint['fields'];
    final fields = form is Map ? form['fields'] ?? form['formFields'] : form;
    final entries = fields is List
        ? fields.whereType<Map>().where((entry) =>
            entry['field'] is String &&
            (entry['field'] as String).trim().isNotEmpty &&
            entry['display'] != false &&
            (readOnly || entry['editable'] != false))
        : const <Map>[];
    Map? initialRecord = record;
    final formConfig = form is Map ? form : const {};
    final dataApi = _link(blueprint['dataApi']) ??
        _link(formConfig['dataApi']) ??
        _link(action?['dataApi']);
    final mappings =
        blueprint['mappings'] ?? formConfig['mappings'] ?? action?['mappings'];
    String? recordDataPath;
    if (record != null && dataApi != null) {
      recordDataPath = configuration.recordEndpoint(
        dataApi,
        record,
        actionMappings: mappings,
      );
      if (recordDataPath == null) {
        throw const AppException('The selected record has no configured ID.');
      }
      final details =
          await _get(bearerToken, recordDataPath, operation: 'load the record');
      if (details is! Map) {
        throw const AppException('The server returned an invalid record.');
      }
      initialRecord = {
        ...record,
        ...(details['data'] is Map ? details['data'] as Map : details)
      };
    }
    bool isGroup(Map entry) =>
        entry['fieldType']?.toString().toLowerCase() == 'repeatablegroup';
    final reusesProductEditForm = !isEditing &&
        configuration.item.isProductManagement &&
        !configuration.actions.contains(action);
    const optionalProductCreateFields = {
      'lifeStage',
      'breedSize',
      'productDetails',
      'hsnCode',
    };
    final inputs = await Future.wait(
        entries.where((entry) => !isGroup(entry)).map((entry) => _loadFormField(
              bearerToken,
              entry,
              initialRecord?[entry['field']],
              optionalForCreate: reusesProductEditForm &&
                  optionalProductCreateFields.contains(entry['field']),
            )));
    final groups = await Future.wait(entries.where(isGroup).map((entry) =>
        _loadFormGroup(bearerToken, entry, initialRecord?[entry['field']])));
    if (inputs.isEmpty && groups.isEmpty) {
      throw const AppException('The form has no editable fields configured.');
    }
    final explicitMethod = (_link(blueprint['updateMethod']) ??
            _link(formConfig['updateMethod']) ??
            _link(action?['updateMethod']))
        ?.toUpperCase();
    final writeMethod = explicitMethod ??
        (action == null ? null : AdminRowAction(action).explicitMethod);
    final hasWriteMethod = const {'POST', 'PUT', 'PATCH'}.contains(writeMethod);
    final updateApi = _link(blueprint['updateApi']) ??
        _link(formConfig['updateApi']) ??
        _link(action?['updateApi']);
    final rowCreateApi = rowAction != null && !rowAction.isEdit
        ? _link(blueprint['createApi']) ??
            _link(formConfig['createApi']) ??
            _link(action?['createApi'])
        : null;
    final editAction = action != null && AdminRowAction(action).isEdit;
    final writeTemplate = updateApi ?? rowCreateApi;
    final String? saveApi;
    if (record == null) {
      saveApi = _link(blueprint['createApi']) ??
          _link(formConfig['createApi']) ??
          _link(action?['createApi']) ??
          _link(configuration.blueprint['createApi']) ??
          _link(configuration.item.createApi);
    } else if (readOnly) {
      saveApi = null;
    } else if (editAction) {
      saveApi = recordDataPath;
    } else if (writeTemplate != null) {
      saveApi = configuration.recordEndpoint(writeTemplate, record,
          actionMappings: mappings);
    } else {
      saveApi = hasWriteMethod ? recordDataPath : null;
    }
    final createTemplate = record == null ? saveApi : null;
    return ModuleRecordForm(
      fields: inputs,
      groups: groups,
      // Product forms have image fields, so create AND edit go as multipart.
      multipart: !readOnly && configuration.item.isProductManagement,
      showResetButton: blueprint['resetButton'] == true,
      readOnly: readOnly,
      // Updates are PATCH (the record URL rejects POST with 405).
      method: !isEditing
          ? 'POST'
          : editAction
              ? 'PATCH'
              : hasWriteMethod
                  ? writeMethod!
                  : (rowCreateApi != null && updateApi == null
                      ? 'POST'
                      : 'PUT'),
      createApi: saveApi,
      resolveCreateApi: createTemplate != null
          ? (values) => configuration.recordEndpoint(
                createTemplate,
                values,
                actionMappings: mappings,
              )
          : null,
    );
  }

  Future<ModuleFormField> _loadFormField(
    String bearerToken,
    Map entry,
    Object? value, {
    bool optionalForCreate = false,
  }) async {
    final validation = _formRules(entry);
    final fieldType = entry['fieldType']?.toString().trim().toLowerCase() ?? '';
    final input = await _loadSearchField(bearerToken, entry);
    final initialValue =
        (value ?? validation['default'] ?? entry['default'])?.toString();
    return ModuleFormField(
      input: input,
      isRadio: fieldType == 'radiobutton',
      fieldType: fieldType,
      allowedValues: _link(validation['allowValues']),
      maxValueField: _link(validation['maxValueField']),
      multipleFiles: validation['multiple'] == true,
      maxFileBytes: fieldType == 'fileupload'
          ? _uploadLimit(validation['maxSize'])
          : null,
      isPercentage: input.field == 'discountPercent',
      helperText: _link(entry['toolTip']) == input.label
          ? null
          : _link(entry['toolTip']),
      isRequired: !optionalForCreate &&
          (validation['mandatory'] == true || entry['required'] == true),
      isProductCreateHsn: optionalForCreate && input.field == 'hsnCode',
      initialValue:
          input.options == null || input.options!.containsKey(initialValue)
              ? initialValue
              : null,
      minLength: int.tryParse(validation['minSize']?.toString() ?? ''),
      maxLength: int.tryParse(validation['maxSize']?.toString() ?? ''),
    );
  }

  int? _uploadLimit(Object? value) {
    final match = RegExp(r'^(\d+)\s*(B|KB|MB)?$', caseSensitive: false)
        .firstMatch(value?.toString().trim() ?? '');
    if (match == null) return null;
    final factor = switch (match[2]?.toUpperCase()) {
      'MB' => 1024 * 1024,
      'KB' => 1024,
      _ => 1,
    };
    return int.parse(match[1]!) * factor;
  }

  Map _formRules(Map entry) {
    final rules = entry['rules'];
    final rule = rules is List ? rules.whereType<Map>().firstOrNull : rules;
    return rule is Map ? rule : entry;
  }

  Future<ModuleFormGroup> _loadFormGroup(
      String bearerToken, Map entry, Object? value) async {
    final rules = _formRules(entry);
    final children = entry['childFields'];
    final fields = await Future.wait([
      if (children is List)
        for (final child in children.whereType<Map>())
          if (_link(child['field']) != null &&
              child['display'] != false &&
              child['editable'] != false)
            _loadFormField(bearerToken, child, null),
    ]);
    return ModuleFormGroup(
      input: await _loadSearchField(bearerToken, entry),
      fields: fields,
      initialRows: [
        if (value is List)
          for (final row in value.whereType<Map>())
            Map<String, Object?>.from(row),
      ],
      addLabel: _link(entry['addButtonLabel']) ?? 'Add row',
      helperText: _link(entry['toolTip']),
      minItems: int.tryParse('${rules['minItems']}') ??
          (rules['mandatory'] == true ? 1 : 0),
      maxItems: int.tryParse('${rules['maxItems']}'),
      uniqueBy: _link(rules['uniqueBy']),
      uniqueTogether: (_link(rules['uniqueTogether']) ?? '')
          .split(',')
          .map((field) => field.trim())
          .where((field) => field.isNotEmpty)
          .toList(),
      singleTrueField: _link(rules['singleTrueField']),
    );
  }

  @override
  Future<void> createRecord(
    String bearerToken,
    ModuleRecordForm form,
    Map<String, Object?> values,
  ) async {
    final resolveEndpoint = form.resolveCreateApi;
    final endpoint =
        resolveEndpoint == null ? form.createApi : resolveEndpoint(values);
    if (resolveEndpoint != null && endpoint == null) {
      throw const AppException(
          'Enter the record identifier required by the Create endpoint.');
    }
    final uri = endpoint == null ? null : _backendUri(endpoint);
    if (uri == null || !const {'POST', 'PUT', 'PATCH'}.contains(form.method)) {
      throw const AppException('The form has no valid Save endpoint.');
    }
    final response = form.multipart
        ? await _createProduct(bearerToken, uri, form, values)
        : await _request(bearerToken, uri, method: form.method, jsonBody: {
            ...values,
            for (final field in form.fields)
              if (field.isPercentage && values.containsKey(field.input.field))
                field.input.field:
                    num.parse(values[field.input.field].toString()),
          });
    _checkWrite(response, 'save record');
  }

  Future<http.Response> _createProduct(
    String bearerToken,
    Uri uri,
    ModuleRecordForm form,
    Map<String, Object?> values,
  ) {
    // POST on create, PATCH on edit.
    final request = http.MultipartRequest(form.method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $bearerToken';
    final groups = {for (final group in form.groups) group.input.field: group};
    final keptUrls = <String>{};
    final removeImages = <String>[];
    for (final entry in values.entries) {
      final rows = entry.value;
      final group = groups[entry.key];
      if (group == null || rows is! List<Map<String, Object?>>) {
        if (rows != null) request.fields[entry.key] = rows.toString();
        continue;
      }
      final fileFields = {
        for (final field in group.fields)
          if (field.fieldType == 'fileupload') field.input.field: field,
      };
      final metadata = <Map<String, Object?>>[];
      for (final (index, row) in rows.indexed) {
        metadata.add({
          for (final field in row.entries)
            if (!fileFields.containsKey(field.key)) field.key: field.value,
          // Server images still kept: a URL for single fields, a list for
          // multiple ones. Newly picked files go as parts below instead.
          for (final MapEntry(key: name, value: field) in fileFields.entries)
            if (_imageUrls(row[name]) case final urls?)
              name: field.multipleFiles ? urls : urls.firstOrNull,
        });
        for (final name in fileFields.keys) {
          keptUrls.addAll(_imageUrls(row[name]) ?? const []);
        }
        for (final field in fileFields.keys) {
          final files = row[field];
          if (files is! List<ModuleFormFile>) continue;
          for (final file in files) {
            request.files.add(http.MultipartFile.fromBytes(
              '${entry.key}[$index][$field]',
              file.bytes,
              filename: file.name,
              contentType: MediaType.parse(file.contentType),
            ));
          }
        }
      }
      request.fields[entry.key] = jsonEncode(metadata);
      // Images the product had when the form opened but no longer keeps.
      for (final initial in group.initialRows) {
        for (final name in fileFields.keys) {
          removeImages.addAll(_imageUrls(initial[name]) ?? const []);
        }
      }
    }
    removeImages.removeWhere(keptUrls.contains);
    // One `removeImages` part per URL (http's `fields` map can't repeat keys).
    for (final url in removeImages.toSet()) {
      request.files.add(http.MultipartFile.fromString('removeImages', url));
    }
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 60));
  }

  @override
  Future<void> deleteRecord(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record, {
    AdminRowAction? rowAction,
  }) async {
    final definition =
        configuration.rowAction('delete') ?? configuration.rowAction('remove');
    final action =
        rowAction ?? (definition == null ? null : AdminRowAction(definition));
    if (action == null || !action.isDelete) {
      throw const AppException('This row has no configured Delete action.');
    }
    await runRowAction(bearerToken, configuration, record, action);
  }

  @override
  Future<void> runRowAction(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record,
    AdminRowAction action,
  ) async {
    final method = action.method;
    final template = action.endpoint;
    final path = template == null
        ? null
        : configuration.recordEndpoint(
            template,
            record,
            actionMappings: action.definition['mappings'],
          );
    final uri = path == null ? null : _backendUri(path);
    if (uri == null ||
        method == null ||
        !const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)) {
      throw const AppException(
          'The action endpoint, method, or record identifier is missing.');
    }
    final payload = action.definition['payload'];
    final mappings = action.definition['payloadMapping'];
    final body = <String, Object?>{
      if (payload is Map) ...Map<String, Object?>.from(payload),
    };
    if (mappings is Map) {
      for (final entry in mappings.entries) {
        final name = entry.key;
        final field = entry.value;
        final value =
            field is String ? configuration.recordValue(record, field) : null;
        if (name is! String || value == null) {
          throw const AppException(
              'The selected record is missing a required action value.');
        }
        body[name] = value;
      }
    }
    final response = await _request(
      bearerToken,
      uri,
      method: method,
      jsonBody: body.isEmpty ? null : body,
    );
    _checkWrite(response, 'run ${action.label}');
  }

  @override
  Future<AdminModuleData> loadRecordDetails(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record, {
    AdminRowAction? rowAction,
  }) async {
    final action = rowAction?.definition ?? configuration.rowAction('view');
    final template = _link(action?['dataApi']) ?? rowAction?.endpoint;
    final path = template == null
        ? null
        : configuration.recordEndpoint(template, record,
            actionMappings: action?['mappings']);
    if (path == null) {
      throw const AppException(
          'The View endpoint or record identifier is missing.');
    }
    final payload = await _get(bearerToken, path, operation: 'load details');
    final details =
        payload is Map && payload['data'] is Map ? payload['data'] : payload;
    final list = _records(payload);
    if (list == null && details is! Map ||
        list != null && list.any((row) => row is! Map)) {
      throw const AppException('The server returned invalid record details.');
    }
    final rows = list == null
        ? [
            {...record, ...Map<String, dynamic>.from(details as Map)}
          ]
        : list
            .cast<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
    final grid = action?['dataGrid'] ?? configuration.blueprint['dataGrid'];
    final columns = [
      if (grid is List)
        for (final entry in grid.whereType<Map>())
          if (entry['field'] case final String field
              when entry['display'] != false)
            AdminModuleColumn(
              field,
              entry['displayName']?.toString() ?? field,
              isImage: _isImageColumn(entry),
              showOnMobile: entry['mobileDisplay'] != false,
            ),
    ];
    if (grid is! List) {
      columns.addAll([
        for (final field in rows.expand((row) => row.keys).toSet())
          AdminModuleColumn(field, field,
              isImage: ProductImagePaths.isImageField(field)),
      ]);
    }
    for (final row in rows) {
      for (final column in columns.where((column) => column.isImage)) {
        row[column.field] = configuration.item.isProductManagement
            ? _productImageSource(row, column.field)
            : ProductImagePaths.fromValue(_fieldValue(row, column.field));
      }
    }
    return AdminModuleData(columns: columns, records: rows);
  }

  void _checkWrite(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map) {
        final message =
            payload['detail'] ?? payload['message'] ?? payload['error'];
        if (message is String && message.isNotEmpty) {
          throw AppException(message);
        }
        if (message is List) {
          final messages = message.whereType<Map>().map((error) {
            final label = error['loc'];
            final text = error['msg'] ?? error['message'];
            if (text is! String || text.isEmpty) return null;
            final field = label is List
                ? label.where((part) => part != 'body').join('.')
                : '';
            return field.isEmpty ? text : '$field: $text';
          }).whereType<String>();
          if (messages.isNotEmpty) throw AppException(messages.join('\n'));
        }
      }
    } on FormatException {
      // Use the HTTP status when the server does not return an error object.
    }
    throw AppException('Could not $operation (HTTP ${response.statusCode}).');
  }

  Future<MenuItem> _resolveMenuItem(
    String bearerToken,
    MenuItem item,
    String? parentCode,
  ) async {
    final menu = await _getMenuItems(bearerToken);
    final siblings = parentCode == null
        ? menu
        : menu
            .where((parent) => parent.code == parentCode)
            .firstOrNull
            ?.children;
    return siblings?.where((entry) => entry.code == item.code).firstOrNull ??
        item;
  }

  String? _link(Object? value) {
    if (value is! String) return null;
    final link = value.trim();
    return link.isEmpty || link == 'string' ? null : link;
  }

  List? _records(Object? payload) {
    if (payload is List) return payload;
    if (payload is! Map) return null;
    for (final key in const [
      'records',
      'content',
      'items',
      'rows',
      'results',
      'data'
    ]) {
      final records = _records(payload[key]);
      if (records != null) return records;
    }
    return null;
  }

  Uri? _backendUri(String path) {
    final base = Uri.parse(ApiConfig.baseUrl);
    final resolvedPath =
        path.replaceAll('{version}', ApiConfig.platformVersion);
    final endpoint = Uri.tryParse(resolvedPath);
    final uri = endpoint == null ? null : base.resolveUri(endpoint);
    if (uri == null ||
        uri.scheme != base.scheme ||
        uri.host != base.host ||
        uri.port != base.port ||
        uri.userInfo.isNotEmpty ||
        resolvedPath.contains('{') ||
        resolvedPath.contains('}')) {
      return null;
    }
    return uri;
  }

  Future<http.Response> _request(
    String bearerToken,
    Uri uri, {
    String method = 'GET',
    Map<String, Object?>? jsonBody,
  }) =>
      (() async {
        final request = http.Request(method, uri)
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $bearerToken';
        if (jsonBody != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(jsonBody);
        }
        return http.Response.fromStream(await _client.send(request));
      })()
          .timeout(const Duration(seconds: 20));

  Future<Object?> _get(
    String bearerToken,
    String path, {
    Map<String, String> query = const {},
    String? fallbackOnNotFound,
    String operation = 'load menu data',
  }) async {
    final uri = _backendUri(path);
    if (uri == null) {
      throw const AppException('The menu has an invalid data endpoint.');
    }
    final response = await _request(
      bearerToken,
      query.isEmpty
          ? uri
          : uri.replace(queryParameters: {...uri.queryParameters, ...query}),
    );
    if (response.statusCode == 204) return const [];
    if (response.statusCode == 404 && fallbackOnNotFound != null) {
      return _get(
        bearerToken,
        fallbackOnNotFound,
        query: query,
        operation: operation,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException('Could not $operation (HTTP ${response.statusCode}).');
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const AppException('The server returned invalid menu data.');
    }
  }
}

/// Server image URLs held by a file field: a URL string or a list of them.
/// Null when the field holds newly picked files (or nothing usable).
List<String>? _imageUrls(Object? value) {
  if (value is List<ModuleFormFile>) return null;
  if (value is String) return value.trim().isEmpty ? const [] : [value.trim()];
  if (value is List) {
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty)
          item.trim()
        else if (item is Map && item['url'] is String)
          item['url'] as String,
    ];
  }
  return null;
}
