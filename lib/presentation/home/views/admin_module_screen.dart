import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/blueprint_search_bar.dart';
import 'module_record_screen.dart';
import 'record_views.dart';

class AdminModuleScreen extends StatefulWidget {
  const AdminModuleScreen({
    super.key,
    required this.item,
    required this.load,
    this.loadFiltered,
    this.loadPage,
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

  /// Like [loadFiltered], but reuses the page's already loaded
  /// configuration (table blueprint) so searches and reloads after a save
  /// cost a single request. Null configuration means load it afresh.
  final Future<AdminModuleData> Function(
    Map<String, String> filters,
    AdminModuleConfiguration? configuration,
  )? loadPage;
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
  Map<String, String> _filters = const {};
  bool _runningAction = false;

  /// Search-by-name in the header (🔍).
  final _headerSearch = HeaderSearchController();

  /// The page's blueprint, reused until the user refreshes.
  AdminModuleConfiguration? _configuration;

  /// The last unfiltered result, used to narrow the list instantly while
  /// the user types (the server search then replaces it).
  AdminModuleData? _unfiltered;

  /// Bumped on refresh so the search bar reloads its blueprint too.
  int _refreshCount = 0;

  bool get _canSearch =>
      (widget.loadFiltered != null || widget.loadPage != null) &&
      widget.loadSearchFields != null;

  String get _moduleCode => widget.item.code.trim().toLowerCase();
  bool get _isCategories => _moduleCode == 'categories';
  bool get _isOffers => _moduleCode == 'offers';
  bool get _usesTableLayout => _isCategories || _isOffers;
  String get _searchHint => _isCategories
      ? 'Search category name…'
      : _moduleCode == 'brands'
          ? 'Search brand name…'
          : widget.item.isProductManagement
              ? 'Search products…'
              : 'Search…';

  @override
  void initState() {
    super.initState();
    _data = _remember(widget.load());
  }

  @override
  void dispose() {
    _headerSearch.dispose();
    super.dispose();
  }

  Future<AdminModuleData> _remember(Future<AdminModuleData> data) {
    final unfiltered = _filters.isEmpty;
    return data.then((value) {
      _configuration = value.configuration ?? _configuration;
      if (unfiltered) _unfiltered = value;
      return value;
    });
  }

  /// Instant feedback while typing: narrow the already loaded list by the
  /// text, before the server search (debounced) comes back.
  void _narrowInstantly(String text) {
    final base = _unfiltered;
    if (base == null) return;
    setState(() {
      _data = Future.value(narrowAdminData(base, text));
    });
  }

  /// Reloads everything from the server, blueprints included.
  Future<void> _refresh() {
    _configuration = null;
    _refreshCount++;
    _reloadRecords();
    return _data.then((_) {}, onError: (_) {});
  }

  /// Makes [child] pullable even when it doesn't fill the screen.
  Widget _pullable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight, child: child),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final records = FutureBuilder<AdminModuleData>(
      future: _data,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        // First load: spinner. Later reloads keep the current list on screen
        // with a thin progress bar instead of blanking it.
        if (loading && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!loading && snapshot.hasError) {
          final error = snapshot.error;
          return _pullable(Center(
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
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ));
        }
        final data = snapshot.requireData;
        return Stack(children: [
          Positioned.fill(child: _recordsView(data)),
          if (loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ]);
      },
    );
    final body = RefreshIndicator(onRefresh: _refresh, child: records);
    return Scaffold(
      appBar: AppBar(
        title: _canSearch
            ? HeaderSearchTitle(
                title: Text(widget.item.name),
                controller: _headerSearch,
                hint: _searchHint,
              )
            : Text(widget.item.name),
        actions: _appBarActions(),
      ),
      floatingActionButton: _createButton(),
      body: _canSearch
          ? Column(
              children: [
                BlueprintSearchBar(
                  key: ValueKey('search-$_refreshCount'),
                  load: () async =>
                      await widget.loadSearchFields!() ?? const [],
                  values: _filters,
                  searchHint: _searchHint,
                  onTyping: _narrowInstantly,
                  headerSearch: _headerSearch,
                  onChanged: (values) {
                    _filters = values;
                    _reloadRecords();
                  },
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }

  Widget _recordsView(AdminModuleData data) {
    if (data.records.isEmpty) {
      return _pullable(Center(
          child: Text(_isOffers ? 'Nothing here yet.' : 'No records found.')));
    }
    final products = data.products;
    if (products != null) {
      return ProductGrid(
        bottomPadding: _canCreate ? 96 : null,
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
    return RecordCardList(
      columns: columns,
      records: data.records,
      cell: _cell,
      textOf: (record, column) => _displayValue(record, column.field),
      actions: (record) => _rowActions(data.configuration, record),
    );
  }

  List<Widget> _appBarActions() => [
        if (_canSearch) HeaderSearchButton(controller: _headerSearch),
      ];

  bool get _canCreate =>
      widget.loadCreateForm != null && widget.createRecord != null;

  /// Compact floating "+ Create …" button (bottom right) for the page's
  /// create action, once its blueprint says there is one.
  Widget? _createButton() => !_canCreate
      ? null
      : FutureBuilder<AdminModuleData>(
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
            // The icon already shows "+", so drop one from the label.
            final label = (action['displayName']?.toString() ?? 'Create')
                .replaceFirst(RegExp(r'^\s*\+\s*'), '');
            return FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openCreate(configuration),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 3,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
              extendedIconLabelSpacing: 6,
              extendedTextStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(label),
            );
          },
        );

  Future<AdminModuleData> _loadRecords() => _remember(
        widget.loadPage?.call(_filters, _configuration) ??
            widget.loadFiltered?.call(_filters) ??
            widget.load(),
      );

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
    _reloadRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record saved')),
    );
  }

  Widget _recordTable(AdminModuleData data, List<AdminModuleColumn> columns) {
    final count = data.configuration?.rowActions.length ?? 0;
    return RecordTableView(
      columns: columns,
      records: data.records,
      cell: _cell,
      textOf: (record, column) => _displayValue(record, column.field),
      actions: (record) => _rowActions(data.configuration, record),
      actionsWidth: count > 3 ? 48.0 : count * 44.0,
    );
  }

  /// One field of a record: a thumbnail for image columns, else its text.
  Widget _cell(Map<String, dynamic> record, AdminModuleColumn column) =>
      column.isImage
          ? _AdminThumbnail(source: record[column.field])
          : Text(
              _displayValue(record, column.field),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );

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
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: action.isDelete
                ? const Color(0xFFFDECEA)
                : AppColors.primaryTint,
            foregroundColor:
                action.isDelete ? const Color(0xFFC0392B) : AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(
            action.isDelete
                ? Icons.delete_outline_rounded
                : action.isView
                    ? Icons.visibility_outlined
                    : action.isEdit || action.blueprintApi != null
                        ? Icons.edit_rounded
                        : Icons.play_arrow_rounded,
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
        cacheWidth: 216,
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
      cacheWidth: 216,
      fit: BoxFit.contain,
      semanticLabel: 'Product image',
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

/// Records (and product cards) whose text contains [text], case-insensitive.
AdminModuleData narrowAdminData(AdminModuleData data, String text) {
  final q = text.trim().toLowerCase();
  if (q.isEmpty) return data;
  bool matches(Map record) => record.values
      .any((value) => value is String && value.toLowerCase().contains(q));
  final products = data.products;
  if (products != null) {
    final kept = products
        .where((p) =>
            p.product.name.toLowerCase().contains(q) || matches(p.record))
        .toList(growable: false);
    return AdminModuleData(
      columns: data.columns,
      records: [for (final p in kept) p.record],
      configuration: data.configuration,
      products: kept,
    );
  }
  return AdminModuleData(
    columns: data.columns,
    records: data.records.where(matches).toList(growable: false),
    configuration: data.configuration,
  );
}
