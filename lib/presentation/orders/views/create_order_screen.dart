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
import '../../shared/widgets/search_filter_panel.dart';
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
  final _searchController = TextEditingController();
  late bool _isSearching;
  Map<String, String> _filterValues = {};
  @override
  void initState() {
    super.initState();
    _isSearching = widget.openInSearchMode;
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
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _applyFilters({Duration debounce = Duration.zero}) {
    final query = _searchController.text.trim();
    _viewModel.applyFilters(
      widget.bearerToken,
      ProductFilters(
        query: query,
        additionalParameters: _filterValues,
      ),
      debounce: debounce,
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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _applyFilters(
                      debounce: const Duration(milliseconds: 250)),
                  onSubmitted: (_) {
                    _applyFilters();
                    if (!widget.openInSearchMode) {
                      setState(() => _isSearching = false);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search products',
                    isDense: true,
                    fillColor: AppColors.background,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                )
              : const Text('Create Order'),
          actions: [
            IconButton(
              tooltip: 'Filters',
              onPressed: _openFilters,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: _isSearching ? 'Close search' : 'Search products',
              onPressed: () {
                if (widget.openInSearchMode) {
                  Navigator.of(context).pop();
                  return;
                }
                if (_isSearching) {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                  _applyFilters();
                } else {
                  setState(() => _isSearching = true);
                }
              },
              icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded),
            ),
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
        body: _viewModel.isLoading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            : _viewModel.errorMessage != null || _viewModel.products.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        _viewModel.errorMessage ?? 'No products found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ProductGrid(
                    itemCount: _viewModel.products.length,
                    itemBuilder: (context, index) {
                      final product = _viewModel.products[index];
                      final quantity =
                          _viewModel.quantityFor(product.variantId);
                      return ProductCard(
                        product: product,
                        onTap: product.variantId?.isNotEmpty == true
                            ? () =>
                                Navigator.of(context).push(MaterialPageRoute(
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
                          isUpdating:
                              _viewModel.cart.isUpdating(product.variantId),
                          onIncrease: () =>
                              _changeQuantity(product, quantity + 1),
                          onDecrease: () =>
                              _changeQuantity(product, quantity - 1),
                          onAdd: () => _addToCart(product),
                        ),
                      );
                    },
                  ),
      );

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
      SearchFilterField(
        field: 'brandName',
        label: 'Brand',
        options: {for (final brand in brands) brand: brand},
      ),
      const SearchFilterField(
        field: 'productType',
        label: 'Product Type',
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
        options: {'Cat': 'Cat', 'Dog': 'Dog'},
      ),
    ];
  }

  Future<void> _openFilters() async {
    final values = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => SearchFilterPanel(
        load: _loadFilterFields,
        initialValues: _filterValues,
      ),
    );
    if (!mounted || values == null) return;
    _filterValues = values;
    _applyFilters();
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
