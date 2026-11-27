import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_brand_names_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import '../../../domain/usecases/get_products_use_case.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import '../viewmodels/cart_view_model.dart';
import '../viewmodels/create_order_view_model.dart';
import '../../shared/widgets/blueprint_search_bar.dart';
import '../../shared/widgets/product_card.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen(
      {super.key,
      required this.bearerToken,
      required this.catalogRepository,
      required this.cartQuantityStore,
      this.cartViewModel,
      this.loadSearchFilters,
      this.openInSearchMode = false});
  final String bearerToken;
  final CatalogRepository catalogRepository;
  final CartQuantityStore cartQuantityStore;
  final CartViewModel? cartViewModel;
  final Future<List<SearchFilterField>?> Function()? loadSearchFilters;
  final bool openInSearchMode;
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  late final CreateOrderViewModel _viewModel;
  Map<String, String> _filterValues = {};

  /// Search-by-name in the header (🔍); opened straight away when this
  /// screen was opened for searching.
  late final _headerSearch =
      HeaderSearchController(open: widget.openInSearchMode);
  @override
  void initState() {
    super.initState();
    _viewModel = CreateOrderViewModel(
      GetProductsUseCase(widget.catalogRepository),
      GetBrandNamesUseCase(widget.catalogRepository),
      GetCartItemsUseCase(widget.catalogRepository),
      AddToCartUseCase(widget.catalogRepository),
      RemoveFromCartUseCase(widget.catalogRepository),
      widget.cartQuantityStore,
      cartViewModel: widget.cartViewModel,
    )..addListener(_refresh);
    _viewModel.cart.addListener(_refresh);
    _viewModel.load(widget.bearerToken);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.cart.removeListener(_refresh);
    _viewModel.dispose();
    _headerSearch.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Every active filter (inline and Filters box) goes as a query param.
  /// The search bar already debounces typing.
  void _applyFilters() {
    _viewModel.applyFilters(
      widget.bearerToken,
      ProductFilters(additionalParameters: _filterValues),
    );
  }

  Future<void> _addToCart(Product product) async {
    final variantId = product.variantId;
    if (variantId == null || variantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is unavailable to add.')),
      );
      return;
    }
    final error = await _viewModel.addProductToCart(
      bearerToken: widget.bearerToken,
      variantId: variantId,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _changeQuantity(Product product, int quantity) async {
    final variantId = product.variantId;
    if (variantId == null || variantId.isEmpty) return;
    final error = await _viewModel.changeQuantity(
      bearerToken: widget.bearerToken,
      variantId: variantId,
      quantity: quantity,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: HeaderSearchTitle(
            title: Text(
                widget.openInSearchMode ? 'Search products' : 'Create Order'),
            controller: _headerSearch,
            hint: 'Search products…',
          ),
          actions: [
            HeaderSearchButton(controller: _headerSearch),
            TextButton.icon(
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                  'Cart${_viewModel.cartItemCount > 0 ? ' (${_viewModel.cartItemCount})' : ''}'),
              style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).appBarTheme.foregroundColor ??
                          AppColors.text),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          // Quick filters inline; the rest in the Filters box.
          BlueprintSearchBar(
            load: _loadFilterFields,
            values: _filterValues,
            searchHint: 'Search products',
            onTyping: _viewModel.narrowInstantly,
            headerSearch: _headerSearch,
            onChanged: (values) {
              _filterValues = values;
              _applyFilters();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _productArea(),
            ),
          ),
        ]),
      );

  /// Reloads products (with the current filters) and the cart.
  Future<void> _reload() => _viewModel.load(widget.bearerToken);

  /// Makes [child] pullable even when it doesn't fill the screen.
  Widget _pullable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight, child: child),
          ],
        ),
      );

  Widget _productArea() {
    final products = _viewModel.products;
    // First load: spinner. Searches and refreshes keep the current products
    // on screen with a thin progress bar instead of blanking the grid.
    if (_viewModel.isLoading && products.isEmpty) {
      return _pullable(const Padding(
        padding: EdgeInsets.all(32),
        child: Align(
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ));
    }
    if (!_viewModel.isLoading &&
        (_viewModel.errorMessage != null || products.isEmpty)) {
      return _pullable(Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            _viewModel.errorMessage ?? 'No products found.',
            textAlign: TextAlign.center,
          ),
        ),
      ));
    }
    return Stack(children: [
      Positioned.fill(
        child: ProductGrid(
          itemCount: _viewModel.products.length,
          itemBuilder: (context, index) {
            final product = _viewModel.products[index];
            final quantity = _viewModel.quantityFor(product.variantId);
            return ProductCard(
              product: product,
              onTap: product.variantId?.isNotEmpty == true
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: product,
                          bearerToken: widget.bearerToken,
                          catalogRepository: widget.catalogRepository,
                          cartViewModel: _viewModel.cart,
                          onSearchRequested: _openProductSearch,
                        ),
                      ))
                  : null,
              actions: _ProductCartAction(
                quantity: quantity,
                isUpdating: _viewModel.cart.isUpdating(product.variantId),
                onIncrease: () => _changeQuantity(product, quantity + 1),
                onDecrease: () => _changeQuantity(product, quantity - 1),
                onAdd: () => _addToCart(product),
              ),
            );
          },
        ),
      ),
      if (_viewModel.isLoading)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(minHeight: 2),
        ),
    ]);
  }

  void _openProductSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateOrderScreen(
        bearerToken: widget.bearerToken,
        catalogRepository: widget.catalogRepository,
        cartQuantityStore: widget.cartQuantityStore,
        cartViewModel: _viewModel.cart,
        loadSearchFilters: widget.loadSearchFilters,
        openInSearchMode: true,
      ),
    ));
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartScreen(
        bearerToken: widget.bearerToken,
        catalogRepository: widget.catalogRepository,
        cartViewModel: _viewModel.cart,
      ),
    ));
  }

  Future<List<SearchFilterField>> _loadFilterFields() async {
    final fields = await widget.loadSearchFilters?.call();
    if (fields != null) return fields;
    final brands = await _viewModel.loadBrandNames(widget.bearerToken);
    return [
      const SearchFilterField(
        field: 'q',
        label: 'Search products',
        placeholder: 'Search products',
        quickSearch: true,
      ),
      SearchFilterField(
        field: 'brandName',
        label: 'Brand',
        options: {for (final brand in brands) brand: brand},
        quickSearch: false,
      ),
      const SearchFilterField(
        field: 'productType',
        label: 'Product Type',
        quickSearch: false,
        options: {
          'Food': 'Food',
          'Medicine': 'Medicine',
          'Accessories': 'Accessories',
          'Treats': 'Treats',
        },
      ),
      const SearchFilterField(
        field: 'petType',
        label: 'Pet Type',
        quickSearch: false,
        options: {'Cat': 'Cat', 'Dog': 'Dog'},
      ),
    ];
  }
}

class _ProductCartAction extends StatelessWidget {
  const _ProductCartAction({
    required this.quantity,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
    required this.onAdd,
  });

  final int quantity;
  final bool isUpdating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (quantity > 0) {
      return _ProductQuantityStepper(
        quantity: quantity,
        isUpdating: isUpdating,
        onIncrease: onIncrease,
        onDecrease: onDecrease,
      );
    }
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: isUpdating ? null : onAdd,
        icon: isUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_shopping_cart_outlined, size: 16),
        label: const Text('Add +'),
      ),
    );
  }
}

class _ProductQuantityStepper extends StatelessWidget {
  const _ProductQuantityStepper({
    required this.quantity,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
  });
  final int quantity;
  final bool isUpdating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ProductQuantityButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            onPressed: isUpdating ? null : onDecrease,
          ),
          SizedBox(
            width: 26,
            child: Center(
              child: Text('$quantity',
                  style: const TextStyle(
                      color: AppColors.onPrimary, fontWeight: FontWeight.w800)),
            ),
          ),
          _ProductQuantityButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            onPressed: isUpdating ? null : onIncrease,
          ),
        ]),
      );
}

class _ProductQuantityButton extends StatelessWidget {
  const _ProductQuantityButton({
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
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 26, height: 30),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16),
      );
}
