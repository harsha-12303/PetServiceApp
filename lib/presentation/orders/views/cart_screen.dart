import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import '../viewmodels/cart_view_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.bearerToken,
    required this.catalogRepository,
    this.cartViewModel,
  });

  final String bearerToken;
  final CatalogRepository catalogRepository;
  final CartViewModel? cartViewModel;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.cartViewModel ??
        CartViewModel(
          GetCartItemsUseCase(widget.catalogRepository),
          AddToCartUseCase(widget.catalogRepository),
          RemoveFromCartUseCase(widget.catalogRepository),
        );
    _viewModel.addListener(_refresh);
    if (widget.cartViewModel == null || _viewModel.errorMessage != null) {
      _viewModel.load(widget.bearerToken);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _changeQuantity(CartItem item, int quantity) async {
    final error = await _viewModel.changeQuantity(
      bearerToken: widget.bearerToken,
      item: item,
      quantity: quantity,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = _CartSummary.fromItems(_viewModel.items);
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Cart', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _viewModel.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_viewModel.errorMessage!,
                        textAlign: TextAlign.center),
                  ),
                )
              : _viewModel.items.isEmpty
                  ? const Center(child: Text('Your cart is empty.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                      children: [
                        _ItemsCard(
                          items: _viewModel.items,
                          summary: summary,
                          isUpdating: _viewModel.isUpdating,
                          onIncrease: (item) =>
                              _changeQuantity(item, item.quantity + 1),
                          onDecrease: (item) =>
                              _changeQuantity(item, item.quantity - 1),
                        ),
                        const SizedBox(height: 18),
                        _BillDetails(total: summary.total),
                      ],
                    ),
      bottomNavigationBar: _viewModel.items.isEmpty || _viewModel.isLoading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _CheckoutBar(
                total: summary.total,
                onCheckout: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CheckoutScreen(
                    bearerToken: widget.bearerToken,
                    catalogRepository: widget.catalogRepository,
                    cartViewModel: _viewModel,
                  ),
                )),
              ),
            ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
    required this.summary,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
  });
  final List<CartItem> items;
  final _CartSummary summary;
  final bool Function(String? variantId) isUpdating;
  final ValueChanged<CartItem> onIncrease;
  final ValueChanged<CartItem> onDecrease;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              height: 50,
              width: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items in cart',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${summary.productCount} products · ${summary.unitCount} units',
                        style: const TextStyle(color: AppColors.textMuted)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++) ...[
            _CartItemRow(
              item: items[index],
              isUpdating: isUpdating(items[index].product.variantId),
              onIncrease: () => onIncrease(items[index]),
              onDecrease: () => onDecrease(items[index]),
            ),
            if (index < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ]),
      );
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
  });
  final CartItem item;
  final bool isUpdating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _CartImage(
        url: ApiConfig.resolveImageUrl(product.mainImage),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.cardTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
          if (product.unitLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(product.unitLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                )),
          ],
          if (product.price != null) ...[
            const SizedBox(height: 4),
            Text(_money(_price(product.price)),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ]),
      ),
      const SizedBox(width: 10),
      _CartQuantityStepper(
        quantity: item.quantity,
        isUpdating: isUpdating,
        onIncrease: onIncrease,
        onDecrease: onDecrease,
      ),
    ]);
  }
}

class _BillDetails extends StatelessWidget {
  const _BillDetails({required this.total});
  final num total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bill details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Items total')),
            Text(_money(total)),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(children: [
            const Expanded(
              child: Text('Grand total',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            Text(_money(total),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ]),
      );
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.onCheckout});
  final num total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_money(total),
                    style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                const Text('TOTAL',
                    style: TextStyle(color: AppColors.onPrimary, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onCheckout,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(142, 48),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Checkout'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded),
            ]),
          ),
        ]),
      );
}

class _CartQuantityStepper extends StatelessWidget {
  const _CartQuantityStepper({
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
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            onPressed: isUpdating ? null : onDecrease,
          ),
          SizedBox(
            width: 38,
            child: Center(
              child: Text('$quantity',
                  semanticsLabel: 'Quantity $quantity',
                  style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            onPressed: isUpdating ? null : onIncrease,
          ),
        ]),
      );
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
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
        constraints: const BoxConstraints.tightFor(width: 36, height: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
      );
}

class _CartImage extends StatelessWidget {
  const _CartImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.imageBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_outlined,
          color: AppColors.textMuted),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        height: 72,
        width: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _CartSummary {
  const _CartSummary({
    required this.productCount,
    required this.unitCount,
    required this.total,
  });
  final int productCount;
  final int unitCount;
  final num total;

  factory _CartSummary.fromItems(List<CartItem> items) => _CartSummary(
        productCount: items.length,
        unitCount: items.fold(0, (sum, item) => sum + item.quantity),
        total: items.fold<num>(
          0,
          (sum, item) => sum + (_price(item.product.price) * item.quantity),
        ),
      );
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(18),
    );

num _price(Object? value) {
  if (value is num) return value;
  return num.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
}

String _money(num value) {
  final source = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  final parts = source.split('.');
  var whole = parts.first;
  if (whole.length > 3) {
    final tail = whole.substring(whole.length - 3);
    final head = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    for (var index = head.length; index > 0; index -= 2) {
      groups.insert(0, head.substring(index >= 2 ? index - 2 : 0, index));
    }
    whole = '${groups.join(',')},$tail';
  }
  return '\u20B9$whole${parts.length == 2 ? '.${parts.last}' : ''}';
}
