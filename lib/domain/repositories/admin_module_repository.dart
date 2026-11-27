import 'dart:typed_data';

import '../entities/models.dart';

abstract class AdminModuleRepository {
  Future<AdminModuleData> load(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    Map<String, String> filters = const {},
  });

  Future<AdminModuleConfiguration> loadConfiguration(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    bool includeSearchEndpoint = false,
  });

  Future<List<SearchFilterField>?> loadSearchFilters(
    String bearerToken,
    MenuItem item, {
    String? parentCode,
    bool includeQuickSearch = false,
  });

  Future<ModuleRecordForm> loadCreateForm(
    String bearerToken,
    AdminModuleConfiguration configuration, {
    Map<String, dynamic>? record,
    AdminRowAction? rowAction,
  });

  Future<void> createRecord(
    String bearerToken,
    ModuleRecordForm form,
    Map<String, Object?> values,
  );

  Future<void> deleteRecord(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record, {
    AdminRowAction? rowAction,
  });

  Future<AdminModuleData> loadRecordDetails(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record, {
    AdminRowAction? rowAction,
  });

  Future<void> runRowAction(
    String bearerToken,
    AdminModuleConfiguration configuration,
    Map<String, dynamic> record,
    AdminRowAction action,
  );
}

class ModuleRecordForm {
  const ModuleRecordForm({
    required this.fields,
    this.createApi,
    this.resolveCreateApi,
    this.groups = const [],
    this.multipart = false,
    this.showResetButton = false,
    this.method = 'POST',
    this.readOnly = false,
  });

  final List<ModuleFormField> fields;
  final String? createApi;
  final String? Function(Map<String, Object?> values)? resolveCreateApi;
  final List<ModuleFormGroup> groups;
  final bool multipart;
  final bool showResetButton;
  final String method;
  final bool readOnly;
}

class ModuleFormField {
  const ModuleFormField({
    required this.input,
    this.isRequired = false,
    this.isProductCreateHsn = false,
    this.initialValue,
    this.minLength,
    this.maxLength,
    this.isRadio = false,
    this.isPercentage = false,
    this.helperText,
    this.fieldType = '',
    this.allowedValues,
    this.maxValueField,
    this.multipleFiles = false,
    this.maxFileBytes,
  });

  final SearchFilterField input;
  final bool isRequired;
  final bool isProductCreateHsn;
  final String? initialValue;
  final int? minLength;
  final int? maxLength;
  final bool isRadio;
  final bool isPercentage;
  final String? helperText;
  final String fieldType;
  final String? allowedValues;
  final String? maxValueField;
  final bool multipleFiles;
  final int? maxFileBytes;
}

class ModuleFormFile {
  const ModuleFormFile(this.name, this.bytes, this.contentType);

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class ModuleFormGroup {
  const ModuleFormGroup({
    required this.input,
    required this.fields,
    required this.initialRows,
    required this.addLabel,
    this.helperText,
    this.minItems = 0,
    this.maxItems,
    this.uniqueBy,
    this.uniqueTogether = const [],
    this.singleTrueField,
  });

  final SearchFilterField input;
  final List<ModuleFormField> fields;
  final List<Map<String, Object?>> initialRows;
  final String addLabel;
  final String? helperText;
  final int minItems;
  final int? maxItems;
  final String? uniqueBy;
  final List<String> uniqueTogether;
  final String? singleTrueField;
}

class AdminRowAction {
  const AdminRowAction(this.definition);

  final Map<String, dynamic> definition;
  String get name => definition['action']!.toString().trim().toLowerCase();
  bool get isDelete => name == 'delete' || name == 'remove';
  bool get isEdit => name == 'edit' || name == 'update';
  String? get blueprintApi => _entry('blueprintApi');
  String? get explicitMethod =>
      (_entry('httpMethod') ?? _entry('requestMethod') ?? _entry('method'))
          ?.toUpperCase();
  bool get isView =>
      name == 'view' ||
      name == 'details' ||
      (!isEdit && !isDelete && method == 'GET');
  String? get endpoint =>
      _entry('deleteApi') ??
      _entry('updateApi') ??
      _entry('createApi') ??
      _entry('dataApi');
  String? get method =>
      explicitMethod ??
      (isDelete || _entry('deleteApi') != null
          ? 'DELETE'
          : _entry('updateApi') != null
              ? 'PUT'
              : _entry('createApi') != null
                  ? 'POST'
                  : name == 'view' || name == 'details'
                      ? 'GET'
                      : null);
  String get label {
    for (final key in const ['displayName', 'iconToolTip', 'action']) {
      final value = _entry(key);
      if (value != null && !value.startsWith('fa-')) {
        return key == 'action'
            ? '${value[0].toUpperCase()}${value.substring(1)}'
            : value;
      }
    }
    return 'Row action';
  }

  String? _entry(String key) {
    final value = definition[key];
    return value is String &&
            value.trim().isNotEmpty &&
            value.trim() != 'string'
        ? value.trim()
        : null;
  }
}

class AdminModuleConfiguration {
  const AdminModuleConfiguration({
    required this.item,
    required this.blueprint,
    required this.actions,
    this.dataApi,
    this.searchApi,
    this.createApi,
  });

  final MenuItem item;
  final Map<String, dynamic> blueprint;
  final List<Map<String, dynamic>> actions;
  final String? dataApi;
  final String? searchApi;
  final String? createApi;

  Map<String, dynamic>? action(String name) => actions
      .where((action) =>
          action['action']?.toString().trim().toLowerCase() ==
          name.toLowerCase())
      .firstOrNull;

  Iterable<AdminRowAction> get rowActions => _readRowActions();

  Iterable<AdminRowAction> _readRowActions({bool includeHidden = false}) sync* {
    for (final entry in blueprint.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      if ((key != 'rowlevelactions' && key != 'rowactions') || value is! List) {
        continue;
      }
      for (final row in value.whereType<Map>()) {
        final action = row['action'];
        if (action is String &&
            action.trim().isNotEmpty &&
            (includeHidden || row['display'] != false)) {
          yield AdminRowAction(Map<String, dynamic>.from(row));
        }
      }
    }
  }

  Map<String, dynamic>? rowAction(String name, {bool includeHidden = false}) =>
      _readRowActions(includeHidden: includeHidden)
          .where((action) => action.name == name.toLowerCase())
          .firstOrNull
          ?.definition;

  bool needsVariant(AdminRowAction action) {
    final mappings = blueprint['mappings'];
    final overrides = action.definition['mappings'];
    final recordId = (overrides is Map ? overrides['recordId'] : null) ??
        (mappings is Map ? mappings['recordId'] : null);
    final endpoints =
        [action.endpoint, action.blueprintApi].whereType<String>();
    final payloadMapping = action.definition['payloadMapping'];
    return endpoints.any((path) =>
            path.contains('{variantId}') ||
            (recordId == 'variantId' && path.contains('{recordId}'))) ||
        (payloadMapping is Map && payloadMapping.containsValue('variantId'));
  }

  Map<String, dynamic>? get createAction {
    bool isCreateLabel(Object? value) {
      final label = value?.toString().trim().replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (match) => '${match[1]} ${match[2]}',
          );
      return RegExp(r'^(create|add)(?:$|[\s_-])', caseSensitive: false)
          .hasMatch(label ?? '');
    }

    final configured = actions.where((action) =>
        isCreateLabel(action['action']) ||
        isCreateLabel(action['displayName']));
    if (configured.isEmpty && item.isProductManagement) {
      return _productCreateFromEdit();
    }
    return configured
        .where((action) =>
            action['display'] != false && action['blueprintApi'] is String)
        .firstOrNull;
  }

  Map<String, dynamic>? _productCreateFromEdit() {
    final editor = rowActions
        .where((action) => action.isEdit && action.blueprintApi != null)
        .firstOrNull;
    final path = editor?.blueprintApi;
    if (path == null || RegExp(r'\{(?!version\})').hasMatch(path)) return null;
    return {
      'action': 'Create Product',
      'displayName': 'Create',
      'blueprintApi': path,
    };
  }

  String? recordEndpoint(String template, Map<String, dynamic> record,
      {Object? actionMappings}) {
    final mappings = blueprint['mappings'];
    final fields = {
      if (mappings is Map) ...mappings,
      if (actionMappings is Map) ...actionMappings,
    };
    var missingValue = false;
    final resolved = template.replaceAllMapped(RegExp(r'\{([\w]+)\}'), (match) {
      final parameter = match[1]!;
      if (parameter == 'version') return match[0]!;
      final field = fields[parameter] ??
          (parameter == 'recordId' && record['id'] != null ? 'id' : parameter);
      final value = field is String ? recordValue(record, field) : null;
      if (value is! String && value is! num ||
          value.toString().trim().isEmpty) {
        missingValue = true;
        return match[0]!;
      }
      return Uri.encodeComponent(value.toString());
    });
    return missingValue ? null : resolved;
  }

  Object? recordValue(Map<String, dynamic> record, String field) {
    if (record[field] != null) return record[field];
    final direct = field.split('.').fold<Object?>(
        record, (value, key) => value is Map ? value[key] : null);
    if (direct != null || field != 'variantId') return direct;
    final variants = record['variants'];
    if (variants is! List) return null;
    final rows = variants.whereType<Map>().toList(growable: false);
    return rows.length == 1 ? rows.single[field] : null;
  }
}

class SearchFilterField {
  const SearchFilterField({
    required this.field,
    required this.label,
    this.placeholder,
    this.options,
    this.loadOptions,
    this.dependencies = const [],
    this.visibilityCriteria,
    this.quickSearch = true,
  });

  final String field;
  final String label;
  final String? placeholder;
  final Map<String, String>? options;
  final Future<Map<String, String>> Function(Map<String, String>)? loadOptions;
  final List<String> dependencies;
  final String? visibilityCriteria;
  final bool quickSearch;

  bool isVisible(Map<String, String> values) {
    if (dependencies.any((key) => values[key]?.isNotEmpty != true)) {
      return false;
    }
    final criteria = visibilityCriteria?.trim();
    if (criteria == null || criteria.isEmpty) return true;
    final equality = RegExp(r"""^\s*field\.(\w+)\s*==\s*(['"])(.*?)\2\s*$""");
    return criteria.split('&&').every((condition) {
      final match = equality.firstMatch(condition);
      return match != null && values[match[1]] == match[3];
    });
  }

  Object optionsKey(Map<String, String> values) =>
      (this, dependencies.map((field) => values[field]).join('\u0000'));
}

void clearDependentFilterValues(
  Map<String, String> values,
  String changedField,
  Iterable<SearchFilterField> fields,
) {
  final changed = {changedField};
  while (true) {
    final downstream = fields
        .where((field) => field.dependencies.any(changed.contains))
        .map((field) => field.field)
        .where(changed.add)
        .toList(growable: false);
    if (downstream.isEmpty) return;
    downstream.forEach(values.remove);
  }
}

class AdminModuleData {
  const AdminModuleData({
    required this.columns,
    required this.records,
    this.configuration,
    this.products,
  });

  final List<AdminModuleColumn> columns;
  final List<Map<String, dynamic>> records;
  final AdminModuleConfiguration? configuration;
  final List<AdminProduct>? products;
}

class AdminProduct {
  const AdminProduct({
    required this.record,
    required this.product,
    this.imageBytes,
  });

  final Map<String, dynamic> record;
  final Product product;
  final Uint8List? imageBytes;
}

class AdminModuleColumn {
  const AdminModuleColumn(
    this.field,
    this.label, {
    this.showOnMobile = true,
    this.isImage = false,
  });

  final String field;
  final String label;
  final bool showOnMobile;
  final bool isImage;
}
