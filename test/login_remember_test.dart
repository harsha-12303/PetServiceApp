import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_services/data/datasources/saved_credentials_store.dart';
import 'package:petcare_services/domain/entities/models.dart';
import 'package:petcare_services/domain/repositories/auth_repository.dart';
import 'package:petcare_services/domain/repositories/cart_quantity_store.dart';
import 'package:petcare_services/domain/repositories/catalog_repository.dart';
import 'package:petcare_services/presentation/app.dart';

class _Auth implements AuthRepository {
  @override
  Future<AppSession> signIn(
          {required String email, required String password}) async =>
      const AppSession(
        tokens: AuthTokens(bearerToken: 't', refreshToken: '', expiresIn: ''),
        menuItems: [],
      );
}

class _Store implements CredentialsStore {
  _Store([this.saved]);
  SavedCredentials? saved;

  @override
  Future<SavedCredentials?> read() async => saved;
  @override
  Future<void> save(String email, String password) async =>
      saved = SavedCredentials(email: email, password: password);
  @override
  Future<void> clear() async => saved = null;
}

class _Catalog implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CartStore implements CartQuantityStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _Store store) async {
  await tester.pumpWidget(PetCareApp(
    authRepository: _Auth(),
    catalogRepository: _Catalog(),
    cartQuantityStore: _CartStore(),
    credentialsStore: store,
  ));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, int index) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .controller
    .text;

void main() {
  testWidgets('a successful login is remembered', (tester) async {
    final store = _Store();
    await _pump(tester, store);
    await tester.enterText(find.byType(TextFormField).first, 'admin@x.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(store.saved?.email, 'admin@x.com');
    expect(store.saved?.password, 'secret');
  });

  testWidgets('the saved login fills the form next time', (tester) async {
    await _pump(
        tester,
        _Store(const SavedCredentials(
            email: 'admin@x.com', password: 'secret')));
    expect(_field(tester, 0), 'admin@x.com');
    expect(_field(tester, 1), 'secret');
  });

  testWidgets('unticking Remember me forgets the login', (tester) async {
    final store = _Store(
        const SavedCredentials(email: 'old@x.com', password: 'old'));
    await _pump(tester, store);
    await tester.tap(find.text('Remember me'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(store.saved, isNull);
  });

  testWidgets('dashboard is plain: no welcome card', (tester) async {
    await _pump(tester, _Store());
    await tester.enterText(find.byType(TextFormField).first, 'admin@x.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome to PetWork'), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });
}
