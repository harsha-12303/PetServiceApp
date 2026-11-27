import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_config.dart';
import '../../../domain/repositories/admin_module_repository.dart';

class ModuleRecordGroup extends StatefulWidget {
  const ModuleRecordGroup({
    super.key,
    required this.group,
    required this.enabled,
    required this.onSaved,
    this.canUpload = false,
  });

  final ModuleFormGroup group;
  final bool enabled;
  final bool canUpload;
  final ValueChanged<List<Map<String, Object?>>> onSaved;

  @override
  State<ModuleRecordGroup> createState() => _ModuleRecordGroupState();
}

class _ModuleRecordGroupState extends State<ModuleRecordGroup> {
  static const _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };
  bool _picking = false;
  late final _rows = widget.group.initialRows
      .map((row) => Map<String, Object?>.of(row))
      .toList();

  Map<String, Object?> _newRow() => {
        for (final field in widget.group.fields)
          if (field.fieldType == 'checkbox')
            field.input.field: field.initialValue == 'true'
          else if (field.initialValue?.isNotEmpty == true)
            field.input.field: field.initialValue,
      };

  String _text(Map<String, Object?> row, String field) =>
      row[field]?.toString().trim() ?? '';

  String? _validateRows() {
    final group = widget.group;
    if (_picking) return 'Wait for the selected images to finish loading.';
    if (widget.canUpload) {
      for (final row in _rows) {
        for (final field in group.fields) {
          if (field.fieldType == 'fileupload' &&
              field.isRequired &&
              _selectedFiles(row, field).isEmpty) {
            return 'Choose ${field.input.label} for every size.';
          }
        }
      }
    }
    if (_rows.length < group.minItems) {
      return 'Add at least ${group.minItems} size row(s).';
    }
    if (group.maxItems case final max? when _rows.length > max) {
      return 'Use at most $max size rows.';
    }
    if (group.uniqueBy case final field?) {
      if (_rows.map((row) => _text(row, field).toLowerCase()).toSet().length <
          _rows.length) {
        return 'Each size must have a unique ${_label(field)}.';
      }
    }
    if (group.uniqueTogether.isNotEmpty &&
        _rows
                .map((row) => group.uniqueTogether
                    .map((field) => _text(row, field).toLowerCase())
                    .join('\u0000'))
                .toSet()
                .length <
            _rows.length) {
      return 'Each size must have a unique ${group.uniqueTogether.map(_label).join(' and ')}.';
    }
    if (group.singleTrueField case final field?) {
      if (_rows.where((row) => _text(row, field) == 'true').length > 1) {
        return 'Select only one ${_label(field)}.';
      }
    }
    return null;
  }

  String _label(String name) =>
      widget.group.fields
          .where((field) => field.input.field == name)
          .map((field) => field.input.label)
          .firstOrNull ??
      name;

  bool _isPrice(ModuleFormField field) =>
      const {'mrpPrice', 'finalPrice'}.contains(field.input.field) ||
      field.maxValueField != null;

  List<Map<String, Object?>> _payload() => [
        for (final row in _rows)
          {
            ...row,
            for (final field in widget.group.fields)
              if (_isPrice(field) && _text(row, field.input.field).isNotEmpty)
                field.input.field: num.parse(_text(row, field.input.field))
              else if (field.allowedValues == 'onlyDigital' &&
                  _text(row, field.input.field).isNotEmpty)
                field.input.field: int.parse(_text(row, field.input.field))
              else if (field.fieldType == 'checkbox')
                field.input.field: _text(row, field.input.field) == 'true',
          },
      ];

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return FormField<void>(
      validator: (_) => _validateRows(),
      onSaved: (_) => widget.onSaved(_payload()),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(group.input.label,
              style: Theme.of(context).textTheme.titleLarge),
          if (group.helperText case final text?) Text(text),
          for (final (index, row) in _rows.indexed)
            Card.outlined(
              key: ObjectKey(row),
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Size ${index + 1}')),
                      if (widget.enabled)
                        IconButton(
                          tooltip: 'Remove size ${index + 1}',
                          onPressed: _rows.length <= group.minItems
                              ? null
                              : () => setState(() => _rows.removeAt(index)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ]),
                    for (final field in group.fields)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildField(row, field),
                      ),
                  ],
                ),
              ),
            ),
          if (state.errorText case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (widget.enabled)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed:
                    group.maxItems != null && _rows.length >= group.maxItems!
                        ? null
                        : () => setState(() => _rows.add(_newRow())),
                label: Text(group.addLabel),
                icon: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, Object?> row, ModuleFormField field) {
    final name = field.input.field;
    if (field.fieldType == 'checkbox') {
      return CheckboxListTile(
        title: Text(field.input.label),
        subtitle: field.helperText == null ? null : Text(field.helperText!),
        value: _text(row, name) == 'true',
        onChanged: !widget.enabled
            ? null
            : (value) => setState(() {
                  if (value == true && widget.group.singleTrueField == name) {
                    for (final other in _rows) {
                      other[name] = false;
                    }
                  }
                  row[name] = value == true;
                }),
      );
    }
    if (field.fieldType == 'fileupload') {
      if (widget.canUpload) return _uploadField(row, field);
      final value = row[name];
      final links = (value is List
              ? value.whereType<String>()
              : [if (value is String) value])
          .where((path) => Uri.tryParse(path)?.scheme == 'https');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.input.label),
          if (links.isEmpty) const Text('No image'),
          if (links.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final link in links)
                  Image.network(
                    ApiConfig.resolveImageUrl(link)!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.square(
                      dimension: 64,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
              ],
            ),
        ],
      );
    }
    final isPrice = _isPrice(field);
    final isInteger = field.allowedValues == 'onlyDigital';
    return TextFormField(
      initialValue: _text(row, name),
      enabled: widget.enabled,
      keyboardType: isPrice || isInteger
          ? TextInputType.numberWithOptions(decimal: isPrice)
          : null,
      decoration: InputDecoration(
        labelText:
            field.isRequired ? '${field.input.label} *' : field.input.label,
        hintText: field.input.placeholder,
        helperText: field.helperText,
        helperMaxLines: 3,
      ),
      onChanged: (value) {
        final text = value.trim();
        if (text.isEmpty) {
          row.remove(name);
        } else {
          row[name] = text;
        }
      },
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return field.isRequired ? 'Enter ${field.input.label}' : null;
        }
        if (field.minLength case final min? when text.length < min) {
          return 'Use at least $min characters.';
        }
        if (field.maxLength case final max? when text.length > max) {
          return 'Use at most $max characters.';
        }
        if (isInteger &&
            (!RegExp(r'^\d+$').hasMatch(text) || int.tryParse(text) == null)) {
          return 'Enter a whole number.';
        }
        if (isPrice) {
          final price = num.tryParse(text);
          if (price == null || !price.isFinite || price < 0) {
            return 'Enter a valid price.';
          }
          if (field.maxValueField case final limit?) {
            final maximum = num.tryParse(_text(row, limit));
            if (maximum != null && price > maximum) {
              return 'Price must be at most ${_label(limit)}.';
            }
          }
        }
        return null;
      },
    );
  }

  List<ModuleFormFile> _selectedFiles(
      Map<String, Object?> row, ModuleFormField field) {
    final value = row[field.input.field];
    return value is List<ModuleFormFile> ? value : const [];
  }

  Widget _uploadField(Map<String, Object?> row, ModuleFormField field) {
    final selected = _selectedFiles(row, field);
    final enabled = widget.enabled && !_picking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.input.label),
        if (selected.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final file in selected)
                InputChip(
                  label: Text(file.name, overflow: TextOverflow.ellipsis),
                  onDeleted: !enabled
                      ? null
                      : () => setState(() {
                            row[field.input.field] = [
                              for (final other in selected)
                                if (other != file) other,
                            ];
                          }),
                ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickImages(row, field) : null,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text('Choose ${field.input.label}'),
        ),
      ],
    );
  }

  Future<void> _pickImages(
      Map<String, Object?> row, ModuleFormField field) async {
    final extensions =
        (field.allowedValues?.toLowerCase().split(',') ?? _imageTypes.keys)
            .map((value) => value.trim())
            .where(_imageTypes.containsKey)
            .toList();
    if (extensions.isEmpty) return;
    setState(() => _picking = true);
    String? error;
    try {
      final List<PlatformFile> files;
      if (field.multipleFiles) {
        files = await FilePicker.pickFiles(
            type: FileType.custom, allowedExtensions: extensions);
      } else {
        final file = await FilePicker.pickFile(
            type: FileType.custom, allowedExtensions: extensions);
        files = [if (file != null) file];
      }
      final selected = <ModuleFormFile>[];
      for (final file in files) {
        final extension = file.extension?.toLowerCase();
        final length = await file.length();
        final max = field.maxFileBytes;
        if (!extensions.contains(extension) ||
            length == 0 ||
            (max != null && length != null && length > max)) {
          error = '${file.name} does not meet the image type or size limit.';
          break;
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty || (max != null && bytes.length > max)) {
          error = '${file.name} does not meet the image size limit.';
          break;
        }
        selected.add(ModuleFormFile(file.name, bytes, _imageTypes[extension]!));
      }
      if (mounted &&
          widget.enabled &&
          _rows.contains(row) &&
          error == null &&
          selected.isNotEmpty) {
        setState(() => row[field.input.field] = selected);
      }
    } on Exception {
      error = 'Could not open the selected images.';
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        if (error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        }
      }
    }
  }
}
