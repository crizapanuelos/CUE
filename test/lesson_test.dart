import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billiardhub/main.dart';
import 'package:billiardhub/models/product.dart';
import 'package:billiardhub/services/local_store.dart';
import 'package:billiardhub/services/shop.dart';
import 'package:billiardhub/repositories/catalog_repository.dart';
import 'package:billiardhub/core/commerce.dart';
import 'package:billiardhub/lesson_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late List<Product> products;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarded': 'true'});
    store = LocalStore(await SharedPreferences.getInstance());
    products =
        (jsonDecode(File('lib/data/products.json').readAsStringSync()) as List)
            .map((j) => Product.fromJson(j))
            .toList();
    for (final pair in [
      ['Manrope', 'assets/fonts/Manrope.ttf'],
      ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
    ]) {
      await (FontLoader(pair[0])..addFont(rootBundle.load(pair[1]))).load();
    }
  });
  test('140 catalog photos and integer-centavo pricing remain intact', () {
    expect(products.length, 140);
    expect(products.map((p) => p.images.first).toSet().length, 140);
    for (final p in products) {
      expect(File(p.images.first).existsSync(), isTrue);
    }
    final totals = CartTotals.calculate(
      {products.first.id: 1},
      products,
      'BREAK10',
    );
    expect(totals.discount, (totals.subtotal * .1).round().clamp(0, 150000));
    expect(
      totals.total,
      totals.subtotal - totals.discount + totals.shipping + totals.tax,
    );
  });
  test(
    'Existing accounts, saved inventory and commerce survive state replacement',
    () async {
      final auth = AuthController(store);
      await auth.register('Demo Player', 'demo@example.test', 'password123');
      await auth.login('demo@example.test', 'password123', true);
      final shop = ShopController(store, products, auth);
      await shop.add(products.first);
      await shop.favorite(products[1].id);
      await shop.saveProduct(
        products.first.copyWith(stock: products.first.stock + 3),
      );
      final loaded = await CatalogRepository(store).load();
      final restored = ShopController(store, loaded, AuthController(store));
      expect(restored.state.cart[products.first.id], 1);
      expect(restored.state.wishlist, contains(products[1].id));
      expect(restored.state.products.first.stock, products.first.stock + 3);
      expect(AuthController(store).state?['email'], 'demo@example.test');
    },
  );
  test(
    'Serialized cart mutations, checkout and historical receipts remain consistent',
    () async {
      final shop = ShopController(store, products, AuthController(store));
      final p = products.firstWhere((p) => p.stock >= 3);
      await Future.wait([shop.add(p), shop.add(p), shop.add(p)]);
      expect(shop.state.cart[p.id], 3);
      await shop.coupon('FREESHIP');
      final delivery = {
        'Full name': 'Demo Player',
        'Contact number': '09171234567',
        'Email address': 'demo@example.test',
        'Shipping address': '123 Demo St',
        'City': 'Manila',
        'Province': 'Metro Manila',
        'Zip code': '1000',
      };
      final order = await shop.checkout(delivery, 'Cash on Delivery');
      expect(shop.state.cart, isEmpty);
      expect(order.lines.first.quantity, 3);
      expect(
        shop.state.products.firstWhere((x) => x.id == p.id).stock,
        p.stock - 3,
      );
      await shop.deleteProduct(p.id);
      final restored = ShopController(
        store,
        await CatalogRepository(store).load(),
        AuthController(store),
      );
      expect(restored.state.orders.first.lines.first.product.price, p.price);
      await restored.advance(order.id);
      expect(restored.state.orders.first.status, 1);
      expect(restored.state.products.any((x) => x.id == p.id), isFalse);
    },
  );
  test(
    'Local authentication reset and password compatibility are retained',
    () async {
      final auth = AuthController(store);
      await auth.register('Player', 'player@example.test', 'password123');
      final code = auth.requestReset('player@example.test');
      await auth.resetPassword(code, 'newpassword123');
      await auth.login('player@example.test', 'newpassword123', true);
      await auth.changePassword('newpassword123', 'changedpassword123');
      await auth.logout();
      await auth.login('player@example.test', 'changedpassword123', true);
      expect(auth.state?['name'], 'Player');
    },
  );
  testWidgets('Lesson form validates and changes password visibility', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonForm(
            fields: [
              FieldSpec(
                'Email',
                validator: (v) =>
                    v?.contains('@') == true ? null : 'Invalid email',
              ),
              const FieldSpec(
                'Password',
                password: true,
                keyboard: TextInputType.visiblePassword,
              ),
            ],
            submit: 'Save',
            onSubmit: (v) async {
              submitted = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email'), findsOneWidget);
    expect(submitted, isFalse);
    await tester.enterText(
      find.byType(TextFormField).first,
      'demo@example.test',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.text('Show passwords'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });
  testWidgets(
    'Lesson storefront, shopping flow and settings render at 360 and 390 pixels',
    (tester) async {
      for (final width in [360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          CueApp(key: ValueKey(width), store: store, products: products),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final captureDir = Directory('test/screenshots');
        Future<void> capture(String name) async {
          if (width != 390) return;
          final context = tester.element(find.byType(Scaffold));
          await tester.runAsync(() async {
            await Future.wait([
              precacheImage(
                const AssetImage('assets/branding/CUE-app-icon.png'),
                context,
              ),
              for (final p in products.take(4))
                precacheImage(
                  ResizeImage(AssetImage(p.images.first), width: 1000),
                  context,
                ),
              for (final p
                  in products.where((p) => p.category == 'Pool Cues').take(3))
                precacheImage(AssetImage(p.images.first), context),
              for (final p in products.where((p) => p.featured).take(4))
                precacheImage(
                  ResizeImage(AssetImage(p.images.first), width: 1000),
                  context,
                ),
            ]);
          });
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final img = await boundary.toImage(pixelRatio: 2);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            captureDir.createSync(recursive: true);
            File(
              '${captureDir.path}/$name.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
          });
        }

        Future<void> tapText(String text) async {
          if (find.text(text).evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.text(text),
              250,
              scrollable: find.byType(Scrollable).first,
            );
          }
          final f = find.text(text).first;
          await Scrollable.ensureVisible(tester.element(f), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(f);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await capture('home');
        await tester.tap(find.byTooltip('Shop'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('catalog');
        await tester.enterText(
          find.byType(TextFormField).first,
          'Roku blue chalk',
        );
        await tester.pumpAndSettle();
        expect(find.text('1 products'), findsOneWidget);
        await tapText('View details');
        await capture('product');
        await tapText('Add to cart');
        expect(find.text('Added to cart'), findsOneWidget);
        await tester.tap(find.byTooltip('Shopping cart'));
        await tester.pumpAndSettle();
        await capture('cart');
        await tapText('Continue to checkout');
        await capture('checkout');
        final values = [
          'Demo Player',
          '09171234567',
          'demo@example.test',
          '123 Demo St',
          'Manila',
          'Metro Manila',
          '1000',
        ];
        for (var i = 0; i < values.length; i++) {
          final f = find.byType(TextFormField).at(i);
          await tester.ensureVisible(f);
          await tester.enterText(f, values[i]);
        }
        await tapText('Review order');
        await capture('review');
        await tapText('Acknowledge simulated payment');
        await tapText('Place demo order');
        expect(find.text('Order confirmed'), findsOneWidget);
        await capture('order');
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tapText('My orders');
        await capture('orders');
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tapText('Sign in');
        await capture('login');
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tapText('Admin demo panel');
        await capture('admin');
        await tapText('Manage inventory');
        await tapText('Edit product');
        expect(find.text('Save product'), findsOneWidget);
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tapText('Contact support');
        expect(find.text('Frequently asked questions'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
