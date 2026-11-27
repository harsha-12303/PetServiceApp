import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import '../../../domain/usecases/get_product_detail_use_case.dart';
import '../viewmodels/cart_view_model.dart';
import 'cart_screen.dart';
import '../viewmodels/product_detail_view_model.dart';

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
  bool _isDescriptionExpanded = false;
  bool _areSpecificationsExpanded = true;

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

  Product get _product => _viewModel.product ?? widget.product;

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
    final cartAction = _StickyCartAction(
      quantity: _quantity,
      isUpdating: _cartViewModel.isUpdating(_variantId),
      isLoading: _cartViewModel.isLoading,
      onAdd: () => _changeQuantity(1),
      onIncrease: () => _changeQuantity(_quantity + 1),
      onDecrease: () => _changeQuantity(_quantity - 1),
    );
    return Scaffold(
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
                foregroundColor:
                    Theme.of(context).appBarTheme.foregroundColor ??
                        AppColors.text),
          ),
          const SizedBox(width: 8),
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
                  product: _product,
                  isWideLayout: isWideLayout,
                  cartAction: cartAction,
                  areSpecificationsExpanded: _areSpecificationsExpanded,
                  isDescriptionExpanded: _isDescriptionExpanded,
                  onDescriptionExpanded: () =>
                      setState(() => _isDescriptionExpanded = true),
                  onSpecificationsToggled: () => setState(() =>
                      _areSpecificationsExpanded = !_areSpecificationsExpanded),
                ),
      bottomNavigationBar: isWideLayout
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: cartAction,
            ),
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
        borderRadius: BorderRadius.circular(8),
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

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({
    required this.product,
    required this.isWideLayout,
    required this.cartAction,
    required this.areSpecificationsExpanded,
    required this.isDescriptionExpanded,
    required this.onDescriptionExpanded,
    required this.onSpecificationsToggled,
  });
  final Product product;
  final bool isWideLayout;
  final Widget cartAction;
  final bool areSpecificationsExpanded;
  final bool isDescriptionExpanded;
  final VoidCallback onDescriptionExpanded;
  final VoidCallback onSpecificationsToggled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final gallery = _ProductImageCarousel(
            height: isWideLayout ? constraints.maxHeight : 288,
            fillPanel: isWideLayout,
            imageUrls: [product.mainImage, ...product.imageUrls]
                .whereType<String>()
                .where((path) => path.trim().isNotEmpty)
                .map(ApiConfig.resolveImageUrl)
                .whereType<String>()
                .toSet()
                .toList(growable: false),
          );
          final summary = _ProductSummary(
            product: product,
            cartAction: isWideLayout ? cartAction : null,
          );
          final content = <Widget>[
            summary,
            if (isWideLayout) const Divider(height: 24),
            if (product.description != null &&
                product.description!.trim().isNotEmpty) ...[
              SizedBox(height: isWideLayout ? 12 : 24),
              const Text('Description',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(product.description!,
                  maxLines: isDescriptionExpanded ? null : 5,
                  overflow: isDescriptionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, height: 1.5)),
              if (!isDescriptionExpanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onDescriptionExpanded,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.only(top: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('More',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
            const SizedBox(height: 22),
            InkWell(
              onTap: onSpecificationsToggled,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Expanded(
                    child: Text('Product specifications',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Icon(
                    areSpecificationsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ]),
              ),
            ),
            if (areSpecificationsExpanded) ...[
              const SizedBox(height: 8),
              _DetailSection(product: product),
            ],
          ];
          if (isWideLayout) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 12, 24),
                    child: gallery,
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
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [gallery, const SizedBox(height: 20), ...content],
          );
        },
      );
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.product,
    this.cartAction,
  });
  final Product product;
  final Widget? cartAction;

  @override
  Widget build(BuildContext context) {
    final hasPrice =
        product.price != null && product.price.toString().isNotEmpty;
    final priceText = hasPrice
        ? Text(
            '\u20B9\u00A0${product.price}',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          )
        : null;
    if (cartAction == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.cardTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 27,
                  height: 1.25,
                )),
        const SizedBox(height: 12),
        if (product.unitLabel.isNotEmpty)
          Text(product.unitLabel,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 17,
                  fontWeight: FontWeight.w500)),
        if (priceText != null) priceText,
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(product.cardTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 30,
                height: 1.15,
              )),
      if (product.brand != null && product.brand!.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('by ${product.brand}',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
      if (product.unitLabel.isNotEmpty || hasPrice) ...[
        const SizedBox(height: 26),
        const Text('Select unit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.unitLabel.isNotEmpty)
                Text(product.unitLabel,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              if (hasPrice)
                Text('\u20B9${product.price}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const Divider(height: 24),
        if (product.unitLabel.isNotEmpty)
          Text(product.unitLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
      ],
      Row(
        children: [
          Expanded(child: priceText ?? const SizedBox.shrink()),
          const SizedBox(width: 16),
          SizedBox(width: 152, child: cartAction),
        ],
      ),
    ]);
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final details = <(String, String?)>[
      ('Product name', product.name),
      ('Variant ID', product.variantId),
      ('Brand', product.brand),
      ('Flavour', product.flavour),
      ('Life stage', product.lifeStage),
      ('Pet type', product.petType),
      ('Category', product.category),
      ('Breed size', product.breedSize),
      ('Unit size', product.unitLabel),
      ('Price', product.price == null ? null : '₹${product.price}'),
    ].where((detail) => detail.$2 != null && detail.$2!.isNotEmpty).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (index, (label, value)) in details.indexed) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({this.url, this.size = 260});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.imageBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.pets_outlined, size: 56),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(url!,
          height: size,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => placeholder),
    );
  }
}

class _ProductImageCarousel extends StatefulWidget {
  const _ProductImageCarousel({
    required this.imageUrls,
    required this.height,
    required this.fillPanel,
  });
  final List<String> imageUrls;
  final double height;
  final bool fillPanel;

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  late final PageController _pageController;
  var _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const Center(child: _DetailImage());

    final hasThumbnails = widget.imageUrls.length > 1;
    if (widget.fillPanel) {
      return LayoutBuilder(builder: (context, constraints) {
        final stripHeight = hasThumbnails
            ? (constraints.maxHeight / 4).clamp(0.0, 54.0).toDouble()
            : 0.0;
        final gap = hasThumbnails ? stripHeight / 4 : 0.0;
        final imageSize = constraints.maxWidth
            .clamp(0.0, constraints.maxHeight - stripHeight - gap)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: _buildPages(),
            ),
            if (hasThumbnails) ...[
              SizedBox(height: gap),
              SizedBox(
                height: stripHeight,
                child: _buildThumbnails(Axis.horizontal),
              ),
            ],
          ],
        );
      });
    }

    return SizedBox(
      height: widget.height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasThumbnails) ...[
          SizedBox(
            width: 58,
            height: widget.height,
            child: _buildThumbnails(Axis.vertical),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: _buildPages()),
      ]),
    );
  }

  Widget _buildPages() => PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _activePage = index),
        itemBuilder: (_, index) => LayoutBuilder(
          builder: (context, constraints) => Center(
            child: _DetailImage(
              url: widget.imageUrls[index],
              size: widget.fillPanel
                  ? constraints.maxWidth
                  : constraints.maxWidth.clamp(0.0, 260.0).toDouble(),
            ),
          ),
        ),
      );

  Widget _buildThumbnails(Axis direction) => ListView.separated(
        primary: false,
        scrollDirection: direction,
        itemCount: widget.imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8, height: 8),
        itemBuilder: (context, index) => _ImageThumbnail(
          url: widget.imageUrls[index],
          isSelected: index == _activePage,
          onTap: () => _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        ),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 54,
          width: 54,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.imageBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              url,
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
