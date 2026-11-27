// Typed views of the backend "blueprint" JSON. Records stay
// Map<String, dynamic> because their shape comes from the blueprint columns.

typedef Json = Map<String, dynamic>;

Json _asJson(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Json> _jsonList(Object? v) =>
    v is List ? v.whereType<Map>().map(Map<String, dynamic>.from).toList() : [];

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

bool? _bool(Object? v) {
  if (v is bool) return v;
  final s = _str(v)?.toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return null;
}

int? _int(Object? v) {
  if (v is num) return v.toInt();
  final s = _str(v);
  return s == null ? null : int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

List<String> _csv(Object? v) {
  if (v is List) {
    return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }
  return (_str(v) ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

// ---------------------------------------------------------------- actions

/// A header button (`actions`) or per-record action (`rowLevelactions`).
class BlueprintAction {
  BlueprintAction({
    required this.action,
    this.displayName,
    this.iconName,
    this.iconToolTip,
    this.blueprintApi,
    this.dataApi,
    this.createApi,
    this.display = true,
    this.raw = const {},
  });

  factory BlueprintAction.fromJson(Json json) => BlueprintAction(
        action: _str(json['action']) ?? '',
        displayName: _str(json['displayName']),
        iconName: _str(json['iconName']),
        iconToolTip: _str(json['iconToolTip']),
        blueprintApi: _firstNonEmpty(json, _blueprintKeys),
        dataApi: _str(json['dataApi']),
        createApi: _str(json['createApi']),
        display: _bool(json['display']) ?? true,
        raw: json,
      );

  /// The backend spells the form link several ways; first non-empty wins.
  static const _blueprintKeys = [
    'blueprintApi',
    'bluePrintApi',
    'blueprintUrl',
    'bluePrintUrl',
    'blueprintAPI',
    'bluePrintAPI',
  ];

  final String action;
  final String? displayName;
  final String? iconName;
  final String? iconToolTip;
  final String? blueprintApi;
  final String? dataApi;
  final String? createApi;

  /// false → no button, but the action still runs (e.g. "view" on tap).
  final bool display;
  final Json raw;

  /// First of displayName / iconToolTip that isn't an `fa-` icon name, else [action].
  String get label {
    for (final s in [displayName, iconToolTip]) {
      if (s != null && !s.startsWith('fa-')) return s;
    }
    return action;
  }

  /// The Font Awesome name (`fa-edit`…) from iconName, iconToolTip or displayName.
  String? get faIcon {
    for (final s in [iconName, iconToolTip, displayName]) {
      if (s == null) continue;
      final match = RegExp(r'fa-[\w-]+').firstMatch(s);
      if (match != null) return match.group(0);
    }
    return null;
  }

  String get _names => [action, displayName, iconName, iconToolTip]
      .whereType<String>()
      .join(' ')
      .toLowerCase();

  bool get mentionsCart => _names.contains('cart');

  bool get isView => action.toLowerCase() == 'view';
  bool get isDelete => action.toLowerCase() == 'delete';
  bool get isEdit {
    final icon = faIcon ?? '';
    return action.toLowerCase() == 'edit' ||
        label.toLowerCase() == 'edit' ||
        icon == 'fa-edit' ||
        icon.startsWith('fa-pen');
  }

  static String? _firstNonEmpty(Json json, List<String> keys) {
    for (final k in keys) {
      final v = _str(json[k]);
      if (v != null) return v;
    }
    return null;
  }
}

// ---------------------------------------------------------------- table

class GridColumn {
  const GridColumn({
    required this.field,
    required this.displayName,
    required this.display,
    required this.mobileDisplay,
  });

  factory GridColumn.fromJson(Json json) => GridColumn(
        field: _str(json['field']) ?? '',
        displayName: _str(json['displayName']) ?? _str(json['field']) ?? '',
        display: _bool(json['display']) ?? true,
        mobileDisplay: _bool(json['mobileDisplay']) ?? true,
      );

  final String field;
  final String displayName;
  final bool display;
  final bool mobileDisplay;
}

class DisplayMode {
  const DisplayMode(this.label, this.value);
  final String label;
  final String value;
}

class TableBlueprint {
  TableBlueprint({
    required this.columns,
    required this.dataApi,
    required this.actions,
    required this.rowActions,
    required this.enableMultipleDisplayModes,
    required this.defaultDisplayMode,
    required this.availableDisplayModes,
    required this.recordIdField,
    required this.raw,
  });

  factory TableBlueprint.fromJson(Json json) => TableBlueprint(
        columns: _jsonList(json['dataGrid']).map(GridColumn.fromJson).toList(),
        dataApi: _str(json['dataApi']),
        actions:
            _jsonList(json['actions']).map(BlueprintAction.fromJson).toList(),
        rowActions:
            _jsonList(json['rowLevelactions'] ?? json['rowLevelActions'])
                .map(BlueprintAction.fromJson)
                .toList(),
        enableMultipleDisplayModes:
            _bool(json['enableMultipleDisplayModes']) ?? false,
        defaultDisplayMode: _str(json['defaultDisplayMode']),
        availableDisplayModes: _jsonList(json['availableDisplayModes'])
            .map((m) => DisplayMode(_str(m['label']) ?? _str(m['value']) ?? '',
                _str(m['value']) ?? ''))
            .toList(),
        recordIdField: _str(_asJson(json['mappings'])['recordId']),
        raw: json,
      );

  /// All columns, including hidden ones; use [visibleColumns] for display.
  final List<GridColumn> columns;
  final String? dataApi;
  final List<BlueprintAction> actions;
  final List<BlueprintAction> rowActions;
  final bool enableMultipleDisplayModes;
  final String? defaultDisplayMode;
  final List<DisplayMode> availableDisplayModes;

  /// `mappings.recordId`: which record field is the row id.
  final String? recordIdField;
  final Json raw;

  List<GridColumn> get visibleColumns =>
      columns.where((c) => c.display).toList();

  String? recordIdOf(Map<String, dynamic> record) =>
      recordIdField == null ? null : _str(record[recordIdField]);
}

// ---------------------------------------------------------------- fields

enum FieldType {
  textBox,
  checkBox,
  radioButton,
  dropDown,
  cascadeDropDown,
  fileUpload,
  repeatableGroup,
  nonrepeatableGroup,
  unknown;

  static FieldType parse(String? raw) {
    final s = (raw ?? '').toLowerCase();
    for (final t in values) {
      if (t.name.toLowerCase() == s) return t;
    }
    return unknown;
  }
}

/// All rule objects in `rules: [...]` merged; numbers arrive as strings.
class FieldRules {
  const FieldRules({
    this.mandatory = false,
    this.minSize,
    this.maxSize,
    this.allowValues = const [],
    this.defaultValue,
    this.multiple = false,
    this.minItems,
    this.maxItems,
    this.uniqueBy = const [],
    this.uniqueTogether = const [],
    this.singleTrueField,
  });

  factory FieldRules.fromJson(Object? rules) {
    final merged = <String, dynamic>{};
    for (final r in _jsonList(rules)) {
      merged.addAll(r);
    }
    return FieldRules(
      mandatory: _bool(merged['mandatory']) ?? false,
      minSize: _str(merged['minSize']),
      maxSize: _str(merged['maxSize']),
      allowValues: _csv(merged['allowValues'])
          .map((e) => e.toLowerCase().replaceFirst('.', ''))
          .toList(),
      defaultValue: merged['default'],
      multiple: _bool(merged['multiple']) ?? false,
      minItems: _int(merged['minItems']),
      maxItems: _int(merged['maxItems']),
      uniqueBy: _csv(merged['uniqueBy']),
      uniqueTogether: _csv(merged['uniqueTogether']),
      singleTrueField: _str(merged['singleTrueField']),
    );
  }

  final bool mandatory;

  /// Text length for text fields; kept raw because file fields use "2MB".
  final String? minSize;
  final String? maxSize;

  /// Allowed file extensions, lower case, without the dot.
  final List<String> allowValues;
  final Object? defaultValue;
  final bool multiple;
  final int? minItems;
  final int? maxItems;
  final List<String> uniqueBy;
  final List<String> uniqueTogether;
  final String? singleTrueField;

  int? get minLength => _int(minSize);
  int? get maxLength => _int(maxSize);

  /// `maxSize` as a byte count ("2MB", "500KB", "1048576").
  int? get maxBytes => parseByteSize(maxSize);
}

int? parseByteSize(String? raw) {
  final m = RegExp(r'^\s*([\d.]+)\s*([kmg]?b?)?\s*$', caseSensitive: false)
      .firstMatch(raw ?? '');
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null) return null;
  final unit = (m.group(2) ?? '').toLowerCase();
  final mult = unit.startsWith('g')
      ? 1024 * 1024 * 1024
      : unit.startsWith('m')
          ? 1024 * 1024
          : unit.startsWith('k')
              ? 1024
              : 1;
  return (n * mult).round();
}

class DropdownOption {
  const DropdownOption(this.value, this.label);
  final String value;
  final String label;
}

class BlueprintField {
  BlueprintField({
    required this.field,
    required this.displayName,
    required this.type,
    required this.rawType,
    this.placeholder,
    this.toolTip,
    this.editable = true,
    this.api,
    this.radioValues = const [],
    this.visibilityCriteria,
    this.valuesDependOnFields = const [],
    this.dropdownCode,
    this.dropdownValue,
    this.staticDropDownValues = const [],
    this.quickSearchFilter = false,
    this.rules = const FieldRules(),
    this.childFields = const [],
    this.addButtonLabel,
    this.raw = const {},
  });

  factory BlueprintField.fromJson(Json json) => BlueprintField(
        field: _str(json['field']) ?? '',
        displayName: _str(json['displayName']) ?? _str(json['field']) ?? '',
        type: FieldType.parse(_str(json['fieldType'])),
        rawType: _str(json['fieldType']) ?? '',
        placeholder: _str(json['placeholder']),
        toolTip: _str(json['toolTip']),
        editable: _bool(json['editable']) ?? true,
        api: _str(json['api']),
        radioValues: _jsonList(json['values'])
            .map((v) => _str(v['radioValue']))
            .whereType<String>()
            .toList(),
        visibilityCriteria: _str(json['visibilityCriteria']),
        valuesDependOnFields: _csv(json['valuesDependOnField']),
        dropdownCode: _str(json['dropdownCode']),
        dropdownValue: _str(json['dropdownValue']),
        staticDropDownValues: _jsonList(json['staticDropDownValues']),
        quickSearchFilter: _bool(json['quickSearchFilter']) ?? false,
        rules: FieldRules.fromJson(json['rules']),
        childFields: _jsonList(json['childFields'])
            .map(BlueprintField.fromJson)
            .toList(),
        addButtonLabel: _str(json['addButtonLabel']),
        raw: json,
      );

  final String field;
  final String displayName;
  final FieldType type;
  final String rawType;
  final String? placeholder;
  final String? toolTip;

  /// false → settable on create only, read-only on edit.
  final bool editable;
  final String? api;
  final List<String> radioValues;
  final String? visibilityCriteria;
  final List<String> valuesDependOnFields;
  final String? dropdownCode;
  final String? dropdownValue;
  final List<Json> staticDropDownValues;
  final bool quickSearchFilter;
  final FieldRules rules;
  final List<BlueprintField> childFields;
  final String? addButtonLabel;
  final Json raw;

  bool get isDropdown =>
      type == FieldType.dropDown || type == FieldType.cascadeDropDown;
  bool get isFile => type == FieldType.fileUpload;
  bool get isRepeatableGroup => type == FieldType.repeatableGroup;
  bool get isNonRepeatableGroup => type == FieldType.nonrepeatableGroup;
  bool get isGroup => isRepeatableGroup || isNonRepeatableGroup;
  bool get isMultipleFile => isFile && rules.multiple;

  /// The field itself or any group child is a file upload.
  bool get hasFiles => isFile || childFields.any((c) => c.hasFiles);

  /// Maps a dropdown row to an option; null when its code is missing.
  DropdownOption? optionFrom(Map row) {
    final value = _str(row[dropdownCode ?? 'code']);
    if (value == null) return null;
    return DropdownOption(value, _str(row[dropdownValue ?? 'name']) ?? value);
  }
}

// ---------------------------------------------------------------- search / form

class SearchBlueprint {
  SearchBlueprint(this.fields);

  factory SearchBlueprint.fromJson(Json json) => SearchBlueprint(
      _jsonList(json['searchForm']).map(BlueprintField.fromJson).toList());

  final List<BlueprintField> fields;

  /// Shown inline in the search bar.
  List<BlueprintField> get quickFields =>
      fields.where((f) => f.quickSearchFilter).toList();

  /// Everything else goes in the "More filters" sheet, including fields the
  /// backend adds later.
  List<BlueprintField> get moreFields =>
      fields.where((f) => !f.quickSearchFilter).toList();
}

class FormBlueprint {
  FormBlueprint({
    required this.displayName,
    required this.fields,
    required this.createApi,
    required this.dataApi,
    required this.recordIdField,
    required this.refreshOnSave,
    required this.resetButton,
    required this.raw,
  });

  factory FormBlueprint.fromJson(Json json) => FormBlueprint(
        displayName: _str(json['displayName']),
        fields:
            _jsonList(json['editForm']).map(BlueprintField.fromJson).toList(),
        createApi: _str(json['createApi']),
        dataApi: _str(json['dataApi']),
        recordIdField: _str(_asJson(json['mappings'])['recordId']),
        refreshOnSave: _bool(json['refreshOnSave']) ?? true,
        resetButton: _bool(json['resetButton']) ?? false,
        raw: json,
      );

  final String? displayName;
  final List<BlueprintField> fields;
  final String? createApi;
  final String? dataApi;
  final String? recordIdField;
  final bool refreshOnSave;
  final bool resetButton;
  final Json raw;

  /// Any file field, top-level or in a group → the body is always multipart.
  bool get usesMultipart => fields.any((f) => f.hasFiles);
}
