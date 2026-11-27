import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import '../../../domain/usecases/get_product_detail_use_case.dart';
import '../viewmodels/cart_view_model.dart';
import '../viewmodels/product_detail_view_model.dart';
import 'cart_screen.dart';

// Shop-style palette additions used on this page.
const _grey = Color(0xFF6B7280);
const _green = Color(0xFF1E8E3E);
const _greenBg = Color(0xFFE6F4EA);

/// Product page in Create Order: swipeable image gallery with dots, brand,
/// title, price with MRP and discount, pack-size selector, collapsible
/// description, specifications and a sticky add-to-cart bar.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.bearerToken,
    required this.catalogRepository,
    this.cartViewModel,
    this.onSearchRequested,
  });

  final Product product;
  final String bearerToken;
  final CatalogRepository catalogRepository;
  final CartViewModel? cartViewModel;
  final VoidCallback? onSearchRequested;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailViewModel _viewModel;
  late final CartViewModel _cartViewModel;
  bool _areSpecificationsExpanded = true;

  /// The pack size the user picked (null: the one they opened).
  String? _selectedVariantId;

  @override
  void initState() {
    super.initState();
    _viewModel = ProductDetailViewModel(
      GetProductDetailUseCase(widget.catalogRepository),
    )..addListener(_refresh);
    _cartViewModel = widget.cartViewModel ??
        CartViewModel(
          GetCartItemsUseCase(widget.catalogRepository),
          AddToCartUseCase(widget.catalogRepository),
          RemoveFromCartUseCase(widget.catalogRepository),
        );
    _cartViewModel.addListener(_refresh);
    if (widget.cartViewModel == null) _cartViewModel.load(widget.bearerToken);
    final variantId = widget.product.variantId;
    if (variantId != null && variantId.isNotEmpty) {
      _viewModel.load(widget.bearerToken, variantId);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _cartViewModel.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Product get _loaded => _viewModel.product ?? widget.product;

  List<ProductVariant> get _variants => _loaded.variants
      .where((v) => v.variantId?.isNotEmpty == true)
      .toList(growable: false);

  /// The selected pack size: the user's pick, else the one that was opened,
  /// else the default, else the first.
  ProductVariant? get _selected {
    final variants = _variants;
    if (variants.isEmpty) return null;
    for (final id in [
      _selectedVariantId,
      widget.product.variantId,
      _loaded.variantId,
    ]) {
      if (id == null) continue;
      for (final v in variants) {
        if (v.variantId == id) return v;
      }
    }
    return variants.where((v) => v.isDefault).firstOrNull ?? variants.first;
  }

  /// The product as shown: the loaded product with the selected pack size's
  /// id, size, price, MRP and images.
  Product get _product {
    final p = _loaded;
    final v = _selected;
    if (v == null) return p;
    final images = v.images.isNotEmpty ? v.images : p.imageUrls;
    return Product(
      name: p.name,
      variantId: v.variantId,
      mainImage: images.firstOrNull ?? p.mainImage,
      imageUrls: images,
      description: p.description,
      category: p.category,
      brand: p.brand,
      flavour: p.flavour,
      breedSize: p.breedSize,
      petType: p.petType,
      lifeStage: p.lifeStage,
      unitSize: v.unitSize ?? p.unitSize,
      unitType: v.unitType ?? p.unitType,
      price: v.price ?? p.price,
      mrp: v.mrp ?? p.mrp,
      variants: p.variants,
    );
  }

  Future<void> _changeQuantity(int quantity) async {
    final product =
        _product.variantId?.isNotEmpty == true ? _product : widget.product;
    final variantId = product.variantId;
    if (variantId == null || variantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is unavailable to update.')),
      );
      return;
    }
    final error = await _cartViewModel.changeQuantity(
      bearerToken: widget.bearerToken,
      item: CartItem(product: product, quantity: _quantity),
      quantity: quantity,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String? get _variantId => _product.variantId?.isNotEmpty == true
      ? _product.variantId
      : widget.product.variantId;

  int get _quantity => _cartViewModel.quantityFor(_variantId);

  int get _cartItemCount => _cartViewModel.itemCount;

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 800;
    final product = _product;
    final cartAction = _StickyCartAction(
      quantity: _quantity,
      isUpdating: _cartViewModel.isUpdating(_variantId),
      isLoading: _cartViewModel.isLoading,
      onAdd: () => _changeQuantity(1),
      onIncrease: () => _changeQuantity(_quantity + 1),
      onDecrease: () => _changeQuantity(_quantity - 1),
    );
    final ready = !_viewModel.isLoading && _viewModel.errorMessage == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            tooltip: 'Search products',
            onPressed: widget.onSearchRequested,
            icon: const Icon(Icons.search_rounded),
          ),
          TextButton.icon(
            onPressed: _openCart,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(
              'Cart${_cartItemCount > 0 ? ' ($_cartItemCount)' : ''}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor ??
                  AppColors.text,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _viewModel.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _viewModel.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _ProductDetails(
                  product: product,
                  variants: _variants,
                  selectedVariantId: _selected?.variantId,
                  onVariantSelected: (id) =>
                      setState(() => _selectedVariantId = id),
                  isWideLayout: isWideLayout,
                  cartAction: cartAction,
                  areSpecificationsExpanded: _areSpecificationsExpanded,
                  onSpecificationsToggled: () => setState(() =>
                      _areSpecificationsExpanded = !_areSpecificationsExpanded),
                ),
      bottomNavigationBar: isWideLayout || !ready
          ? null
          : _BottomBuyBar(product: product, cartAction: cartAction),
    );
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartScreen(
        bearerToken: widget.bearerToken,
        catalogRepository: widget.catalogRepository,
        cartViewModel: _cartViewModel,
      ),
    ));
  }
}

// ------------------------------------------------------------------ prices

num? _asNum(Object? v) => v is num
    ? v
    : num.tryParse('${v ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), ''));

String _money(Object? v) {
  final n = _asNum(v);
  if (n == null) return '$v';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

/// Whole-number percentage off MRP, or null when there's no discount.
int? _discountPercent(Object? price, Object? mrp) {
  final p = _asNum(price);
  final m = _asNum(mrp);
  if (p == null || m == null || m <= 0 || p >= m) return null;
  return ((m - p) * 100 / m).round();
}

/// "₹ 3494  ~~₹3999~~  13% off" on one line.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product, this.compact = false});
  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final price = product.price;
    if (price == null || '$price'.isEmpty) return const SizedBox.shrink();
    final off = _discountPercent(price, product.mrp);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          '₹ ${_money(price)}',
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 20 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (off != null) ...[
          Text(
            '₹${_money(product.mrp)}',
            style: TextStyle(
              color: _grey,
              fontSize: compact ? 13 : 16,
              decoration: TextDecoration.lineThrough,
              decorationColor: _grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$off% off',
              style: TextStyle(
                color: _green,
                fontSize: compact ? 11.5 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ cart

class _BottomBuyBar extends StatelessWidget {
  const _BottomBuyBar({required this.product, required this.cartAction});
  final Product product;
  final Widget cartAction;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PriceLine(product: product, compact: true),
                  if (product.unitLabel.isNotEmpty)
                    Text(
                      product.unitLabel,
                      style: const TextStyle(color: _grey, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 168, child: cartAction),
          ]),
        ),
      );
}

class _StickyCartAction extends StatelessWidget {
  const _StickyCartAction({
    required this.quantity,
    required this.isUpdating,
    required this.isLoading,
    required this.onAdd,
    required this.onIncrease,
    required this.onDecrease,
  });
  final int quantity;
  final bool isUpdating;
  final bool isLoading;
  final VoidCallback onAdd;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    if (quantity < 1) {
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          onPressed: isUpdating || isLoading ? null : onAdd,
          icon: isUpdating || isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.add_shopping_cart_outlined),
          label: const Text('Add +'),
        ),
      );
    }
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _DetailQuantityButton(
          icon: Icons.remove,
          tooltip: 'Decrease quantity',
          onPressed: isUpdating ? null : onDecrease,
        ),
        SizedBox(
          width: 42,
          child: Center(
            child: Text('$quantity',
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
          ),
        ),
        _DetailQuantityButton(
          icon: Icons.add,
          tooltip: 'Increase quantity',
          onPressed: isUpdating ? null : onIncrease,
        ),
      ]),
    );
  }
}

class _DetailQuantityButton extends StatelessWidget {
  const _DetailQuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: AppColors.onPrimary,
        disabledColor: AppColors.onPrimary,
        icon: Icon(icon),
      );
}

// ------------------------------------------------------------------ page

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({
    required this.product,
    required this.variants,
    required this.selectedVariantId,
    required this.onVariantSelected,
    required this.isWideLayout,
    required this.cartAction,
    required this.areSpecificationsExpanded,
    required this.onSpecificationsToggled,
  });
  final Product product;
  final List<ProductVariant> variants;
  final String? selectedVariantId;
  final ValueChanged<String> onVariantSelected;
  final bool isWideLayout;
  final Widget cartAction;
  final bool areSpecificationsExpanded;
  final VoidCallback onSpecificationsToggled;

  List<String> get _images => [product.mainImage, ...product.imageUrls]
      .whereType<String>()
      .where((path) => path.trim().isNotEmpty)
      .map(ApiConfig.resolveImageUrl)
      .whereType<String>()
      .toSet()
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final hasDescription = product.description?.trim().isNotEmpty == true;
    final content = <Widget>[
      _ProductHeading(product: product),
      const SizedBox(height: 16),
      if (isWideLayout)
        Row(children: [
          Expanded(child: _PriceLine(product: product)),
          const SizedBox(width: 16),
          SizedBox(width: 152, child: cartAction),
        ])
      else
        _PriceLine(product: product),
      if (product.price != null) ...[
        const SizedBox(height: 4),
        const Text('Inclusive of all taxes',
            style: TextStyle(color: _grey, fontSize: 12.5)),
      ],
      if (variants.length > 1) ...[
        const SizedBox(height: 22),
        _VariantSelector(
          variants: variants,
          selectedId: selectedVariantId,
          onSelected: onVariantSelected,
        ),
      ] else if (product.unitLabel.isNotEmpty) ...[
        const SizedBox(height: 18),
        _InfoPill(icon: Icons.scale_outlined, text: product.unitLabel),
      ],
      const SizedBox(height: 22),
      const _Highlights(),
      if (hasDescription) ...[
        const _SectionDivider(),
        const _SectionTitle('About this product'),
        const SizedBox(height: 10),
        _ExpandableDescription(text: product.description!.trim()),
      ],
      const _SectionDivider(),
      InkWell(
        onTap: onSpecificationsToggled,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            const Expanded(child: _SectionTitle('Product specifications')),
            AnimatedRotation(
              turns: areSpecificationsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: areSpecificationsExpanded
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _DetailSection(product: product),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: 24),
    ];

    if (isWideLayout) {
      return LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 24),
                child: _ProductGallery(
                  key: ValueKey(images.join('|')),
                  imageUrls: images,
                  showThumbnails: true,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: const PageStorageKey('product-details-information'),
                padding: const EdgeInsets.fromLTRB(20, 18, 24, 24),
                children: content,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ProductGallery(
          key: ValueKey(images.join('|')),
          imageUrls: images,
          showThumbnails: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ],
    );
  }
}

/// Brand, title and a few tags (pet type, life stage, category).
class _ProductHeading extends StatelessWidget {
  const _ProductHeading({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final brand = product.brand?.trim() ?? '';
    final tags = [product.petType, product.lifeStage, product.category]
        .whereType<String>()
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand.isNotEmpty) ...[
          Text(
            brand.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          product.cardTitle.isEmpty ? product.name : product.cardTitle,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 21,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tag in tags) _Tag(tag),
          ]),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
      );
}

/// Pack-size cards; picking one switches price, images and cart variant.
class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.variants,
    required this.selectedId,
    required this.onSelected,
  });
  final List<ProductVariant> variants;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Select size'),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final v in variants)
              _VariantCard(
                variant: v,
                selected: v.variantId == selectedId,
                onTap: () => onSelected(v.variantId!),
              ),
          ]),
        ],
      );
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.selected,
    required this.onTap,
  });
  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final off = _discountPercent(variant.price, variant.mrp);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variant.unitLabel.isEmpty ? 'Pack' : variant.unitLabel,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            if (variant.price != null) ...[
              const SizedBox(height: 2),
              Text('₹${_money(variant.price)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.text)),
            ],
            if (off != null)
              Text('$off% off',
                  style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Small reassurance strip. Only states what's true today: payment is cash
/// on delivery.
class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.payments_outlined, color: AppColors.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cash on delivery available',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child:
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
      );
}

/// Shows 5 lines; "More" / "Less" appears only when the text is longer.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  static const maxLines = 5;
  static const style = TextStyle(color: _grey, fontSize: 15, height: 1.55);

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(
                text: widget.text, style: _ExpandableDescription.style),
            maxLines: _ExpandableDescription.maxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  widget.text,
                  maxLines: _expanded || !overflows
                      ? null
                      : _ExpandableDescription.maxLines,
                  overflow: _expanded || !overflows
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: _ExpandableDescription.style,
                ),
              ),
              if (overflows)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.only(top: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_expanded ? 'Less' : 'More',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          );
        },
      );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final details = <(String, String?)>[
      ('Product name', product.name),
      ('Brand', product.brand),
      ('Flavour', product.flavour),
      ('Life stage', product.lifeStage),
      ('Pet type', product.petType),
      ('Category', product.category),
      ('Breed size', product.breedSize),
      ('Unit size', product.unitLabel),
      ('Price', product.price == null ? null : '₹${_money(product.price)}'),
      ('Variant ID', product.variantId),
    ].where((detail) => detail.$2 != null && detail.$2!.isNotEmpty).toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (final (index, (label, value)) in details.indexed)
            Container(
              color: index.isEven ? AppColors.primarySoft : AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      label,
                      style: const TextStyle(color: _grey, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      value!,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ gallery

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Icon(Icons.pets_outlined, size: 64, color: AppColors.border),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        url!,
        fit: BoxFit.contain,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        // Decode at display size for smooth swiping.
        cacheWidth: constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
            : null,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// Swipe left/right through the images; dots below show which one is on
/// screen, and a counter sits in the corner. Tap to view full screen.
class _ProductGallery extends StatefulWidget {
  const _ProductGallery({
    super.key,
    required this.imageUrls,
    required this.showThumbnails,
  });
  final List<String> imageUrls;
  final bool showThumbnails;

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final _pageController = PageController();
  var _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) => _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );

  Future<void> _openFullScreen(int index) async {
    final page = await Navigator.of(context).push<int>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _FullScreenGallery(imageUrls: widget.imageUrls, initial: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (page != null && mounted && page != _activePage) {
      _pageController.jumpToPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls;
    final many = images.length > 1;
    final pages = Container(
      decoration: BoxDecoration(
        color: AppColors.imageBg,
        borderRadius: widget.showThumbnails
            ? BorderRadius.circular(20)
            : BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: images.isEmpty
              ? const _GalleryImage()
              : PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _activePage = index),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => _openFullScreen(index),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _GalleryImage(url: images[index]),
                    ),
                  ),
                ),
        ),
        if (many) ...[
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_activePage + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _PageDots(
              count: images.length,
              active: _activePage,
              onTap: _goTo,
            ),
          ),
        ],
      ]),
    );

    if (!widget.showThumbnails) {
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: (constraints.maxWidth * 0.95).clamp(240.0, 420.0),
          child: pages,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: pages),
        if (many) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _ImageThumbnail(
                url: images[index],
                isSelected: index == _activePage,
                onTap: () => _goTo(index),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small dots; the current one stretches into a pill.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.active,
    required this.onTap,
    this.light = false,
  });
  final int count;
  final int active;
  final ValueChanged<int> onTap;
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: i == active ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == active
                        ? (light ? Colors.white : AppColors.primary)
                        : (light
                            ? Colors.white.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.url,
    required this.isSelected,
    required this.onTap,
  });
  final String url;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 64,
          width: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.imageBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              cacheWidth: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.placeholder,
              ),
            ),
          ),
        ),
      );
}

/// Full-screen, pinch-to-zoom viewer; returns the page it was closed on.
class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.imageUrls, required this.initial});
  final List<String> imageUrls;
  final int initial;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_page);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.imageUrls.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.imageUrls[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white54,
                          size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close',
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(_page),
                ),
              ),
              if (widget.imageUrls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: _PageDots(
                    count: widget.imageUrls.length,
                    active: _page,
                    light: true,
                    onTap: (i) => _controller.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
