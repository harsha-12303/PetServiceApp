import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/add_to_cart_use_case.dart';
import '../../../domain/usecases/get_cart_items_use_case.dart';
import '../viewmodels/cart_view_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.bearerToken,
    required this.catalogRepository,
    this.cartViewModel,
  });
  final String bearerToken;
  final CatalogRepository catalogRepository;
  final CartViewModel? cartViewModel;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final CartViewModel _cart;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  String _addressType = 'Home';

  @override
  void initState() {
    super.initState();
    _cart = widget.cartViewModel ??
        CartViewModel(
          GetCartItemsUseCase(widget.catalogRepository),
          AddToCartUseCase(widget.catalogRepository),
          RemoveFromCartUseCase(widget.catalogRepository),
        );
    _cart.addListener(_refresh);
    if (widget.cartViewModel == null) _cart.load(widget.bearerToken);
  }

  @override
  void dispose() {
    _cart.removeListener(_refresh);
    for (final controller in [
      _name,
      _phone,
      _street,
      _landmark,
      _city,
      _state,
      _pincode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _changeQuantity(CartItem item, int quantity) async {
    final error = await _cart.changeQuantity(
      bearerToken: widget.bearerToken,
      item: item,
      quantity: quantity,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _saveAddress() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address saved for this checkout.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _total(_cart.items);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _cart.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _cart.errorMessage != null
              ? Center(child: Text(_cart.errorMessage!))
              : _cart.items.isEmpty
                  ? const Center(child: Text('Your cart is empty.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                      children: [
                        _AddressPanel(
                          formKey: _formKey,
                          addressType: _addressType,
                          onAddressTypeChanged: (value) =>
                              setState(() => _addressType = value),
                          name: _name,
                          phone: _phone,
                          street: _street,
                          landmark: _landmark,
                          city: _city,
                          state: _state,
                          pincode: _pincode,
                          onSave: _saveAddress,
                        ),
                        const SizedBox(height: 12),
                        _OrderItemsPanel(
                          items: _cart.items,
                          isUpdating: _cart.isUpdating,
                          onIncrease: (item) =>
                              _changeQuantity(item, item.quantity + 1),
                          onDecrease: (item) =>
                              _changeQuantity(item, item.quantity - 1),
                        ),
                        const SizedBox(height: 12),
                        _BillPanel(total: total),
                        const SizedBox(height: 12),
                        const _PaymentPanel(),
                      ],
                    ),
      bottomNavigationBar: _cart.items.isEmpty || _cart.isLoading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _CheckoutFooter(total: total),
            ),
    );
  }
}

class _AddressPanel extends StatelessWidget {
  const _AddressPanel({
    required this.formKey,
    required this.addressType,
    required this.onAddressTypeChanged,
    required this.name,
    required this.phone,
    required this.street,
    required this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    required this.onSave,
  });
  final GlobalKey<FormState> formKey;
  final String addressType;
  final ValueChanged<String> onAddressTypeChanged;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController street;
  final TextEditingController landmark;
  final TextEditingController city;
  final TextEditingController state;
  final TextEditingController pincode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Form(
          key: formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelHeader(
              icon: Icons.location_on_outlined,
              title: 'Delivery address',
              subtitle: 'Add address to deliver to',
            ),
            const SizedBox(height: 12),
            Row(
              children: ['Home', 'Work', 'Other']
                  .map((type) => Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(right: type == 'Other' ? 0 : 3),
                          child: SizedBox(
                            height: 28,
                            child: FilledButton(
                              onPressed: () => onAddressTypeChanged(type),
                              style: FilledButton.styleFrom(
                                backgroundColor: addressType == type
                                    ? AppColors.primary
                                    : AppColors.background,
                                foregroundColor: addressType == type
                                    ? AppColors.onPrimary
                                    : AppColors.text,
                                side: const BorderSide(color: AppColors.border),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(type,
                                  style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _Input(
                      label: 'Full name', required: true, controller: name)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Input(
                      label: 'Phone',
                      required: true,
                      controller: phone,
                      keyboardType: TextInputType.phone)),
            ]),
            const SizedBox(height: 7),
            _Input(
                label: 'House / flat / street',
                required: true,
                controller: street),
            const SizedBox(height: 7),
            _Input(label: 'Area / landmark', controller: landmark),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(
                  child:
                      _Input(label: 'City', required: true, controller: city)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Input(
                      label: 'State', required: true, controller: state)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Input(
                      label: 'Pincode',
                      required: true,
                      controller: pincode,
                      keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 34,
                child: FilledButton(
                    onPressed: onSave, child: const Text('Save address')),
              ),
            ),
          ]),
        ),
      );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label${required ? ' *' : ''}',
              style: TextStyle(
                  fontSize: 10,
                  color: required ? AppColors.primary : AppColors.text)),
          const SizedBox(height: 3),
          SizedBox(
            height: 30,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: required
                  ? (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null
                  : null,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
}

class _OrderItemsPanel extends StatelessWidget {
  const _OrderItemsPanel({
    required this.items,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
  });
  final List<CartItem> items;
  final bool Function(String? variantId) isUpdating;
  final ValueChanged<CartItem> onIncrease;
  final ValueChanged<CartItem> onDecrease;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PanelHeader(
            icon: Icons.shopping_bag_outlined,
            title: 'Order items',
            subtitle:
                '${items.length} product${items.length == 1 ? '' : 's'} · Nutrition',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            _OrderItem(
              item: items[index],
              isUpdating: isUpdating(items[index].product.variantId),
              onIncrease: () => onIncrease(items[index]),
              onDecrease: () => onDecrease(items[index]),
            ),
            if (index < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ]),
      );
}

class _OrderItem extends StatelessWidget {
  const _OrderItem({
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
    return Row(children: [
      _ProductImage(
        url: ApiConfig.resolveImageUrl(product.mainImage),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(product.unitLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(_money(_price(product.price)),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      ),
      _MiniStepper(
        quantity: item.quantity,
        isUpdating: isUpdating,
        onIncrease: onIncrease,
        onDecrease: onDecrease,
      ),
    ]);
  }
}

class _BillPanel extends StatelessWidget {
  const _BillPanel({required this.total});
  final num total;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bill details',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 15),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Items total', style: TextStyle(fontSize: 12))),
            Text(_money(total), style: const TextStyle(fontSize: 12)),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(children: [
            const Expanded(
                child: Text('Grand total',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            Text(_money(total),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ]),
      );
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel();

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _PanelHeader(
            icon: Icons.credit_card_outlined,
            title: 'Payment mode',
            subtitle: 'How the order will pay',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(children: [
              Icon(Icons.radio_button_checked,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 10),
              Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash on delivery',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('Pay in cash when the order arrives',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textMuted)),
                    ]),
              ),
            ]),
          ),
        ]),
      );
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({required this.total});
  final num total;

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(5),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                const Text('TOTAL',
                    style: TextStyle(color: AppColors.onPrimary, fontSize: 10)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.print_outlined, size: 15),
            label: const Text('Print invoice'),
            style: FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.background,
              disabledForegroundColor: AppColors.disabledText,
              minimumSize: const Size(112, 38),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          height: 30,
          width: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(subtitle,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ]);
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper(
      {required this.quantity,
      required this.isUpdating,
      required this.onIncrease,
      required this.onDecrease});
  final int quantity;
  final bool isUpdating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _StepButton(
              icon: Icons.remove, onPressed: isUpdating ? null : onDecrease),
          SizedBox(
            width: 22,
            child: Center(
              child: Text('$quantity',
                  style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          _StepButton(
              icon: Icons.add, onPressed: isUpdating ? null : onIncrease),
        ]),
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        color: AppColors.onPrimary,
        disabledColor: AppColors.onPrimary,
        constraints: const BoxConstraints.tightFor(width: 25, height: 28),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14),
      );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 50,
      width: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(5)),
      child: const Icon(Icons.image_not_supported_outlined, size: 16),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(url!,
          height: 50,
          width: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

num _price(Object? value) {
  if (value is num) return value;
  return num.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
}

num _total(List<CartItem> items) => items.fold<num>(
    0, (sum, item) => sum + (_price(item.product.price) * item.quantity));

String _money(num value) =>
    '\u20B9${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
