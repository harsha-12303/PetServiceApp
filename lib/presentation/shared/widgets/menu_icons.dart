import 'package:flutter/material.dart';

import '../../../domain/entities/models.dart';

/// The icon for a menu link: the backend's icon when we recognise it, else
/// one picked from the menu's code / name, else a generic one.
IconData menuIconFor(MenuItem item, {bool isSubmenu = false}) {
  final backend = _fromBackendName(item.icon);
  if (backend != null) return backend;
  final text = [item.code, item.name, item.icon ?? '']
      .join(' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '');
  for (final (keywords, icon) in _keywordIcons) {
    if (keywords.any(text.contains)) return icon;
  }
  return isSubmenu ? Icons.label_outline_rounded : Icons.folder_rounded;
}

IconData? _fromBackendName(String? raw) {
  if (raw == null) return null;
  // "fa fa-box", "fas fa-box", "fa-box" → "fa-box"
  final match = RegExp(r'fa-[\w-]+').firstMatch(raw.toLowerCase());
  return match == null ? null : _faIcons[match.group(0)];
}

/// Checked in order: more specific phrases first.
const _keywordIcons = <(List<String>, IconData)>[
  (['createorder', 'neworder', 'placeorder'], Icons.add_shopping_cart_rounded),
  (['cart'], Icons.shopping_cart_rounded),
  (['order'], Icons.receipt_long_rounded),
  (['inventory', 'stock', 'warehouse'], Icons.inventory_2_rounded),
  (['productmanag', 'product'], Icons.shopping_bag_rounded),
  (['categor'], Icons.category_rounded),
  (['brand'], Icons.verified_rounded),
  (['voucher', 'coupon'], Icons.confirmation_number_rounded),
  (['offer', 'discount', 'promo'], Icons.local_offer_rounded),
  (['vet', 'doctor', 'medical', 'clinic'], Icons.medical_services_rounded),
  (['appointment', 'booking', 'schedule', 'calendar'], Icons.event_rounded),
  (['customer', 'client'], Icons.person_rounded),
  (['role', 'permission', 'access'], Icons.admin_panel_settings_rounded),
  (['user', 'staff', 'employee', 'team', 'member'], Icons.people_alt_rounded),
  (['invoice', 'bill'], Icons.request_quote_rounded),
  (['payment', 'finance', 'transaction'], Icons.payments_rounded),
  (['report', 'analytic', 'insight'], Icons.bar_chart_rounded),
  (['dashboard', 'home', 'overview'], Icons.dashboard_rounded),
  (['delivery', 'shipping', 'shipment'], Icons.local_shipping_rounded),
  (['store', 'shop', 'branch', 'outlet'], Icons.storefront_rounded),
  (['service', 'groom', 'spa'], Icons.spa_rounded),
  (['pet', 'animal'], Icons.pets_rounded),
  (['notification', 'alert'], Icons.notifications_rounded),
  (['banner', 'media', 'gallery', 'image'], Icons.photo_library_rounded),
  (['review', 'feedback', 'rating'], Icons.reviews_rounded),
  (['setting', 'config', 'master', 'setup'], Icons.settings_rounded),
];

const _faIcons = <String, IconData>{
  'fa-box': Icons.inventory_2_rounded,
  'fa-boxes': Icons.inventory_2_rounded,
  'fa-boxes-stacked': Icons.inventory_2_rounded,
  'fa-warehouse': Icons.warehouse_rounded,
  'fa-shopping-bag': Icons.shopping_bag_rounded,
  'fa-bag-shopping': Icons.shopping_bag_rounded,
  'fa-shopping-cart': Icons.shopping_cart_rounded,
  'fa-cart-shopping': Icons.shopping_cart_rounded,
  'fa-cart-plus': Icons.add_shopping_cart_rounded,
  'fa-receipt': Icons.receipt_long_rounded,
  'fa-clipboard-list': Icons.assignment_rounded,
  'fa-list': Icons.list_alt_rounded,
  'fa-th-large': Icons.grid_view_rounded,
  'fa-table-cells-large': Icons.grid_view_rounded,
  'fa-tag': Icons.sell_rounded,
  'fa-tags': Icons.local_offer_rounded,
  'fa-percent': Icons.percent_rounded,
  'fa-percentage': Icons.percent_rounded,
  'fa-ticket': Icons.confirmation_number_rounded,
  'fa-ticket-alt': Icons.confirmation_number_rounded,
  'fa-gift': Icons.card_giftcard_rounded,
  'fa-paw': Icons.pets_rounded,
  'fa-dog': Icons.pets_rounded,
  'fa-cat': Icons.pets_rounded,
  'fa-user': Icons.person_rounded,
  'fa-users': Icons.people_alt_rounded,
  'fa-user-md': Icons.medical_services_rounded,
  'fa-user-doctor': Icons.medical_services_rounded,
  'fa-stethoscope': Icons.medical_services_rounded,
  'fa-user-shield': Icons.admin_panel_settings_rounded,
  'fa-calendar': Icons.event_rounded,
  'fa-calendar-alt': Icons.event_rounded,
  'fa-calendar-days': Icons.event_rounded,
  'fa-file-invoice': Icons.request_quote_rounded,
  'fa-file-invoice-dollar': Icons.request_quote_rounded,
  'fa-money-bill': Icons.payments_rounded,
  'fa-credit-card': Icons.credit_card_rounded,
  'fa-chart-bar': Icons.bar_chart_rounded,
  'fa-chart-line': Icons.show_chart_rounded,
  'fa-chart-pie': Icons.pie_chart_rounded,
  'fa-tachometer-alt': Icons.dashboard_rounded,
  'fa-gauge': Icons.dashboard_rounded,
  'fa-home': Icons.home_rounded,
  'fa-house': Icons.home_rounded,
  'fa-truck': Icons.local_shipping_rounded,
  'fa-store': Icons.storefront_rounded,
  'fa-shop': Icons.storefront_rounded,
  'fa-bell': Icons.notifications_rounded,
  'fa-image': Icons.photo_library_rounded,
  'fa-images': Icons.photo_library_rounded,
  'fa-star': Icons.star_rounded,
  'fa-cog': Icons.settings_rounded,
  'fa-cogs': Icons.settings_rounded,
  'fa-gear': Icons.settings_rounded,
  'fa-gears': Icons.settings_rounded,
  'fa-sitemap': Icons.account_tree_rounded,
  'fa-folder': Icons.folder_rounded,
  'fa-layer-group': Icons.layers_rounded,
};
