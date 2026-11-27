import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/repositories/admin_module_repository.dart';
import 'blueprint_dropdown.dart';
import 'search_filter_panel.dart';

/// The search area of a list page, driven by the search blueprint:
///
/// - `quickSearchFilter: true` fields are shown inline on the page.
/// - Every other field (including ones the backend adds later) lives in a
///   small Filters box behind the filter button, whose badge counts the
///   active ones.
///
/// Text applies once it reaches the field's minimum length, 200 ms after
/// typing stops; dropdown picks apply immediately. [onChanged] receives the
/// complete set of active filters (quick and box together).
/// If the search blueprint can't be loaded, nothing is shown.
class BlueprintSearchBar extends StatefulWidget {
  const BlueprintSearchBar({
    super.key,
    required this.load,
    required this.values,
    required this.onChanged,
    this.searchHint = 'Search…',
    this.autofocus = false,
    this.onTyping,
    this.headerSearch,
  });

  /// When given, search-by-name lives in the page header (see
  /// [HeaderSearchTitle] / [HeaderSearchButton]) instead of on the page:
  /// inline text boxes are hidden and the header's text drives the name
  /// filter (same debounce, minimum length and instant narrowing).
  final HeaderSearchController? headerSearch;

  final Future<List<SearchFilterField>> Function() load;
  final Map<String, String> values;
  final ValueChanged<Map<String, String>> onChanged;
  final String searchHint;
  final bool autofocus;

  /// Called on every keystroke in an inline search box (no delay) while no
  /// other filter is active, so the page can narrow what it already shows
  /// right away; [onChanged] then follows with the server search.
  final ValueChanged<String>? onTyping;

  @override
  State<BlueprintSearchBar> createState() => _BlueprintSearchBarState();
}

class _BlueprintSearchBarState extends State<BlueprintSearchBar> {
  /// Short pause after typing before searching the server.
  static const _debounce = Duration(milliseconds: 200);

  /// Inline on the page: `quickSearchFilter: true`, plus the name search box
  /// (`q`) when the blueprint has no other inline text search, so every
  /// list page gets search-by-name.
  static bool _isInline(SearchFilterField f, List<SearchFilterField> fields) =>
      f.quickSearch ||
      (f.isText &&
          f.field == 'q' &&
          !fields.any((o) => o.quickSearch && o.isText));

  late final Future<List<SearchFilterField>> _fields = widget.load()
    ..then((fields) => _loaded = fields, onError: (_) => _loaded = const []);

  /// The loaded fields (empty when the search blueprint failed).
  List<SearchFilterField>? _loaded;
  String _headerText = '';

  @override
  void initState() {
    super.initState();
    widget.headerSearch?.text.addListener(_onHeaderText);
  }

  /// The field the header search writes to: the page's inline text search,
  /// else any `q` text field, else a plain `q`.
  static SearchFilterField _nameField(List<SearchFilterField> fields) =>
      fields
          .where((f) => f.isText && _isInline(f, fields))
          .followedBy(fields.where((f) => f.isText && f.field == 'q'))
          .firstOrNull ??
      const SearchFilterField(field: 'q', label: 'Search');

  void _onHeaderText() {
    final text = widget.headerSearch!.text.text;
    if (text == _headerText) return; // cursor moves also notify
    _headerText = text;
    final fields = _loaded ?? const <SearchFilterField>[];
    _onTextChanged(fields, _nameField(fields), text);
  }

  late Map<String, String> _values = Map.of(widget.values);
  final _controllers = <String, TextEditingController>{};
  Timer? _timer;

  @override
  void didUpdateWidget(BlueprintSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only take values from the page when the page itself changed them; a
    // plain rebuild mid-typing must not undo what the user just typed.
    if (!_sameValues(widget.values, oldWidget.values) &&
        !_sameValues(widget.values, _values)) {
      _values = Map.of(widget.values);
      for (final entry in _controllers.entries) {
        final text = _values[entry.key] ?? '';
        if (entry.value.text.trim() != text) entry.value.text = text;
      }
    }
  }

  @override
  void dispose() {
    widget.headerSearch?.text.removeListener(_onHeaderText);
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _sameValues(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  void _set(List<SearchFilterField> fields, String field, String? value,
      {bool debounce = false}) {
    final next = Map.of(_values);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      next.remove(field);
    } else {
      next[field] = trimmed;
    }
    if (next[field] != _values[field]) {
      clearDependentFilterValues(next, field, fields);
    }
    _emit(next, debounce: debounce);
  }

  void _emit(Map<String, String> next, {bool debounce = false}) {
    _timer?.cancel();
    final changed = !_sameValues(next, _values);
    setState(() => _values = next);
    if (!changed) return;
    if (debounce) {
      _timer = Timer(_debounce, () => widget.onChanged(Map.of(_values)));
    } else {
      widget.onChanged(Map.of(_values));
    }
  }

  void _onTextChanged(
      List<SearchFilterField> fields, SearchFilterField field, String text,
      {bool submitted = false}) {
    final trimmed = text.trim();
    final othersActive = fields.any((f) =>
        !f.isText &&
        f.field != field.field &&
        _values[f.field]?.isNotEmpty == true);
    if (!othersActive) widget.onTyping?.call(trimmed);
    // Too short to search yet: treat as no filter.
    final applied = trimmed.length >= field.minLength ? trimmed : '';
    _set(fields, field.field, applied, debounce: !submitted);
  }

  Future<void> _openFilterBox(List<SearchFilterField> fields) async {
    final boxFields = fields.where((f) => !_isInline(f, fields)).toList();
    // Reload the blueprint each time the box opens so options are fresh.
    Future<List<SearchFilterField>> loadBoxFields() async {
      final all = await widget.load();
      return all.where((f) => !_isInline(f, all)).toList();
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SearchFilterPanel(
            load: loadBoxFields,
            initialValues: _values,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    final boxKeys = boxFields.map((f) => f.field).toSet();
    final next = {
      for (final e in _values.entries)
        if (!boxKeys.contains(e.key)) e.key: e.value,
      ...result,
    };
    for (final key in boxKeys) {
      if (next[key] != _values[key]) {
        clearDependentFilterValues(next, key, fields);
      }
    }
    _emit(next);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SearchFilterField>>(
        future: _fields,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          // No search blueprint: show the list without search.
          if (snapshot.hasError) return const SizedBox.shrink();
          final fields = snapshot.requireData;
          final quick = fields
              .where((f) =>
                  _isInline(f, fields) &&
                  f.isVisible(_values) &&
                  // Name search is in the header when there's one.
                  !(widget.headerSearch != null && f.isText))
              .toList();
          final hasBox = fields.any((f) => !_isInline(f, fields));
          if (quick.isEmpty && !hasBox) return const SizedBox.shrink();
          final activeInBox = fields
              .where((f) =>
                  !_isInline(f, fields) && _values[f.field]?.isNotEmpty == true)
              .length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: quick.isEmpty
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            activeInBox == 0
                                ? 'No filters applied'
                                : '$activeInBox filter${activeInBox == 1 ? '' : 's'} applied',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : _quickControls(fields, quick),
                ),
                if (hasBox) ...[
                  const SizedBox(width: 8),
                  Badge.count(
                    count: activeInBox,
                    isLabelVisible: activeInBox > 0,
                    child: IconButton.filledTonal(
                      key: const ValueKey('search-more-filters'),
                      tooltip: 'Filters',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => _openFilterBox(fields),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );

  Widget _quickControls(
      List<SearchFilterField> fields, List<SearchFilterField> quick) {
    final ordered = [
      // Dropdowns first (side by side on phones), then the search box.
      ...quick.where((f) => !f.isText),
      ...quick.where((f) => f.isText),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final width = constraints.maxWidth;
      final wide = width >= 680;
      final columns = ordered.length.clamp(1, 3);
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final field in ordered)
            SizedBox(
              key: ValueKey(field.field),
              width: wide
                  ? (width - (columns - 1) * spacing) / columns
                  : !field.isText && width >= 300
                      ? (width - spacing) / 2
                      : width,
              child: _control(fields, field,
                  autofocus: widget.autofocus &&
                      field ==
                          ordered.firstWhere((f) => f.isText,
                              orElse: () => field)),
            ),
        ],
      );
    });
  }

  Widget _control(List<SearchFilterField> fields, SearchFilterField field,
      {bool autofocus = false}) {
    if (field.isText) {
      final controller = _controllers.putIfAbsent(
        field.field,
        () => TextEditingController(text: _values[field.field] ?? ''),
      );
      return TextField(
        key: ValueKey('search-${field.field}'),
        controller: controller,
        autofocus: autofocus && field.isText,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: field.placeholder?.trim().isNotEmpty == true
              ? field.placeholder
              : widget.searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    _set(fields, field.field, null);
                  },
                ),
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) => _onTextChanged(fields, field, text),
        onSubmitted: (text) =>
            _onTextChanged(fields, field, text, submitted: true),
      );
    }
    final decoration = InputDecoration(
      isDense: true,
      labelText: field.label,
      border: const OutlineInputBorder(),
    );
    if (field.loadOptions != null) {
      return BlueprintDropdown(
        key: ValueKey(field.optionsKey(_values)),
        field: field,
        values: _values,
        decoration: decoration,
        onChanged: (value) => _set(fields, field.field, value),
      );
    }
    final options = field.options!;
    final current = _values[field.field];
    return DropdownButtonFormField<String>(
      key: ValueKey('search-${field.field}-$current'),
      isExpanded: true,
      initialValue: options.containsKey(current) ? current : '',
      decoration: decoration,
      items: [
        const DropdownMenuItem(value: '', child: Text('All')),
        for (final option in options.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => _set(fields, field.field, value),
    );
  }
}

/// Shared state between the header's search field and the page's
/// [BlueprintSearchBar].
class HeaderSearchController extends ChangeNotifier {
  HeaderSearchController({bool open = false}) : _open = open;

  final text = TextEditingController();
  bool _open;
  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  /// Closes the field and clears the search.
  void close() {
    text.clear();
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// The header title, swapped (animated) for a search field while searching.
class HeaderSearchTitle extends StatelessWidget {
  const HeaderSearchTitle({
    super.key,
    required this.title,
    required this.controller,
    this.hint = 'Search by name…',
  });

  final Widget title;
  final HeaderSearchController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              child: child,
            ),
          ),
          child: controller.isOpen
              ? SizedBox(
                  key: const ValueKey('search-open'),
                  height: 42,
                  child: TextField(
                    key: const ValueKey('header-search'),
                    controller: controller.text,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('search-closed'), child: title),
        ),
      );
}

/// 🔍 in the header; turns into ✕ (close and clear) while searching.
class HeaderSearchButton extends StatelessWidget {
  const HeaderSearchButton({super.key, required this.controller});
  final HeaderSearchController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => IconButton(
          tooltip: controller.isOpen ? 'Close search' : 'Search',
          onPressed: controller.toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              controller.isOpen ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(controller.isOpen),
            ),
          ),
        ),
      );
}
