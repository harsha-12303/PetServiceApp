import '../blueprint/blueprint_models.dart';
import 'form_values.dart';

// Pure helpers for blueprint forms: visibility, defaults, prefill, dependent
// resets, single-true toggles and validation.

final _clause = RegExp(
  r'''^\(?\s*field\.([\w.]+)\s*(==|!=)\s*(['"])(.*?)\3\s*\)?$''',
);

/// Supports only `field.x == 'v'` / `field.x != 'v'` clauses joined with
/// `&&` / `||` (`&&` binds tighter). Empty → visible; unparseable → hidden.
/// [lookup] returns the current value of a field.
bool evaluateVisibility(
    String? criteria, Object? Function(String field) lookup) {
  if (criteria == null || criteria.trim().isEmpty) return true;
  final groups = <List<RegExpMatch>>[];
  for (final orPart in criteria.split('||')) {
    final clauses = <RegExpMatch>[];
    for (final raw in orPart.split('&&')) {
      final m = _clause.firstMatch(raw.trim());
      if (m == null) return false;
      clauses.add(m);
    }
    groups.add(clauses);
  }
  return groups.any((clauses) => clauses.every((m) {
        final actual = _asText(lookup(m.group(1)!));
        final equal = actual == m.group(4);
        return m.group(2) == '==' ? equal : !equal;
      }));
}

/// Visibility of [field] given the form [values]; for a group child pass the
/// [row] too (its values are looked up first).
bool isFieldVisible(BlueprintField field, FormValues values, [GroupRow? row]) =>
    evaluateVisibility(field.visibilityCriteria, (name) {
      if (row != null && row.values.containsKey(name)) return row.values[name];
      return values[name];
    });

String _asText(Object? v) => v == null ? '' : '$v'.trim();

/// The value a field starts with (from `rules.default`).
Object? defaultValueFor(BlueprintField f) {
  final d = f.rules.defaultValue;
  switch (f.type) {
    case FieldType.checkBox:
      return d == true || '$d'.toLowerCase() == 'true';
    case FieldType.fileUpload:
      return FileFieldValue();
    case FieldType.repeatableGroup:
      return List.generate(f.rules.minItems ?? 0, (_) => newGroupRow(f));
    case FieldType.nonrepeatableGroup:
      return newGroupRow(f);
    default:
      return d == null ? null : '$d';
  }
}

GroupRow newGroupRow(BlueprintField group) => GroupRow(values: {
      for (final c in group.childFields) c.field: defaultValueFor(c),
    });

/// Form values for create (no [record]) or edit (prefilled from [record]).
FormValues initialValues(List<BlueprintField> fields,
        [Map<String, dynamic>? record]) =>
    {
      for (final f in fields)
        f.field: record != null && record.containsKey(f.field)
            ? _fromRecord(f, record[f.field])
            : defaultValueFor(f),
    };

Object? _fromRecord(BlueprintField f, Object? v) {
  switch (f.type) {
    case FieldType.checkBox:
      return v == true || '$v'.toLowerCase() == 'true';
    case FieldType.fileUpload:
      return FileFieldValue(keptUrls: _urls(v));
    case FieldType.repeatableGroup:
      final rows = v is List ? v.whereType<Map>().toList() : const <Map>[];
      if (rows.isEmpty) return defaultValueFor(f);
      return rows.map((r) => _serverRow(f, r)).toList();
    case FieldType.nonrepeatableGroup:
      return v is Map ? _serverRow(f, v) : newGroupRow(f);
    default:
      return v == null ? null : '$v';
  }
}

GroupRow _serverRow(BlueprintField group, Map data) => GroupRow(
      fromServer: true,
      values: {
        for (final c in group.childFields)
          c.field: data.containsKey(c.field)
              ? _fromRecord(c, data[c.field])
              : defaultValueFor(c),
      },
    );

List<String> _urls(Object? v) {
  if (v is String && v.trim().isNotEmpty) return [v.trim()];
  if (v is List) {
    return v
        .map((e) => e is Map ? (e['url'] ?? e['imageUrl']) : e)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  return [];
}

/// Sets [fieldName] and resets every field whose `valuesDependOnField`
/// names it (and their dependents in turn) to its default.
FormValues applyFieldChange(
  List<BlueprintField> fields,
  FormValues values,
  String fieldName,
  Object? value,
) {
  final next = Map<String, dynamic>.of(values)..[fieldName] = value;
  final queue = [fieldName];
  final reset = <String>{};
  while (queue.isNotEmpty) {
    final changed = queue.removeAt(0);
    for (final f in fields) {
      if (f.valuesDependOnFields.contains(changed) && reset.add(f.field)) {
        next[f.field] = defaultValueFor(f);
        queue.add(f.field);
      }
    }
  }
  return next;
}

/// Sets a child value in a group row; turning on the group's
/// `singleTrueField` in one row turns it off in all others.
void setGroupChild(
  BlueprintField group,
  List<GroupRow> rows,
  int rowIndex,
  String child,
  Object? value,
) {
  rows[rowIndex].values[child] = value;
  if (child == group.rules.singleTrueField && value == true) {
    for (var i = 0; i < rows.length; i++) {
      if (i != rowIndex) rows[i].values[child] = false;
    }
  }
}

/// Returns error messages keyed by field name, or `group.index.child` for
/// group children (e.g. `variants.0.mrp`). Hidden fields are skipped.
Map<String, String> validateForm(
    List<BlueprintField> fields, FormValues values) {
  final errors = <String, String>{};
  for (final f in fields) {
    if (!isFieldVisible(f, values)) continue;
    final v = values[f.field];
    if (f.isRepeatableGroup) {
      final rows = v is List ? v.whereType<GroupRow>().toList() : <GroupRow>[];
      _validateGroup(f, rows, values, errors);
    } else if (f.isNonRepeatableGroup) {
      _validateRow(
          f, v is GroupRow ? v : GroupRow(values: {}), values, f.field, errors);
    } else {
      final msg = validateValue(f, v);
      if (msg != null) errors[f.field] = msg;
    }
  }
  return errors;
}

void _validateGroup(
  BlueprintField group,
  List<GroupRow> rows,
  FormValues values,
  Map<String, String> errors,
) {
  final r = group.rules;
  if (r.minItems != null && rows.length < r.minItems!) {
    errors[group.field] = 'Add at least ${r.minItems} ${group.displayName}.';
  } else if (r.maxItems != null && rows.length > r.maxItems!) {
    errors[group.field] = 'Add at most ${r.maxItems} ${group.displayName}.';
  } else if (r.mandatory && rows.isEmpty) {
    errors[group.field] = '${group.displayName} is required.';
  }
  for (var i = 0; i < rows.length; i++) {
    _validateRow(group, rows[i], values, '${group.field}.$i', errors);
  }

  String label(String child) => group.childFields
      .firstWhere((c) => c.field == child,
          orElse: () => BlueprintField(
              field: child,
              displayName: child,
              type: FieldType.unknown,
              rawType: ''))
      .displayName;

  for (final child in r.uniqueBy) {
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final v = _asText(rows[i].values[child]).toLowerCase();
      if (v.isEmpty) continue;
      if (!seen.add(v)) {
        errors['${group.field}.$i.$child'] = '${label(child)} must be unique.';
      }
    }
  }
  if (r.uniqueTogether.isNotEmpty) {
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final parts = r.uniqueTogether
          .map((c) => _asText(rows[i].values[c]).toLowerCase())
          .toList();
      if (parts.every((p) => p.isEmpty)) continue;
      if (!seen.add(parts.join('\u0000'))) {
        errors['${group.field}.$i.${r.uniqueTogether.first}'] =
            'This combination of ${r.uniqueTogether.map(label).join(' and ')} is already used.';
      }
    }
  }
}

void _validateRow(
  BlueprintField group,
  GroupRow row,
  FormValues values,
  String prefix,
  Map<String, String> errors,
) {
  for (final child in group.childFields) {
    if (!isFieldVisible(child, values, row)) continue;
    final msg = validateValue(child, row.values[child.field]);
    if (msg != null) errors['$prefix.${child.field}'] = msg;
  }
}

/// Checks one non-group value: mandatory, text length, file type / size.
String? validateValue(BlueprintField f, Object? v) {
  final r = f.rules;
  final name = f.displayName;
  if (f.isFile) {
    final files = v is FileFieldValue ? v : FileFieldValue();
    if (r.mandatory && files.isEmpty) return '$name is required.';
    final maxBytes = r.maxBytes;
    for (final file in files.newFiles) {
      if (r.allowValues.isNotEmpty && !r.allowValues.contains(file.extension)) {
        return '$name: only ${r.allowValues.join(', ')} files are allowed.';
      }
      if (maxBytes != null && file.size > maxBytes) {
        return '$name: each file must be ${r.maxSize} or smaller.';
      }
    }
    return null;
  }
  if (f.type == FieldType.checkBox) return null;
  final text = _asText(v);
  if (text.isEmpty) return r.mandatory ? '$name is required.' : null;
  if (f.type == FieldType.textBox) {
    final min = r.minLength;
    final max = r.maxLength;
    if (min != null && text.length < min) {
      return '$name must be at least $min characters.';
    }
    if (max != null && text.length > max) {
      return '$name must be at most $max characters.';
    }
  }
  return null;
}
