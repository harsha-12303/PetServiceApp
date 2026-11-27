import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/models.dart';
import '../../shared/widgets/menu_icons.dart';
import '../../shared/widgets/app_logo.dart';

/// The navigation drawer: gradient header, icon on every link, accordion
/// sections (several can be open at once) with smooth expand/collapse, and a short
/// staggered slide-in when the drawer opens.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.menuItems,
    required this.onSelected,
    required this.onLogout,
  });

  final List<MenuItem> menuItems;

  /// [parent] is the section the link belongs to (null for top-level links).
  final void Function(MenuItem selected, MenuItem? parent) onSelected;
  final VoidCallback onLogout;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  /// Open sections; any number can be open at once.
  final _open = <int>{};

  void _select(MenuItem selected, MenuItem? parent) {
    Scaffold.of(context).closeDrawer();
    widget.onSelected(selected, parent);
  }

  @override
  Widget build(BuildContext context) => Drawer(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          const _DrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      color: AppColors.placeholder,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                for (final (index, item) in widget.menuItems.indexed)
                  _StaggeredEntry(
                    index: index,
                    child: item.children.isEmpty
                        ? _NavLink(
                            item: item,
                            onTap: () => _select(item, null),
                          )
                        : _NavSection(
                            item: item,
                            expanded: _open.contains(index),
                            onToggle: () => setState(() {
                              if (!_open.remove(index)) _open.add(index);
                            }),
                            onSelected: (child) => _select(child, item),
                          ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _NavLink(
                label: 'Logout',
                icon: Icons.logout_rounded,
                color: const Color(0xFFC0392B),
                onTap: widget.onLogout,
              ),
            ),
          ),
        ]),
      );
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            24, MediaQuery.paddingOf(context).top + 28, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: const AppLogo(size: 52),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PetWork',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Admin console',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ]),
      );
}

/// Rounded square holding a menu icon; filled when [active].
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.active = false,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final bool active;
  final Color color;

  static const size = 38.0;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child:
            Icon(icon, size: size * 0.52, color: active ? Colors.white : color),
      );
}

/// A single tappable link (top-level menu without children, or Logout).
class _NavLink extends StatelessWidget {
  const _NavLink({
    this.item,
    this.label,
    this.icon,
    this.color = AppColors.primary,
    required this.onTap,
  });

  final MenuItem? item;
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                _IconBadge(icon: icon ?? menuIconFor(item!), color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label ?? item!.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color:
                          color == AppColors.primary ? AppColors.text : color,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// A main menu with sub-menu links that slide open below it.
class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.item,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
  });

  final MenuItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<MenuItem> onSelected;

  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        // No box around an open section: links simply slide out below.
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  _IconBadge(icon: menuIconFor(item), active: expanded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  _CountChip(count: item.children.length),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary),
                  ),
                ]),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: _duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: expanded ? 1 : 0,
              child: AnimatedOpacity(
                duration: _duration,
                opacity: expanded ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
                  child: Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    child: Column(children: [
                      for (final child in item.children)
                        _SubLink(
                          item: child,
                          enabled: expanded,
                          onTap: () => onSelected(child),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _SubLink extends StatelessWidget {
  const _SubLink({
    required this.item,
    required this.onTap,
    required this.enabled,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(children: [
              Icon(menuIconFor(item, isSubmenu: true),
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
            ]),
          ),
        ),
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
}

/// Fades and slides each menu entry in, one after another.
class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + 50 * index.clamp(0, 8)),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-16 * (1 - t), 0),
            child: child,
          ),
        ),
        child: child,
      );
}
