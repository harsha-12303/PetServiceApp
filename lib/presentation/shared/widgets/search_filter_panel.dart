import 'package:flutter/material.dart';

import '../../../domain/repositories/admin_module_repository.dart';
import 'blueprint_dropdown.dart';

class SearchFilterPanel extends StatefulWidget {
  const SearchFilterPanel(
      {super.key, required this.load, required this.initialValues});

  final Future<List<SearchFilterField>> Function() load;
  final Map<String, String> initialValues;

  @override
  State<SearchFilterPanel> createState() => _SearchFilterPanelState();
}

class _SearchFilterPanelState extends State<SearchFilterPanel> {
  late Future<List<SearchFilterField>> _fields;
  late final Map<String, String> _values;

  @override
  void initState() {
    super.initState();
    _values = Map.of(widget.initialValues);
    _fields = widget.load();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Filters',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              FutureBuilder<List<SearchFilterField>>(
                future: _fields,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Column(children: [
                      const Text('Could not load search filters.'),
                      TextButton(
                        onPressed: () {
                          final fields = widget.load();
                          setState(() {
                            _fields = fields;
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ]);
                  }
                  final fields = snapshot.requireData;
                  final visible =
                      fields.where((field) => field.isVisible(_values));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (fields.isEmpty) const Text('No filters configured.'),
                      for (final field in visible) ...[
                        _buildField(field, fields),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop({
                          for (final field in visible)
                            if (_selectedValue(field) case final value?)
                              field.field: value,
                        }),
                        child: const Text('Apply filters'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  String? _selectedValue(SearchFilterField field) {
    final value = _values[field.field]?.trim();
    if (value == null || value.isEmpty) return null;
    if (field.options != null && !field.options!.containsKey(value)) {
      return null;
    }
    return value;
  }

  Widget _buildField(SearchFilterField field, List<SearchFilterField> fields) {
    void change(String? value) {
      if (_values[field.field] == value) return;
      setState(() {
        _values[field.field] = value ?? '';
        clearDependentFilterValues(_values, field.field, fields);
      });
    }

    final decoration = InputDecoration(
      labelText: field.label,
      hintText: field.placeholder,
    );
    if (field.loadOptions != null) {
      return BlueprintDropdown(
        key: ValueKey(field.optionsKey(_values)),
        field: field,
        values: _values,
        decoration: decoration,
        onChanged: change,
      );
    }
    final options = field.options;
    if (options == null) {
      return TextFormField(
        key: ObjectKey(field),
        initialValue: _selectedValue(field),
        decoration: decoration,
        onChanged: change,
      );
    }
    return DropdownButtonFormField<String>(
      key: ObjectKey(field),
      initialValue: _selectedValue(field) ?? '',
      isExpanded: true,
      decoration: decoration,
      items: [
        const DropdownMenuItem(value: '', child: Text('All')),
        for (final option in options.entries)
          DropdownMenuItem(value: option.key, child: Text(option.value)),
      ],
      onChanged: change,
    );
  }
}
