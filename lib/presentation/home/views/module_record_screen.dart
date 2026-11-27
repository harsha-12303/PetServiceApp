import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../shared/widgets/blueprint_dropdown.dart';
import 'module_record_group.dart';

class ModuleRecordScreen extends StatefulWidget {
  const ModuleRecordScreen({
    super.key,
    required this.load,
    required this.submit,
    required this.title,
    required this.sectionName,
  });

  final Future<ModuleRecordForm> Function() load;
  final Future<void> Function(ModuleRecordForm, Map<String, Object?>) submit;
  final String title;
  final String sectionName;

  @override
  State<ModuleRecordScreen> createState() => _ModuleRecordScreenState();
}

class _ModuleRecordScreenState extends State<ModuleRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _values = <String, Object?>{};
  final _draft = <String, String>{};
  late Future<ModuleRecordForm> _form = _loadForm();
  int _resetGeneration = 0;
  bool _saving = false;
  String? _error;

  Future<ModuleRecordForm> _loadForm() async {
    final form = await widget.load();
    _restoreDefaults(form);
    return form;
  }

  void _restoreDefaults(ModuleRecordForm form) {
    _draft
      ..clear()
      ..addEntries(
        form.fields
            .where((field) => field.initialValue?.isNotEmpty == true)
            .map((field) => MapEntry(field.input.field, field.initialValue!)),
      );
  }

  void _changeValue(ModuleRecordForm form, String field, String? value) {
    if (_draft[field] == value) return;
    setState(() {
      if (value == null || value.isEmpty) {
        _draft.remove(field);
      } else {
        _draft[field] = value;
      }
      clearDependentFilterValues(
        _draft,
        field,
        form.fields.map((field) => field.input),
      );
    });
  }

  Future<void> _save(ModuleRecordForm form) async {
    if (_saving) return;
    final formState = _formKey.currentState!;
    final invalidFields = formState.validateGranularly();
    if (invalidFields.isNotEmpty) {
      FocusScope.of(context).unfocus();
      setState(() => _error = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final first = invalidFields.first;
        if (!mounted || !first.mounted) return;
        Scrollable.ensureVisible(first.context,
            duration: const Duration(milliseconds: 250), alignment: 0.15);
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _values.clear();
      formState.save();
      await widget.submit(form, Map.of(_values));
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is AppException
            ? error.message
            : 'Could not save the record.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          backgroundColor: AppColors.primarySoft,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            surfaceTintColor: AppColors.primary,
            toolbarHeight: 74,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w800)),
                Text(widget.sectionName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryTint,
                    )),
              ],
            ),
          ),
          body: FutureBuilder<ModuleRecordForm>(
            future: _form,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error is AppException
                          ? error.message
                          : 'Could not load the record form.'),
                      TextButton(
                        onPressed: () {
                          final form = _loadForm();
                          setState(() {
                            _form = form;
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ]),
                  ),
                );
              }
              return _buildForm(context, snapshot.requireData);
            },
          ),
        ),
      );

  Widget _buildForm(BuildContext context, ModuleRecordForm form) {
    final visible = form.fields.where((field) => field.input.isVisible(_draft));
    final general = visible.where((field) => !field.isRadio).toList();
    final organize = visible.where((field) => field.isRadio).toList();
    return Form(
      key: _formKey,
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 &&
            general.isNotEmpty &&
            organize.isNotEmpty;
        final gutter = constraints.maxWidth > 1280
            ? (constraints.maxWidth - 1240) / 2
            : (columns ? 24.0 : 16.0);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, columns ? 28 : 16, gutter, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 3,
                      child: _section(context, form, 'General Information',
                          general, Icons.description_outlined)),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 2,
                      child: _section(context, form, 'Organize', organize,
                          Icons.category_outlined)),
                ],
              )
            else ...[
              if (general.isNotEmpty)
                _section(context, form, 'General Information', general,
                    Icons.description_outlined),
              if (general.isNotEmpty && organize.isNotEmpty)
                const SizedBox(height: 16),
              if (organize.isNotEmpty)
                _section(context, form, 'Organize', organize,
                    Icons.category_outlined),
            ],
            for (final group in form.groups)
              if (group.input.isVisible(_draft)) ...[
                const SizedBox(height: 16),
                _panel(
                  context,
                  ModuleRecordGroup(
                    key: ValueKey((group, _resetGeneration)),
                    group: group,
                    enabled: !_saving && !form.readOnly,
                    canUpload: form.multipart,
                    onSaved: (rows) => _values[group.input.field] = rows,
                  ),
                ),
              ],
            const SizedBox(height: 16),
            _panel(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (form.createApi == null && !form.readOnly)
                    const Text(
                        'This form has no usable Save endpoint in its blueprint.'),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        )),
                  Row(
                    children: [
                      if (form.showResetButton && !form.readOnly)
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _restoreDefaults(form);
                                    _resetGeneration++;
                                    _error = null;
                                  });
                                },
                          child: const Text('Reset'),
                        ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                      if (!form.readOnly) ...[
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saving || form.createApi == null
                              ? null
                              : () => _save(form),
                          child: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _section(BuildContext context, ModuleRecordForm form, String title,
          List<ModuleFormField> fields, IconData icon) =>
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ))),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            for (final field in fields)
              Padding(
                key: ValueKey((field, _resetGeneration)),
                padding: const EdgeInsets.only(top: 18),
                child: _buildField(form, field),
              ),
          ],
        ),
      );

  Widget _panel(BuildContext context, Widget child) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.09),
              blurRadius: 16,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: child,
      );

  Widget _buildField(ModuleRecordForm form, ModuleFormField field) {
    final input = field.input;
    final enabled = !_saving && !form.readOnly;
    final decoration = InputDecoration(
      labelText: field.isRequired ? '${input.label} *' : input.label,
      hintText: input.placeholder,
      helperText: field.helperText,
      helperMaxLines: 4,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
    String? validate(String? value) {
      final text = value?.trim() ?? '';
      final size = text.length;
      if (size == 0) {
        return field.isRequired
            ? '${input.options == null && input.loadOptions == null ? 'Enter' : 'Select'} ${input.label}'
            : null;
      }
      if (field.isProductCreateHsn) {
        return RegExp(r'^\d{4}(?:\d{2}){0,2}$').hasMatch(text)
            ? null
            : 'Enter a 4, 6, or 8 digit HSN code.';
      }
      if (field.minLength case final minimum? when size < minimum) {
        return 'Use at least $minimum characters.';
      }
      if (field.maxLength case final maximum? when size > maximum) {
        return 'Use at most $maximum characters.';
      }
      if (field.isPercentage) {
        final percent = num.tryParse(text);
        if (percent == null ||
            percent <= 0 ||
            percent > 100 ||
            !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
          return 'Enter a percentage above 0 and up to 100 with up to 2 decimals.';
        }
      }
      return null;
    }

    void save(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) _values[input.field] = text;
    }

    final options = input.options;
    if (input.loadOptions != null) {
      return BlueprintDropdown(
        key: ValueKey((input.optionsKey(_draft), _resetGeneration)),
        field: input,
        values: _draft,
        decoration: decoration,
        emptyLabel: 'Select',
        enabled: enabled,
        onChanged: (value) => _changeValue(form, input.field, value),
        validator: validate,
        onSaved: save,
      );
    }
    if (field.isRadio && options != null) {
      return FormField<String>(
        initialValue: _draft[input.field],
        validator: validate,
        onSaved: save,
        builder: (state) => InputDecorator(
          decoration: decoration.copyWith(errorText: state.errorText),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in options.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: state.value == option.key,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: state.value == option.key
                        ? AppColors.onPrimary
                        : AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: !enabled
                      ? null
                      : (_) {
                          state.didChange(option.key);
                          _changeValue(form, input.field, option.key);
                        },
                ),
            ],
          ),
        ),
      );
    }
    if (options == null) {
      return TextFormField(
        initialValue: _draft[input.field],
        enabled: enabled,
        keyboardType: field.isPercentage
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        maxLines: input.field == 'productDetails' ? 5 : 1,
        decoration: decoration,
        validator: validate,
        onSaved: save,
        onChanged: (value) => _changeValue(form, input.field, value),
      );
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _draft[input.field] ?? '',
      decoration: decoration,
      items: [
        const DropdownMenuItem(value: '', child: Text('Select')),
        for (final option in options.entries)
          DropdownMenuItem(value: option.key, child: Text(option.value)),
      ],
      onChanged:
          enabled ? (value) => _changeValue(form, input.field, value) : null,
      validator: validate,
      onSaved: save,
    );
  }
}
