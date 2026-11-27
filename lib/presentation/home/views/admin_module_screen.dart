import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/search_filter_panel.dart';
import 'module_record_screen.dart';

class AdminModuleScreen extends StatefulWidget {
  const AdminModuleScreen({
    super.key,
    required this.item,
    required this.load,
    this.loadFiltered,
    this.loadSearchFields,
    this.loadCreateForm,
    this.createRecord,
    this.loadRowForm,
    this.runRowAction,
    this.loadRecordDetails,
  });

  final MenuItem item;
  final Future<AdminModuleData> Function() load;
  final Future<AdminModuleData> Function(Map<String, String>)? loadFiltered;
  final Future<List<SearchFilterField>?> Function()? loadSearchFields;
  final Future<ModuleRecordForm> Function(AdminModuleConfiguration)?
      loadCreateForm;
  final Future<void> Function(ModuleRecordForm, Map<String, Object?>)?
      createRecord;
  final Future<ModuleRecordForm> Function(
    AdminModuleConfiguration,
    Map<String, dynamic>,
    AdminRowAction,
  )? loadRowForm;
  final Future<void> Function(
    AdminModuleConfiguration,
    Map<String, dynamic>,
    AdminRowAction,
  )? runRowAction;
  final Future<AdminModuleData> Function(
    AdminModuleConfiguration,
    Map<String, dynamic>,
    AdminRowAction,
  )? loadRecordDetails;

  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen> {
  late Future<AdminModuleData> _data;
  late Future<List<SearchFilterField>?> _searchFields;
  Map<String, String> _filters = const {};
  Timer? _searchDebounce;
  bool _runningAction = false;

  bool get _canSearch =>
      widget.loadFiltered != null && widget.loadSearchFields != null;

  String get _moduleCode => widget.item.code.trim().toLowerCase();
  bool get _isCategories => _moduleCode == 'categories';
  bool get _isOffers => _moduleCode == 'offers';
  bool get _usesTableLayout => _isCategories || _isOffers;
  bool get _usesBlueprintControls =>
      _moduleCode == 'brands' || _usesTableLayout;
  bool get _hasInlineSearch => _canSearch && _usesBlueprintControls;

  @override
  void initState() {
    super.initState();
    _data = widget.load();
    if (_hasInlineSearch) _searchFields = widget.loadSearchFields!();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = FutureBuilder<AdminModuleData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is AppException
                        ? error.message
                        : 'Could not load records for this menu.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _reloadRecords,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.requireData;
        if (data.records.isEmpty) {
          return Center(
              child:
                  Text(_isOffers ? 'Nothing here yet.' : 'No records found.'));
        }
        final products = data.products;
        if (products != null) {
          return ProductGrid(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              final config = data.configuration;
              final edit = config?.rowActions
                  .where((action) =>
                      action.isEdit &&
                      action.blueprintApi != null &&
                      _canRunAction(action))
                  .firstOrNull;
              return ProductCard(
                product: item.product,
                imageBytes: item.imageBytes,
                onTap: config != null && edit != null && !_runningAction
                    ? () => _runRowAction(config, item.record, edit)
                    : null,
                actions: config?.rowActions.isNotEmpty == true
                    ? SizedBox(
                        width: double.infinity,
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.centerRight,
                            child: _rowActions(
                              config,
                              item.record,
                              availableWidth: constraints.maxWidth,
                            ),
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        }
        final isWide = MediaQuery.sizeOf(context).width >= 600;
        final columns = data.columns
            .where((column) => isWide || column.showOnMobile)
            .toList(growable: false);
        if (columns.isEmpty) {
          return const Center(child: Text('No display fields configured.'));
        }
        if (_usesTableLayout &&
            isWide &&
            data.configuration?.blueprint['defaultDisplayMode'] == 'table') {
          return _recordTable(data, columns);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final column in columns)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(column.label)),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: column.isImage
                                ? _AdminThumbnail(
                                    source: data.records[index][column.field],
                                  )
                                : Text(
                                    _displayValue(
                                        data.records[index], column.field),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  if (data.configuration != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child:
                          _rowActions(data.configuration, data.records[index]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
        actions: [
          if (widget.loadCreateForm != null && widget.createRecord != null)
            FutureBuilder<AdminModuleData>(
              future: _data,
              builder: (context, snapshot) {
                final configuration = snapshot.data?.configuration;
                final action = configuration?.createAction;
                if (configuration == null ||
                    action == null ||
                    action['display'] == false ||
                    action['blueprintApi'] is! String) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: FilledButton.icon(
                    onPressed: () => _openCreate(configuration),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(action['displayName']?.toString() ?? 'Create'),
                  ),
                );
              },
            ),
          if (_canSearch && (!_hasInlineSearch || _isOffers))
            IconButton(
              tooltip: _isOffers ? 'Advanced search' : 'Search',
              icon: const Icon(Icons.search_rounded),
              onPressed: _openFilters,
            ),
        ],
      ),
      body: _hasInlineSearch
          ? Column(
              children: [
                FutureBuilder<List<SearchFilterField>?>(
                  future: _searchFields,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return TextButton(
                        onPressed: () {
                          final fields = widget.loadSearchFields!();
                          setState(() {
                            _searchFields = fields;
                          });
                        },
                        child:
                            const Text('Could not load search options. Retry'),
                      );
                    }
                    final fields = snapshot.data ?? const <SearchFilterField>[];
                    return _InlineSearchControls(
                      fields: _isOffers
                          ? fields.where((field) => field.quickSearch).toList()
                          : fields,
                      values: _filters,
                      onChanged: (field, value, {required debounce}) =>
                          _updateInlineFilter(field, value, fields,
                              debounce: debounce),
                      searchHint: _isCategories
                          ? 'Search category name…'
                          : 'Search brand name…',
                    );
                  },
                ),
                Expanded(child: records),
              ],
            )
          : records,
    );
  }

  void _updateInlineFilter(
      String field, String value, List<SearchFilterField> fields,
      {required bool debounce}) {
    final next = Map<String, String>.of(_filters);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      next.remove(field);
    } else {
      next[field] = trimmed;
    }
    if (next[field] != _filters[field]) {
      clearDependentFilterValues(next, field, fields);
    }
    _filters = next;
    _searchDebounce?.cancel();
    if (debounce) {
      _searchDebounce =
          Timer(const Duration(milliseconds: 250), _reloadRecords);
    } else {
      _reloadRecords();
    }
  }

  Future<AdminModuleData> _loadRecords() =>
      widget.loadFiltered?.call(_filters) ?? widget.load();

  Future<void> _openCreate(AdminModuleConfiguration configuration) =>
      _openEditor(
        title: configuration.createAction?['action']?.toString() ?? 'Create',
        load: () => widget.loadCreateForm!(configuration),
      );

  Future<void> _openEditor({
    required String title,
    required Future<ModuleRecordForm> Function() load,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ModuleRecordScreen(
          title: title,
          sectionName: widget.item.name,
          load: load,
          submit: widget.createRecord ??
              (_, __) async {
                throw const AppException('This action has no Save endpoint.');
              },
        ),
      ),
    );
    if (!mounted || saved != true) return;
    _searchDebounce?.cancel();
    _reloadRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record saved')),
    );
  }

  Widget _recordTable(AdminModuleData data, List<AdminModuleColumn> columns) {
    final count = data.configuration?.rowActions.length ?? 0;
    final actionWidth = count > 3 ? 48.0 : count * 48.0;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.records.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = index == 0 ? null : data.records[index - 1];
        return Container(
          color: index.isEven ? AppColors.primarySoft : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            for (final column in columns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Text(
                    record == null
                        ? column.label.toUpperCase()
                        : _displayValue(record, column.field),
                    style: TextStyle(
                      fontWeight:
                          record == null ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: actionWidth,
              child: record == null
                  ? null
                  : _rowActions(data.configuration, record),
            ),
          ]),
        );
      },
    );
  }

  Widget _rowActions(
    AdminModuleConfiguration? config,
    Map<String, dynamic> record, {
    double? availableWidth,
  }) {
    if (config == null) return const SizedBox.shrink();
    final actions = config.rowActions.toList(growable: false);
    if (actions.isEmpty) return const SizedBox.shrink();
    if (actions.length > 3 ||
        (availableWidth != null && availableWidth < actions.length * 48)) {
      return PopupMenuButton<AdminRowAction>(
        tooltip: 'Row actions',
        enabled: !_runningAction,
        onSelected: (action) => _runRowAction(config, record, action),
        itemBuilder: (_) => [
          for (final action in actions)
            PopupMenuItem(
              value: action,
              enabled: _canRunAction(action),
              child: Text(action.label),
            ),
        ],
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final action in actions)
        IconButton(
          tooltip: _canRunAction(action)
              ? action.label
              : '${action.label} unavailable',
          icon: Icon(
            action.isDelete
                ? Icons.delete_outline
                : action.isView
                    ? Icons.visibility_outlined
                    : action.isEdit || action.blueprintApi != null
                        ? Icons.edit_outlined
                        : Icons.play_arrow_outlined,
          ),
          onPressed: _runningAction || !_canRunAction(action)
              ? null
              : () => _runRowAction(config, record, action),
        ),
    ]);
  }

  bool _canRunAction(AdminRowAction action) {
    if (!action.isDelete && action.blueprintApi != null) {
      return widget.loadRowForm != null &&
          (action.isView || widget.createRecord != null);
    }
    if (action.isView) {
      return action.endpoint != null && widget.loadRecordDetails != null;
    }
    return action.endpoint != null &&
        const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(action.method) &&
        widget.runRowAction != null;
  }

  Future<void> _runRowAction(
    AdminModuleConfiguration config,
    Map<String, dynamic> record,
    AdminRowAction action,
  ) async {
    if (_runningAction || !_canRunAction(action)) return;
    final needsVariant = config.needsVariant(action) &&
        config.recordValue(record, 'variantId') == null;
    final target = needsVariant ? await _chooseVariant(record) : record;
    if (!mounted || target == null) return;
    if (!action.isDelete && action.blueprintApi != null) {
      await _openEditor(
        title: action.label,
        load: () => widget.loadRowForm!(config, target, action),
      );
      return;
    }
    if (action.isView) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminModuleScreen(
          item: MenuItem(code: widget.item.code, name: action.label),
          load: () => widget.loadRecordDetails!(config, target, action),
        ),
      ));
      return;
    }
    await _confirmAction(config, target, action);
  }

  Future<Map<String, dynamic>?> _chooseVariant(
      Map<String, dynamic> record) async {
    final raw = record['variants'];
    final variants = raw is List
        ? raw.whereType<Map>().where((variant) =>
            variant['variantId']?.toString().trim().isNotEmpty == true)
        : const <Map>[];
    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No variant ID is available for this action.')),
      );
      return null;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a variant'),
        children: [
          for (final variant in variants)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(variant['variantId'].toString()),
              child: Text(
                [variant['unitSize'], variant['unitType'], variant['variantId']]
                    .where(
                        (value) => value?.toString().trim().isNotEmpty == true)
                    .join(' '),
              ),
            ),
        ],
      ),
    );
    return id == null ? null : {...record, 'variantId': id};
  }

  Future<void> _confirmAction(
    AdminModuleConfiguration config,
    Map<String, dynamic> record,
    AdminRowAction action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.isDelete ? 'Delete this record?' : action.label),
        content: action.isDelete
            ? null
            : const Text('Apply this action to the selected record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action.isDelete ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _runningAction) return;
    setState(() => _runningAction = true);
    try {
      await widget.runRowAction!(config, record, action);
      if (mounted) _reloadRecords();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          error is AppException
              ? error.message
              : 'Could not run ${action.label}.',
        )));
      }
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  void _reloadRecords() {
    final records = _loadRecords();
    setState(() {
      _data = records;
    });
  }

  Future<void> _openFilters() async {
    final values = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SearchFilterPanel(
        load: () async => await widget.loadSearchFields!() ?? const [],
        initialValues: _filters,
      ),
    );
    if (!mounted || values == null) return;
    setState(() {
      _filters = values;
      _data = _loadRecords();
    });
  }

  String _displayValue(Map<String, dynamic> record, String field) {
    Object? value = record[field];
    if (!record.containsKey(field)) {
      value = record;
      for (final key in field.split('.')) {
        value = value is Map ? value[key] : null;
      }
    }
    return value?.toString() ?? '—';
  }
}

class _InlineSearchControls extends StatelessWidget {
  const _InlineSearchControls({
    required this.fields,
    required this.values,
    required this.onChanged,
    required this.searchHint,
  });

  final List<SearchFilterField> fields;
  final Map<String, String> values;
  final String searchHint;
  final void Function(String field, String value, {required bool debounce})
      onChanged;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    final ordered = [
      ...fields.where((field) => field.options != null),
      ...fields.where((field) => field.options == null),
    ];
    final columns = ordered.length.clamp(1, 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        final wide = width >= 680;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final field in ordered)
              SizedBox(
                width: wide
                    ? (width - (columns - 1) * spacing) / columns
                    : field.options != null && width >= 300
                        ? (width - spacing) / 2
                        : width,
                child: _control(field),
              ),
          ],
        );
      }),
    );
  }

  Widget _control(SearchFilterField field) {
    final options = field.options;
    if (options == null) {
      return TextFormField(
        key: ValueKey(field.field),
        initialValue: values[field.field],
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: field.placeholder?.trim().isNotEmpty == true
              ? field.placeholder
              : searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => onChanged(field.field, value, debounce: true),
        onFieldSubmitted: (value) =>
            onChanged(field.field, value, debounce: false),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(field.field),
      isExpanded: true,
      initialValue:
          options.containsKey(values[field.field]) ? values[field.field] : '',
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('All')),
        for (final option in options.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) =>
          onChanged(field.field, value ?? '', debounce: false),
    );
  }
}

class _AdminThumbnail extends StatelessWidget {
  const _AdminThumbnail({required this.source});

  final Object? source;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(dimension: 72, child: _buildImage()),
        ),
      );

  Widget _buildImage() {
    const placeholder = Icon(
      Icons.image_not_supported_outlined,
      semanticLabel: 'Product image unavailable',
    );
    final image = source;
    if (image is Uint8List) {
      return Image.memory(
        image,
        fit: BoxFit.contain,
        semanticLabel: 'Product image',
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    // Product Management supplies a complete URL. Other modules may still
    // supply relative image paths through their table blueprints.
    final url = switch (image) {
      String url => url,
      List<String> paths =>
        paths.map(ApiConfig.resolveImageUrl).whereType<String>().where((url) {
          final uri = Uri.tryParse(url);
          return uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty;
        }).firstOrNull,
      _ => null,
    };
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.contain,
      semanticLabel: 'Product image',
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
