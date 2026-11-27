import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/models.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../orders/views/create_order_screen.dart';
import 'admin_module_screen.dart';

class PetWorkHomeScreen extends StatelessWidget {
  const PetWorkHomeScreen(
      {super.key,
      required this.session,
      required this.catalogRepository,
      required this.cartQuantityStore,
      this.adminModuleRepository,
      this.onLogout,
      this.loginScreenBuilder});
  final AppSession session;
  final CatalogRepository catalogRepository;
  final CartQuantityStore cartQuantityStore;
  final AdminModuleRepository? adminModuleRepository;
  final Future<void> Function()? onLogout;
  final Widget Function()? loginScreenBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PetWork',
              style: TextStyle(fontWeight: FontWeight.w800)),
          elevation: 0,
          leading: Builder(
              builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer())),
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(children: [
                  Container(
                      padding: const EdgeInsets.all(24),
                      color: AppColors.primaryTint,
                      child: const Row(children: [
                        Icon(Icons.pets_outlined, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text('PetWork',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                      ])),
                  const Padding(
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Text('NAVIGATION',
                          style: TextStyle(
                              color: AppColors.placeholder,
                              fontWeight: FontWeight.w800,
                              fontSize: 12))),
                  for (final item in session.menuItems)
                    _MenuTile(
                        item: item,
                        onSelected: (selected) => _openMenu(
                              context,
                              selected,
                              parentCode:
                                  identical(item, selected) ? null : item.code,
                            )),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _logout(context),
              ),
            ]),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.pets_outlined,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text('Welcome to PetWork',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _openMenu(BuildContext context, MenuItem item, {String? parentCode}) {
    final navigator = Navigator.of(context);
    final isCreateOrder = [item.code, item.name].any((value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '')
        .contains('createorder'));
    final repository = adminModuleRepository;
    if (isCreateOrder) {
      final catalog = catalogRepository;
      final configuration =
          repository != null && catalog is ConfigurableOrderCatalog
              ? repository.loadConfiguration(
                  session.tokens.bearerToken,
                  item,
                  parentCode: parentCode,
                  includeSearchEndpoint: true,
                )
              : null;
      Widget orderScreen(CatalogRepository orderCatalog) => CreateOrderScreen(
            bearerToken: session.tokens.bearerToken,
            catalogRepository: orderCatalog,
            cartQuantityStore: cartQuantityStore,
            loadSearchFilters: repository == null
                ? null
                : () => repository.loadSearchFilters(
                      session.tokens.bearerToken,
                      item,
                      parentCode: parentCode,
                    ),
          );
      navigator.push(MaterialPageRoute(
        builder: (_) => configuration == null
            ? orderScreen(catalog)
            : FutureBuilder<AdminModuleConfiguration>(
                future: configuration,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return orderScreen(
                      (catalog as ConfigurableOrderCatalog)
                          .forModule(snapshot.requireData),
                    );
                  }
                  return Scaffold(
                    appBar: AppBar(title: Text(item.name)),
                    body: Center(
                      child: snapshot.hasError
                          ? const Text(
                              'Could not load the order module configuration.')
                          : const CircularProgressIndicator(),
                    ),
                  );
                },
              ),
      ));
    } else if (repository != null &&
        (parentCode != null ||
            item.dataApi != null ||
            item.dataTableBlueprintUrl != null)) {
      navigator.push(MaterialPageRoute(
        builder: (_) => AdminModuleScreen(
          item: item,
          load: () => repository.load(
            session.tokens.bearerToken,
            item,
            parentCode: parentCode,
          ),
          loadFiltered: (filters) => repository.load(
            session.tokens.bearerToken,
            item,
            parentCode: parentCode,
            filters: filters,
          ),
          loadSearchFields: () => repository.loadSearchFilters(
            session.tokens.bearerToken,
            item,
            parentCode: parentCode,
            includeQuickSearch: true,
          ),
          loadCreateForm: (configuration) => repository.loadCreateForm(
              session.tokens.bearerToken, configuration),
          createRecord: (form, values) =>
              repository.createRecord(session.tokens.bearerToken, form, values),
          loadRowForm: (configuration, record, action) =>
              repository.loadCreateForm(
            session.tokens.bearerToken,
            configuration,
            record: record,
            rowAction: action,
          ),
          runRowAction: (configuration, record, action) =>
              repository.runRowAction(
            session.tokens.bearerToken,
            configuration,
            record,
            action,
          ),
          loadRecordDetails: (configuration, record, action) =>
              repository.loadRecordDetails(
            session.tokens.bearerToken,
            configuration,
            record,
            rowAction: action,
          ),
        ),
      ));
    }
  }

  Future<void> _logout(BuildContext context) async {
    await onLogout?.call();
    if (!context.mounted) return;
    if (loginScreenBuilder != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => loginScreenBuilder!()),
        (route) => false,
      );
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.onSelected});
  final MenuItem item;
  final ValueChanged<MenuItem> onSelected;

  void _select(BuildContext context, MenuItem selected) {
    Scaffold.of(context).closeDrawer();
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (item.children.isEmpty) {
      return ListTile(
          title: Text(item.name),
          leading: const Icon(Icons.grid_view_rounded),
          onTap: () => _select(context, item));
    }
    return ExpansionTile(
      title: Text(item.name),
      leading: const Icon(Icons.folder_outlined),
      children: [
        for (final child in item.children)
          ListTile(
            title: Text(child.name),
            contentPadding: const EdgeInsets.only(left: 72, right: 24),
            onTap: () => _select(context, child),
          )
      ],
    );
  }
}
