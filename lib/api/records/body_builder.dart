import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../blueprint/blueprint_models.dart';
import 'form_values.dart';

/// Builds the save body for a form: multipart when any field (or group
/// child) is a file upload, even if no new file was picked; JSON otherwise.
Object buildSaveBody(
  FormBlueprint form,
  FormValues values, {
  List<String> removedImages = const [],
}) =>
    form.usesMultipart
        ? buildMultipartBody(form.fields, values, removedImages: removedImages)
        : buildJsonBody(form.fields, values, removedImages: removedImages);

/// JSON: text trimmed, unset → null, file fields omitted, groups as
/// list / object, `removeImages` when any server image was removed.
Map<String, dynamic> buildJsonBody(
  List<BlueprintField> fields,
  FormValues values, {
  List<String> removedImages = const [],
}) {
  final body = <String, dynamic>{};
  for (final f in fields) {
    if (f.isFile) continue;
    body[f.field] = _fieldJson(f, values[f.field]);
  }
  if (removedImages.isNotEmpty) body['removeImages'] = List.of(removedImages);
  return body;
}

/// Multipart: plain values as string parts, groups as JSON-string parts,
/// new files as `field`, `group[i][child]` or `group[child]` parts, and one
/// `removeImages` part per removed server image.
FormData buildMultipartBody(
  List<BlueprintField> fields,
  FormValues values, {
  List<String> removedImages = const [],
}) {
  final form = FormData();
  for (final f in fields) {
    final v = values[f.field];
    if (f.isFile) {
      for (final file in _newFiles(f, v)) {
        form.files.add(MapEntry(f.field, toMultipartFile(file)));
      }
    } else if (f.isRepeatableGroup) {
      final rows = v is List ? v.whereType<GroupRow>().toList() : <GroupRow>[];
      form.fields.add(MapEntry(f.field, jsonEncode(_fieldJson(f, rows))));
      for (var i = 0; i < rows.length; i++) {
        _addChildFiles(form, f, rows[i], '${f.field}[$i]');
      }
    } else if (f.isNonRepeatableGroup) {
      form.fields.add(MapEntry(f.field, jsonEncode(_fieldJson(f, v))));
      if (v is GroupRow) _addChildFiles(form, f, v, f.field);
    } else {
      form.fields.add(MapEntry(f.field, _fieldString(f, v)));
    }
  }
  for (final url in removedImages) {
    form.fields.add(MapEntry('removeImages', url));
  }
  return form;
}

void _addChildFiles(
    FormData form, BlueprintField group, GroupRow row, String prefix) {
  for (final child in group.childFields.where((c) => c.isFile)) {
    for (final file in _newFiles(child, row.values[child.field])) {
      form.files
          .add(MapEntry('$prefix[${child.field}]', toMultipartFile(file)));
    }
  }
}

List<PickedFile> _newFiles(BlueprintField f, Object? v) {
  if (v is! FileFieldValue) return const [];
  return f.rules.multiple ? v.newFiles : v.newFiles.take(1).toList();
}

Object? _fieldJson(BlueprintField f, Object? v) {
  if (f.isRepeatableGroup) {
    final rows = v is List ? v.whereType<GroupRow>() : const <GroupRow>[];
    return rows.map((r) => _rowJson(f, r)).toList();
  }
  if (f.isNonRepeatableGroup) {
    return _rowJson(f, v is GroupRow ? v : GroupRow(values: {}));
  }
  if (f.type == FieldType.checkBox) return _asBool(v);
  if (v is String) return v.trim();
  return v;
}

Map<String, dynamic> _rowJson(BlueprintField group, GroupRow row) {
  final out = <String, dynamic>{};
  for (final child in group.childFields) {
    final v = row.values[child.field];
    if (child.isFile) {
      // New rows: leave file children out. Server rows: the URLs still kept.
      if (!row.fromServer) continue;
      final kept = v is FileFieldValue ? v.keptUrls : const <String>[];
      out[child.field] = child.rules.multiple
          ? List.of(kept)
          : (kept.isEmpty ? null : kept.first);
    } else {
      out[child.field] = _fieldJson(child, v);
    }
  }
  return out;
}

String _fieldString(BlueprintField f, Object? v) {
  if (f.type == FieldType.checkBox) {
    return (_asBool(v) ?? false) ? 'true' : 'false';
  }
  if (v == null) return '';
  if (v is String) return v.trim();
  return '$v';
}

bool? _asBool(Object? v) {
  if (v is bool) return v;
  if (v == null) return null;
  final s = '$v'.trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0' || s.isEmpty) return false;
  return null;
}

MultipartFile toMultipartFile(PickedFile file) {
  final type = _mediaTypeFor(file.extension);
  final bytes = file.bytes;
  if (bytes != null) {
    return MultipartFile.fromBytes(bytes,
        filename: file.name, contentType: type);
  }
  final path = file.path;
  if (path == null) {
    throw ArgumentError(
        'Picked file "${file.name}" has neither bytes nor a path.');
  }
  return MultipartFile.fromFileSync(path,
      filename: file.name, contentType: type);
}

MediaType? _mediaTypeFor(String ext) => switch (ext) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      'svg' => MediaType('image', 'svg+xml'),
      'pdf' => MediaType('application', 'pdf'),
      _ => null,
    };
