import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/repositories/admin_module_repository.dart';

/// Builds one cell's content for a record.
typedef RecordCellBuilder = Widget Function(
    Map<String, dynamic> record, AdminModuleColumn column);

/// Text of a record field, for titles and avatars.
typedef RecordTextOf = String Function(
    Map<String, dynamic> record, AdminModuleColumn column);

/// Phone layout: one rounded card per record with an avatar (image or
/// initials), a bold title, the other fields as label/value pairs, and the
/// row actions on the right. Cards fade in one after another.
class RecordCardList extends StatelessWidget {
  const RecordCardList({
    super.key,
    required this.columns,
    required this.records,
    required this.cell,
    required this.textOf,
    required this.actions,
  });

  final List<AdminModuleColumn> columns;
  final List<Map<String, dynamic>> records;
  final RecordCellBuilder cell;
  final RecordTextOf textOf;
  final Widget Function(Map<String, dynamic> record) actions;

  @override
  Widget build(BuildContext context) {
    final image = columns.where((c) => c.isImage).firstOrNull;
    final textColumns = columns.where((c) => !c.isImage).toList();
    final title = textColumns.firstOrNull;
    final details = textColumns.skip(1).toList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final titleText = title == null ? '' : textOf(record, title);
        return _FadeIn(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox.square(
                          dimension: 56,
                          child: cell(record, image),
                        ),
                      )
                    : InitialsAvatar(text: titleText),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (title != null)
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                          child: cell(record, title),
                        ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            for (final column in details)
                              _Field(
                                label: column.label,
                                child: cell(record, column),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions(record),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wide layout: a rounded table with a tinted header row, hover highlight
/// and an avatar beside the first column.
class RecordTableView extends StatelessWidget {
  const RecordTableView({
    super.key,
    required this.columns,
    required this.records,
    required this.cell,
    required this.textOf,
    required this.actions,
    required this.actionsWidth,
  });

  final List<AdminModuleColumn> columns;
  final List<Map<String, dynamic>> records;
  final RecordCellBuilder cell;
  final RecordTextOf textOf;
  final Widget Function(Map<String, dynamic> record) actions;
  final double actionsWidth;

  @override
  Widget build(BuildContext context) {
    final first = columns.where((c) => !c.isImage).firstOrNull;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryTint, AppColors.primarySoft],
                ),
              ),
              child: Row(children: [
                for (final column in columns)
                  Expanded(
                    flex: column == first ? 2 : 1,
                    child: Text(
                      column.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                SizedBox(width: actionsWidth),
              ]),
            ),
            for (final (index, record) in records.indexed)
              _FadeIn(
                index: index,
                child: _HoverRow(
                  showDivider: index > 0,
                  child: Row(children: [
                    for (final column in columns)
                      Expanded(
                        flex: column == first ? 2 : 1,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: column == first
                              ? Row(children: [
                                  InitialsAvatar(
                                    text: textOf(record, column),
                                    size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: DefaultTextStyle.merge(
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                      child: cell(record, column),
                                    ),
                                  ),
                                ])
                              : column.isImage
                                  ? Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox.square(
                                          dimension: 44,
                                          child: cell(record, column),
                                        ),
                                      ),
                                    )
                                  : cell(record, column),
                        ),
                      ),
                    SizedBox(
                      width: actionsWidth,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actions(record),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            child: child,
          ),
        ],
      );
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.showDivider});
  final Widget child;
  final bool showDivider;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? AppColors.primarySoft : Colors.transparent,
            border: widget.showDivider
                ? Border(
                    top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.6)))
                : null,
          ),
          child: widget.child,
        ),
      );
}

/// A soft gradient circle with the first letters of [text].
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.text, this.size = 48});
  final String text;
  final double size;

  static const _palettes = [
    [Color(0xFF2D518F), Color(0xFF4F7BC8)],
    [Color(0xFF00897B), Color(0xFF26A69A)],
    [Color(0xFF8E24AA), Color(0xFFBA68C8)],
    [Color(0xFFEF6C00), Color(0xFFFFA726)],
    [Color(0xFFC2185B), Color(0xFFF06292)],
    [Color(0xFF3949AB), Color(0xFF7986CB)],
  ];

  String get _initials {
    final words = text
        .trim()
        .split(RegExp(r'[\s_-]+'))
        .where((w) => w.isNotEmpty && w != '—')
        .toList();
    if (words.isEmpty) return '•';
    final letters = words.take(2).map((w) => w.characters.first).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[text.hashCode.abs() % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: ExcludeSemantics(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts an item in, slightly after the one before it.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 240 + 40 * index.clamp(0, 10)),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        ),
        child: child,
      );
}
