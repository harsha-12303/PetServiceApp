import 'package:flutter/material.dart';

import '../../../domain/entities/models.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../orders/views/create_order_screen.dart';
import 'admin_module_screen.dart';
import 'app_drawer.dart';

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
        drawer: AppDrawer(
          menuItems: session.menuItems,
          onSelected: (selected, parent) =>
              _openMenu(context, selected, parentCode: parent?.code),
          onLogout: () => _logout(context),
        ),
        // Plain, empty dashboard: navigation lives in the drawer.
        body: const SizedBox.expand(),
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
                      // Keep the name search (`q`) so it shows on the page.
                      includeQuickSearch: true,
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
          loadPage: (filters, configuration) => repository.load(
            session.tokens.bearerToken,
            item,
            parentCode: parentCode,
            filters: filters,
            configuration: configuration,
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
