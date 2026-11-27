import 'package:flutter/material.dart';

import 'blueprint/blueprint_models.dart';

/// Maps the backend's Font Awesome names to Material icons.
IconData iconForFa(String? faName,
    {IconData fallback = Icons.circle_outlined}) {
  final name =
      (faName ?? '').toLowerCase().replaceFirst(RegExp(r'^fa[srb]?\s+'), '');
  return _faIcons[name] ?? fallback;
}

IconData iconForAction(BlueprintAction action) => iconForFa(action.faIcon,
    fallback: action.isDelete
        ? Icons.delete_outline
        : action.isEdit
            ? Icons.edit_outlined
            : action.isView
                ? Icons.visibility_outlined
                : action.mentionsCart
                    ? Icons.shopping_cart_outlined
                    : Icons.circle_outlined);

const _faIcons = <String, IconData>{
  'fa-plus': Icons.add,
  'fa-plus-circle': Icons.add_circle_outline,
  'fa-edit': Icons.edit_outlined,
  'fa-pen': Icons.edit_outlined,
  'fa-pencil': Icons.edit_outlined,
  'fa-pencil-alt': Icons.edit_outlined,
  'fa-pen-to-square': Icons.edit_outlined,
  'fa-trash': Icons.delete_outline,
  'fa-trash-alt': Icons.delete_outline,
  'fa-trash-can': Icons.delete_outline,
  'fa-eye': Icons.visibility_outlined,
  'fa-shopping-cart': Icons.shopping_cart_outlined,
  'fa-cart-shopping': Icons.shopping_cart_outlined,
  'fa-cart-plus': Icons.add_shopping_cart,
  'fa-search': Icons.search,
  'fa-magnifying-glass': Icons.search,
  'fa-filter': Icons.filter_list,
  'fa-download': Icons.download_outlined,
  'fa-upload': Icons.upload_outlined,
  'fa-print': Icons.print_outlined,
  'fa-save': Icons.save_outlined,
  'fa-times': Icons.close,
  'fa-xmark': Icons.close,
  'fa-check': Icons.check,
  'fa-refresh': Icons.refresh,
  'fa-rotate': Icons.refresh,
  'fa-user': Icons.person_outline,
  'fa-users': Icons.people_outline,
  'fa-box': Icons.inventory_2_outlined,
  'fa-boxes': Icons.inventory_2_outlined,
  'fa-list': Icons.list,
  'fa-cog': Icons.settings_outlined,
  'fa-gear': Icons.settings_outlined,
};
