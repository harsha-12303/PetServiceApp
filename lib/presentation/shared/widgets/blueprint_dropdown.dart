import 'package:flutter/material.dart';

import '../../../domain/repositories/admin_module_repository.dart';

class BlueprintDropdown extends StatefulWidget {
  const BlueprintDropdown({
    super.key,
    required this.field,
    required this.values,
    required this.decoration,
    required this.onChanged,
    this.validator,
    this.onSaved,
    this.emptyLabel = 'All',
    this.enabled = true,
  });

  final SearchFilterField field;
  final Map<String, String> values;
  final InputDecoration decoration;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final String emptyLabel;
  final bool enabled;

  @override
  State<BlueprintDropdown> createState() => _BlueprintDropdownState();
}

class _BlueprintDropdownState extends State<BlueprintDropdown> {
  late Future<Map<String, String>> _options = _load();

  Future<Map<String, String>> _load() =>
      widget.field.loadOptions!(Map.of(widget.values));

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, String>>(
        future: _options,
        builder: (context, snapshot) {
          final options = snapshot.data ?? const <String, String>{};
          final ready = snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError;
          final current = widget.values[widget.field.field];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(ready),
                isExpanded: true,
                initialValue:
                    ready && options.containsKey(current) ? current : '',
                decoration: widget.decoration,
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(ready ? widget.emptyLabel : 'Loading options…'),
                  ),
                  if (ready)
                    for (final option in options.entries)
                      DropdownMenuItem(
                          value: option.key, child: Text(option.value)),
                ],
                onChanged: ready && widget.enabled ? widget.onChanged : null,
                onSaved: widget.onSaved,
                validator: widget.validator,
              ),
              if (snapshot.hasError)
                TextButton(
                  onPressed: () {
                    final options = _load();
                    setState(() {
                      _options = options;
                    });
                  },
                  child: const Text('Could not load options. Retry'),
                ),
            ],
          );
        },
      );
}
