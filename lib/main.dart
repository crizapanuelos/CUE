import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/product.dart';
import 'models/order.dart';
import 'services/local_store.dart';
import 'services/shop.dart';
import 'repositories/catalog_repository.dart';
import 'core/delivery.dart';
import 'utils/format.dart';
import 'constants/catalog.dart';
import 'lesson_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = LocalStore(await SharedPreferences.getInstance());
    runApp(
      CueApp(store: store, products: await CatalogRepository(store).load()),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'CUE could not load local storage. Restart the app.\n$e',
            ),
          ),
        ),
      ),
    );
  }
}

// Lesson 1: state is owned by an ordinary StatefulWidget and updated by setState.
// Device persistence is retained as the explicitly requested course exception.
class CueApp extends StatefulWidget {
  final LocalStore store;
  final List<Product> products;
  const CueApp({super.key, required this.store, required this.products});
  @override
  State<CueApp> createState() => _CueAppState();
}

class _CueAppState extends State<CueApp> {
  late final AuthController auth;
  late final ShopController shop;
  final history = <String>[];
  String page = 'Home',
      message = '',
      query = '',
      category = '',
      brand = '',
      sort = 'Popular',
      selected = '',
      payment = paymentMethods.first,
      code = '';
  int quantity = 1, photo = 0, mode = 0, intro = 0;
  double minimum = 0, maximum = 150000, rating = 0;
  bool busy = false, list = false, remember = true, accepted = false;
  Map<String, String> delivery = {};
  Color get ink =>
      (mode == 2 ||
          (mode == 0 &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark))
      ? Colors.white
      : const Color(0xFF163C2C);
  @override
  void initState() {
    super.initState();
    auth = AuthController(widget.store);
    shop = ShopController(widget.store, widget.products, auth);
    mode = (widget.store.read('theme', 0) as int).clamp(0, 2);
    page = widget.store.read('onboarded', false) == true ? 'Home' : 'Welcome';
  }

  void go(String next) => setState(() {
    history.add(page);
    page = next;
    message = '';
  });
  void back() => setState(() {
    page = history.isEmpty ? 'Home' : history.removeLast();
    message = '';
  });
  Future<void> act(
    Future<void> Function() action, [
    String success = 'Saved locally',
  ]) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
      if (mounted) setState(() => message = success);
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget heading(String s) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Text(
      s,
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink),
    ),
  );
  Widget note(String s) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s));
  Widget button(
    String s,
    VoidCallback f, {
    bool secondary = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: LessonButton(
      s,
      onPressed: busy ? null : f,
      secondary: secondary,
      icon: icon,
    ),
  );
  Widget screen(List<Widget> c) => ListView(
    key: ValueKey(page),
    padding: const EdgeInsets.all(20),
    children: c,
  );
  Widget image(Product p, {double height = 150, int index = 0}) => Container(
    height: height,
    padding: const EdgeInsets.all(4),
    color: const Color(0xFFF7F7F5),
    child: Image.asset(
      p.images[index % p.images.length],
      fit: BoxFit.contain,
      cacheWidth: 1000,
      semanticLabel: p.name,
      errorBuilder: (_, e, s) => const Placeholder(),
    ),
  );
  void showProduct(Product p) {
    selected = p.id;
    quantity = 1;
    photo = 0;
    go('Product');
    act(() => shop.viewed(p.id), '');
  }

  Widget productCard(Product p) => LessonPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        image(p),
        const SizedBox(height: 8),
        Text(
          p.brand.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(money(p.effectivePrice)),
        button('View details', () => showProduct(p)),
        Row(
          children: [
            Expanded(
              child: LessonButton(
                'Save',
                secondary: true,
                onPressed: busy
                    ? null
                    : () => act(() => shop.favorite(p.id), 'Wishlist updated'),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: LessonButton(
                'Add',
                onPressed: busy || p.stock == 0
                    ? null
                    : () => act(() => shop.add(p), 'Added to cart'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget grid(List<Product> items) {
    if (items.isEmpty) return note('No products in this selection.');
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = view.physicalSize.width / view.devicePixelRatio;
    final columns = list
        ? 1
        : width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2;
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 4,
      crossAxisSpacing: 12,
      childAspectRatio: ((width - 40 - (columns - 1) * 12) / columns) / 380,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map(productCard).toList(),
    );
  }

  Widget choices(List<String> options, void Function(String) choose) =>
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final s in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LessonButton(
                  s,
                  secondary: true,
                  onPressed: () => choose(s),
                ),
              ),
          ],
        ),
      );
  List<Product> get filtered {
    final items = shop.state.products
        .where(
          (p) =>
              (category.isEmpty || p.category == category) &&
              (brand.isEmpty || p.brand == brand) &&
              p.effectivePrice >= minimum * 100 &&
              p.effectivePrice <= maximum * 100 &&
              p.rating >= rating &&
              '${p.name} ${p.brand} ${p.category} ${p.sku}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    items.sort(
      (a, b) => switch (sort) {
        'Price ascending' => a.effectivePrice.compareTo(b.effectivePrice),
        'Price descending' => b.effectivePrice.compareTo(a.effectivePrice),
        'Rating' => b.rating.compareTo(a.rating),
        'Newest' => b.id.compareTo(a.id),
        _ => b.reviews.compareTo(a.reviews),
      },
    );
    return items;
  }

  Widget home() => screen([
    Text(
      'GOOD TO SEE YOU, ${auth.state?['name'] ?? 'PLAYER'}',
      style: const TextStyle(fontSize: 11, letterSpacing: 1.2),
    ),
    heading('Find your edge.'),
    TextFormField(
      decoration: const InputDecoration(
        labelText: 'Search cues, cloth, accessories',
        prefixIcon: Icon(Icons.search),
      ),
      onFieldSubmitted: (v) {
        query = v;
        category = '';
        brand = '';
        go('Shop');
      },
    ),
    const SizedBox(height: 18),
    SizedBox(
      height: 255,
      child: CarouselView(
        itemExtent: double.infinity,
        itemSnapping: true,
        padding: EdgeInsets.zero,
        children: [
          for (final p
              in shop.state.products
                  .where((p) => p.category == 'Pool Cues')
                  .take(3))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF103F2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.asset(
                      p.images.first,
                      fit: BoxFit.contain,
                      semanticLabel: p.name,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  button('Explore collection', () {
                    category = p.category;
                    query = '';
                    brand = '';
                    go('Shop');
                  }, secondary: true),
                ],
              ),
            ),
        ],
      ),
    ),
    heading('Shop by equipment'),
    choices(categories, (v) {
      category = v;
      brand = '';
      query = '';
      go('Shop');
    }),
    heading('Featured picks'),
    grid(shop.state.products.where((p) => p.featured).take(4).toList()),
    LessonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.local_offer, color: Color(0xFFB8922F)),
          note(
            'Use BREAK10 for 10% off, up to ₱1,500. Free shipping from ₱5,000.',
          ),
          button('Shop all equipment', () {
            category = '';
            brand = '';
            query = '';
            go('Shop');
          }),
        ],
      ),
    ),
    heading('New arrivals'),
    grid(shop.state.products.reversed.take(4).toList()),
    heading('Brands'),
    choices(brands, (v) {
      brand = v;
      category = '';
      query = '';
      go('Shop');
    }),
    note('CUE · For the love of the game.\nOffline shopping demonstration.'),
  ]);
  Widget catalog() => screen([
    heading(category.isEmpty ? 'Shop all equipment' : category),
    TextFormField(
      key: ValueKey('search-$category-$brand'),
      initialValue: query,
      decoration: const InputDecoration(
        labelText: 'Search equipment',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (v) => setState(() => query = v),
    ),
    Row(
      children: [
        Expanded(
          child: button('Filters', () => go('Filters'), secondary: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: button(
            list ? 'Grid view' : 'List view',
            () => setState(() => list = !list),
            secondary: true,
          ),
        ),
      ],
    ),
    Text('${filtered.length} products'),
    choices([
      'Popular',
      'Price ascending',
      'Price descending',
      'Rating',
      'Newest',
    ], (v) => setState(() => sort = v)),
    grid(filtered),
  ]);
  String? numberError(String? s) {
    final n = double.tryParse(s ?? '');
    return n != null && n.isFinite && n >= 0
        ? null
        : 'Enter a non-negative number';
  }

  Widget filters() => screen([
    heading('Refine your game'),
    note(
      'Choose a listed category or brand. Leave either field blank for all products.',
    ),
    choices([
      'All categories',
      ...categories,
    ], (v) => setState(() => category = v == 'All categories' ? '' : v)),
    choices([
      'All brands',
      ...brands,
    ], (v) => setState(() => brand = v == 'All brands' ? '' : v)),
    LessonForm(
      key: ValueKey('filters-$category-$brand'),
      fields: [
        FieldSpec(
          'Category',
          initial: category,
          validator: (v) => (v ?? '').isEmpty || categories.contains(v)
              ? null
              : 'Choose a listed category',
        ),
        FieldSpec(
          'Brand',
          initial: brand,
          validator: (v) => (v ?? '').isEmpty || brands.contains(v)
              ? null
              : 'Choose a listed brand',
        ),
        FieldSpec(
          'Minimum price PHP',
          initial: '$minimum',
          keyboard: TextInputType.number,
          validator: numberError,
        ),
        FieldSpec(
          'Maximum price PHP',
          initial: '$maximum',
          keyboard: TextInputType.number,
          validator: numberError,
        ),
        FieldSpec(
          'Minimum rating',
          initial: '$rating',
          keyboard: TextInputType.number,
          validator: (v) => numberError(v) == null && double.parse(v!) <= 5
              ? null
              : 'Use a rating from 0 to 5',
        ),
      ],
      submit: 'Show results',
      onSubmit: (v) async {
        final lo = double.parse(v['Minimum price PHP']!),
            hi = double.parse(v['Maximum price PHP']!);
        if (lo > hi) {
          throw StateError('Minimum price must not exceed maximum price.');
        }
        setState(() {
          category = v['Category']!;
          brand = v['Brand']!;
          minimum = lo;
          maximum = hi;
          rating = double.parse(v['Minimum rating']!);
        });
        back();
      },
    ),
    button(
      'Reset filters',
      () => setState(() {
        category = '';
        brand = '';
        minimum = 0;
        maximum = 150000;
        rating = 0;
      }),
      secondary: true,
    ),
  ]);
  Widget product() {
    final p = shop.state.products.where((p) => p.id == selected).firstOrNull;
    if (p == null) {
      return screen([
        heading('Product unavailable'),
        note('This item was removed. Browse the catalog for other equipment.'),
      ]);
    }
    return screen([
      SizedBox(
        height: 265,
        child: CarouselView(
          key: ValueKey(p.id),
          itemExtent: double.infinity,
          itemSnapping: true,
          padding: EdgeInsets.zero,
          onIndexChanged: (v) => setState(() => photo = v),
          children: [
            for (var i = 0; i < p.images.length; i++)
              image(p, height: 265, index: i),
          ],
        ),
      ),
      Text(
        '${photo + 1} / ${p.images.length} · AI-generated product image',
        style: const TextStyle(fontSize: 11),
      ),
      const SizedBox(height: 12),
      Text(p.category.toUpperCase()),
      heading(p.name),
      Text('${p.brand} · ★ ${p.rating} · ${p.reviews} sample ratings'),
      Text(
        money(p.effectivePrice),
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink),
      ),
      if (p.discountPrice > 0) ...[
        Text(
          money(p.price),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.rotate(
              angle: -.06,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFE8DEB4),
                child: Text(
                  'Save ${money(p.price - p.effectivePrice)}',
                  style: const TextStyle(color: Color(0xFF163C2C)),
                ),
              ),
            ),
          ),
        ),
      ],
      note('${p.stock} in stock · ${p.sku}'),
      note(p.description),
      Row(
        children: [
          Expanded(child: Text('Quantity: $quantity')),
          LessonButton(
            '−',
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
          const SizedBox(width: 8),
          LessonButton(
            '+',
            onPressed: quantity < p.stock
                ? () => setState(() => quantity++)
                : null,
          ),
        ],
      ),
      button(
        p.stock == 0 ? 'Out of stock' : 'Add to cart',
        () => act(() => shop.add(p, quantity), 'Added to cart'),
        icon: Icons.add_shopping_cart,
      ),
      button(
        shop.state.wishlist.contains(p.id)
            ? 'Remove from wishlist'
            : 'Save to wishlist',
        () => act(() => shop.favorite(p.id), 'Wishlist updated'),
        secondary: true,
      ),
      heading('Specifications'),
      for (final e in p.specifications.entries)
        LessonPanel(
          child: Row(
            children: [
              Expanded(child: Text(e.key)),
              Expanded(child: Text(e.value)),
            ],
          ),
        ),
      note(
        'Product photographs are AI-generated. Ratings and reviews are sample data.',
      ),
    ]);
  }

  Widget totals() {
    final t = shop.state.totals;
    return LessonPanel(
      child: Column(
        children: [
          for (final e in {
            'Subtotal': money(t.subtotal),
            'Coupon discount': '−${money(t.discount)}',
            'Shipping': t.shipping == 0 ? 'FREE' : money(t.shipping),
            'Simulated tax 12%': money(t.tax),
            'Total': money(t.total),
            'You save': money(t.savings),
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(e.key)),
                  Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget cart() => screen([
    heading('Your cart'),
    if (shop.state.cart.isEmpty)
      note('Your cart is empty. Add equipment from the shop.'),
    for (final p in shop.state.products.where(
      (p) => shop.state.cart.containsKey(p.id),
    ))
      LessonPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: 75, child: image(p, height: 75)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${p.name}\n${money(p.effectivePrice)}\nQuantity: ${shop.state.cart[p.id]}',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: button(
                    '−',
                    () => act(() => shop.adjust(p.id, -1), ''),
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: button(
                    '+',
                    () => act(() => shop.adjust(p.id, 1), ''),
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: button(
                    'Remove',
                    () => act(() => shop.quantity(p.id, 0), 'Removed'),
                    secondary: true,
                  ),
                ),
              ],
            ),
            button(
              'Save for later',
              () => act(() => shop.saveForLater(p.id), 'Moved to wishlist'),
              secondary: true,
            ),
          ],
        ),
      ),
    if (shop.state.cart.isNotEmpty) ...[
      LessonForm(
        key: ValueKey('coupon-${shop.state.coupon}'),
        fields: [FieldSpec('Promo code', initial: shop.state.coupon)],
        submit: 'Apply code',
        onSubmit: (v) async {
          await shop.coupon(v['Promo code']!);
          setState(() => message = 'Promo code updated');
        },
      ),
      totals(),
      note(
        'BREAK10: 10% off up to ₱1,500. FREESHIP removes shipping. One code per order.',
      ),
      button('Continue to checkout', () {
        accepted = false;
        go('Checkout');
      }),
    ],
  ]);
  Widget checkout() {
    final saved = Map<String, dynamic>.from(
      widget.store.read('delivery-${auth.state?['email'] ?? 'guest'}', {}),
    );
    String initial(String label) {
      if (delivery.containsKey(label)) return delivery[label]!;
      if (saved.containsKey(label)) return saved[label].toString();
      if (label == 'Full name') return auth.state?['name']?.toString() ?? '';
      if (label == 'Email address') {
        return auth.state?['email']?.toString() ?? '';
      }
      return '';
    }

    return screen([
      heading('Delivery details'),
      if (shop.state.cart.isEmpty)
        note('Your cart is empty.')
      else
        LessonForm(
          key: const ValueKey('delivery-form'),
          description:
              'Use fictional information for this local demonstration.',
          fields: [
            for (final label in deliveryFields)
              FieldSpec(
                label,
                initial: initial(label),
                validator: (v) => deliveryError(label, v),
                keyboard: label == 'Email address'
                    ? TextInputType.emailAddress
                    : ['Zip code', 'Contact number'].contains(label)
                    ? TextInputType.number
                    : TextInputType.text,
              ),
          ],
          submit: 'Review order',
          onSubmit: (v) async {
            delivery = v;
            accepted = false;
            go('Review order');
          },
        ),
    ]);
  }

  Widget review() => screen([
    heading('Review and payment'),
    LessonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in delivery.entries) Text('${e.key}: ${e.value}'),
        ],
      ),
    ),
    totals(),
    heading('Payment method'),
    for (final method in paymentMethods)
      button(
        '${payment == method ? '[x] ' : ''}$method',
        () => setState(() => payment = method),
        secondary: payment != method,
      ),
    note(
      'No money is collected. This order creates no real purchase or delivery.',
    ),
    button(
      accepted
          ? '[x] Simulation acknowledged'
          : 'Acknowledge simulated payment',
      () => setState(() => accepted = !accepted),
      secondary: true,
    ),
    button(
      'Place demo order',
      () => act(() async {
        if (!accepted) {
          throw StateError('Acknowledge the simulated payment first.');
        }
        await widget.store.write(
          'delivery-${auth.state?['email'] ?? 'guest'}',
          delivery,
        );
        final o = await shop.checkout(delivery, payment);
        setState(() {
          selected = o.id;
          page = 'Order';
          history.clear();
        });
      }, 'Order confirmed'),
    ),
  ]);
  Widget orders() => screen([
    heading('My orders'),
    if (!shop.state.orders.any(
      (o) => o.owner == (auth.state?['email'] ?? 'guest'),
    ))
      note('Your completed checkouts will appear here.'),
    for (final o in shop.state.orders.where(
      (o) => o.owner == (auth.state?['email'] ?? 'guest'),
    ))
      LessonPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(o.id),
            Text('${orderStatuses[o.status]} · ${money(o.total)}'),
            button('View order', () {
              selected = o.id;
              go('Order');
            }, secondary: true),
          ],
        ),
      ),
  ]);
  Widget order() {
    final o = shop.state.orders.where((o) => o.id == selected).firstOrNull;
    if (o == null || o.owner != (auth.state?['email'] ?? 'guest')) {
      return screen([note('Order unavailable for this account.')]);
    }
    return screen([
      heading('Order details'),
      note(o.id),
      heading(orderStatuses[o.status]),
      for (final line in o.lines)
        LessonPanel(
          child: Row(
            children: [
              SizedBox(width: 70, child: image(line.product, height: 70)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${line.product.name}\n${line.quantity} × ${money(line.product.effectivePrice)}',
                ),
              ),
            ],
          ),
        ),
      note(
        'Total: ${money(o.total)}\nPayment: ${o.payment}\n${o.delivery.values.join(', ')}',
      ),
      for (var i = 0; i < orderStatuses.length; i++)
        note('${i <= o.status ? '[x]' : '[ ]'} ${orderStatuses[i]}'),
      if (o.status < 5)
        button(
          'Simulate next delivery step',
          () => act(() => shop.advance(o.id), 'Tracking updated'),
        ),
    ]);
  }

  Widget account() => screen([
    heading(auth.state?['name']?.toString() ?? 'Guest player'),
    note(auth.state?['email']?.toString() ?? 'Welcome to CUE'),
    if (auth.state == null) ...[
      button('Sign in', () => go('Sign in')),
      button('Create account', () => go('Create account'), secondary: true),
    ] else ...[
      button('Edit profile', () => go('Edit profile'), secondary: true),
      button('Change password', () => go('Change password'), secondary: true),
    ],
    button('My orders', () => go('Orders'), secondary: true),
    button('Notifications', () => go('Notifications'), secondary: true),
    button('Contact support', () => go('Support'), secondary: true),
    heading('Appearance'),
    choices(
      ['System', 'Light', 'Dark'],
      (v) => act(() async {
        mode = ['System', 'Light', 'Dark'].indexOf(v);
        await widget.store.write('theme', mode);
      }, 'Appearance updated'),
    ),
    button('Admin demo panel', () => go('Admin'), secondary: true),
    note('Public local sandbox. Changes affect only this installation.'),
    if (auth.state != null)
      button(
        'Sign out',
        () => act(() => auth.logout(), 'Signed out'),
        secondary: true,
      ),
    note(
      'CUE 1.3.0\nBuilt with lesson widgets and setState. Local storage retained.',
    ),
  ]);
  Widget authentication(bool register) => screen([
    heading(register ? 'Join the club.' : 'Back for another game?'),
    Center(
      child: Image.asset(
        'assets/branding/CUE-app-icon.png',
        height: 110,
        semanticLabel: 'CUE logo',
      ),
    ),
    note('Local demo accounts. Use fictional details and a demo password.'),
    LessonForm(
      key: ValueKey(page),
      fields: [
        if (register) FieldSpec('Full name', validator: requiredText),
        FieldSpec(
          'Email address',
          validator: emailError,
          keyboard: TextInputType.emailAddress,
        ),
        FieldSpec(
          'Password',
          validator: passwordError,
          keyboard: TextInputType.visiblePassword,
          password: true,
        ),
      ],
      submit: register ? 'Create account' : 'Sign in',
      onSubmit: (v) async {
        if (register) {
          await auth.register(
            v['Full name']!,
            v['Email address']!,
            v['Password']!,
          );
        }
        await auth.login(v['Email address']!, v['Password']!, remember);
        setState(() {
          page = 'Home';
          history.clear();
          message = 'Welcome to CUE';
        });
      },
    ),
    button(
      remember ? '[x] Remember me' : 'Remember me',
      () => setState(() => remember = !remember),
      secondary: true,
    ),
    button(
      register ? 'Already registered? Sign in' : 'Create an account',
      () => go(register ? 'Sign in' : 'Create account'),
      secondary: true,
    ),
    button('Forgot password', () {
      code = '';
      go('Reset password');
    }, secondary: true),
    button(
      'Continue as guest',
      () => act(() async {
        await auth.logout();
        setState(() {
          page = 'Home';
          history.clear();
        });
      }, ''),
      secondary: true,
    ),
  ]);
  Widget reset() => screen([
    heading('Reset password'),
    note('Local OTP simulation. No email is sent.'),
    if (code.isNotEmpty)
      note(
        'Demo code: $code · expires in five minutes · maximum five attempts.',
      ),
    LessonForm(
      key: ValueKey('reset-$code'),
      fields: [
        if (code.isEmpty)
          FieldSpec(
            'Email address',
            validator: emailError,
            keyboard: TextInputType.emailAddress,
          )
        else ...[
          FieldSpec(
            'OTP',
            keyboard: TextInputType.number,
            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                ? null
                : 'Enter six digits',
          ),
          FieldSpec(
            'New password',
            validator: passwordError,
            password: true,
            keyboard: TextInputType.visiblePassword,
          ),
        ],
      ],
      submit: code.isEmpty ? 'Generate demo code' : 'Reset password',
      onSubmit: (v) async {
        if (code.isEmpty) {
          final generated = auth.requestReset(v['Email address']!);
          setState(() => code = generated);
        } else {
          await auth.resetPassword(v['OTP']!, v['New password']!);
          setState(() {
            page = 'Sign in';
            message = 'Password reset. Sign in again.';
          });
        }
      },
    ),
  ]);
  Widget profileEdit() => screen([
    heading('Edit profile'),
    LessonForm(
      key: const ValueKey('profile'),
      fields: [
        FieldSpec(
          'Full name',
          initial: auth.state?['name']?.toString() ?? '',
          validator: requiredText,
        ),
      ],
      submit: 'Save changes',
      onSubmit: (v) async {
        await auth.edit(v['Full name']!);
        setState(() => message = 'Profile updated');
      },
    ),
  ]);
  Widget passwordEdit() => screen([
    heading('Change password'),
    LessonForm(
      key: const ValueKey('password'),
      fields: [
        FieldSpec(
          'Current password',
          validator: requiredText,
          password: true,
          keyboard: TextInputType.visiblePassword,
        ),
        FieldSpec(
          'New password',
          validator: passwordError,
          password: true,
          keyboard: TextInputType.visiblePassword,
        ),
        FieldSpec(
          'Confirm password',
          validator: passwordError,
          password: true,
          keyboard: TextInputType.visiblePassword,
        ),
      ],
      submit: 'Save password',
      onSubmit: (v) async {
        if (v['New password'] != v['Confirm password']) {
          throw StateError('Passwords do not match.');
        }
        await auth.changePassword(v['Current password']!, v['New password']!);
        setState(() => message = 'Password updated');
      },
    ),
  ]);
  Widget support() => screen([
    heading('We are in your corner'),
    note(
      'CUE Demo Store · Manila, Philippines\nMonday–Saturday, 9 AM–6 PM\nsupport@cue.example (demo address)',
    ),
    heading('Frequently asked questions'),
    LessonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Does CUE need internet?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          note('No. Product photos and shopping data stay on this device.'),
          const Text(
            'Are payments and deliveries real?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          note(
            'No. All payments, tracking, prices, and orders are demonstration data.',
          ),
          const Text(
            'How much is shipping?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          note(
            '₱150, or free from ₱5,000. FREESHIP removes shipping. BREAK10 gives 10% off capped at ₱1,500.',
          ),
        ],
      ),
    ),
    heading('Leave a local support request'),
    LessonForm(
      key: const ValueKey('support'),
      description: 'Saved locally only. This form sends no message.',
      fields: [
        FieldSpec('Name', validator: requiredText),
        FieldSpec(
          'Email',
          validator: emailError,
          keyboard: TextInputType.emailAddress,
        ),
        FieldSpec(
          'Message',
          lines: 4,
          validator: (v) => (v?.trim().length ?? 0) >= 10
              ? null
              : 'Use at least ten characters',
        ),
      ],
      submit: 'Save support request',
      onSubmit: (v) async {
        final requests = List<dynamic>.from(widget.store.read('support', []));
        requests.add({...v, 'created': DateTime.now().toIso8601String()});
        await widget.store.write('support', requests);
        setState(() => message = 'Support request saved locally');
      },
    ),
    heading('Privacy and terms'),
    note(
      'CUE is a fictional shop. No real purchases, deliveries, remote authentication, or messages occur. Data stays in device preferences, which are not encrypted secure storage. Use fictitious details. Clearing app data removes saved information. Product photographs are AI-generated representations. Brands identify mock catalog families.',
    ),
  ]);
  Widget admin() => screen([
    heading('Admin demo panel'),
    note('Public local sandbox · all changes stay on this device.'),
    Row(
      children: [
        Expanded(
          child: LessonPanel(
            child: Column(
              children: [
                Text(
                  '${shop.state.products.length}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Products'),
              ],
            ),
          ),
        ),
        Expanded(
          child: LessonPanel(
            child: Column(
              children: [
                Text(
                  '${shop.state.orders.length}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Local orders'),
              ],
            ),
          ),
        ),
      ],
    ),
    LessonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order value: ${money(shop.state.orders.fold(0, (sum, o) => sum + o.total))}',
          ),
          Text(
            'Low stock: ${shop.state.products.where((p) => p.stock < 10).length}',
          ),
        ],
      ),
    ),
    button('Manage inventory', () => go('Inventory')),
    button('Add product', () {
      selected = '';
      go('Product editor');
    }, secondary: true),
    button('All local orders', () => go('Admin orders'), secondary: true),
  ]);
  Widget inventory() => screen([
    heading('Inventory'),
    for (final p in shop.state.products)
      LessonPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${p.sku} · ${p.stock} in stock · ${money(p.effectivePrice)}'),
            button('Edit product', () {
              selected = p.id;
              go('Product editor');
            }, secondary: true),
            button('Delete product', () {
              selected = p.id;
              go('Delete product');
            }, secondary: true),
          ],
        ),
      ),
  ]);
  Widget deleteProduct() => screen([
    heading('Delete this product?'),
    note(
      'The product and its cart and wishlist references will be removed from this installation. Historical orders remain.',
    ),
    button(
      'Confirm deletion',
      () => act(() async {
        await shop.deleteProduct(selected);
        setState(() => page = 'Inventory');
      }, 'Product deleted'),
    ),
    button('Cancel', back, secondary: true),
  ]);
  Widget productEditor() {
    final p = shop.state.products.where((p) => p.id == selected).firstOrNull;
    return screen([
      heading(p == null ? 'Add product' : 'Edit product'),
      note(
        'Enter a category exactly as listed. Existing photographs stay unchanged. New products use a matching category photo.',
      ),
      note(categories.join(' · ')),
      LessonForm(
        key: ValueKey('editor-$selected'),
        fields: [
          FieldSpec('Name', initial: p?.name ?? '', validator: requiredText),
          FieldSpec('Brand', initial: p?.brand ?? '', validator: requiredText),
          FieldSpec('SKU', initial: p?.sku ?? '', validator: requiredText),
          FieldSpec(
            'Category',
            initial: p?.category ?? categories.first,
            validator: (v) =>
                categories.contains(v) ? null : 'Enter a listed category',
          ),
          FieldSpec(
            'Description',
            initial: p?.description ?? '',
            validator: requiredText,
            lines: 3,
          ),
          FieldSpec(
            'Price PHP',
            initial: p == null ? '' : (p.price / 100).toString(),
            validator: numberError,
            keyboard: TextInputType.number,
          ),
          FieldSpec(
            'Sale price PHP',
            initial: ((p?.discountPrice ?? 0) / 100).toString(),
            validator: numberError,
            keyboard: TextInputType.number,
          ),
          FieldSpec(
            'Stock',
            initial: '${p?.stock ?? 1}',
            keyboard: TextInputType.number,
            validator: (v) =>
                int.tryParse(v ?? '') != null && int.parse(v!) >= 0
                ? null
                : 'Use a non-negative whole number',
          ),
          FieldSpec(
            'Specifications',
            initial:
                p?.specifications.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n') ??
                'Material: Wood',
            lines: 3,
            validator: (v) =>
                (v ?? '')
                    .split('\n')
                    .every(
                      (line) =>
                          line.contains(':') &&
                          line.split(':').first.trim().isNotEmpty &&
                          line
                              .substring(line.indexOf(':') + 1)
                              .trim()
                              .isNotEmpty,
                    )
                ? null
                : 'Use Key: Value on each line',
          ),
        ],
        submit: 'Save product',
        onSubmit: (v) async {
          final specs = <String, String>{};
          for (final line in v['Specifications']!.split('\n')) {
            final i = line.indexOf(':');
            specs[line.substring(0, i).trim()] = line.substring(i + 1).trim();
          }
          final next = Product(
            id: p?.id ?? 'BH-${DateTime.now().microsecondsSinceEpoch}',
            name: v['Name']!,
            brand: v['Brand']!,
            sku: v['SKU']!,
            category: v['Category']!,
            description: v['Description']!,
            price: (double.parse(v['Price PHP']!) * 100).round(),
            discountPrice: (double.parse(v['Sale price PHP']!) * 100).round(),
            stock: int.parse(v['Stock']!),
            reviews: p?.reviews ?? 0,
            rating: p?.rating ?? 0,
            specifications: specs,
            images:
                p?.images ??
                [
                  widget.products
                      .firstWhere((item) => item.category == v['Category'])
                      .images
                      .first,
                ],
            featured: p?.featured ?? false,
            bestSeller: p?.bestSeller ?? false,
          );
          await shop.saveProduct(next);
          setState(() {
            page = 'Inventory';
            message = 'Product saved';
          });
        },
      ),
      if (p != null) ...[
        button(
          '${p.featured ? '[x] ' : ''}Featured product',
          () => act(
            () => shop.saveProduct(
              Product.fromJson({...p.toJson(), 'featured': !p.featured}),
            ),
            'Featured flag updated',
          ),
          secondary: true,
        ),
        button(
          '${p.bestSeller ? '[x] ' : ''}Best seller',
          () => act(
            () => shop.saveProduct(
              Product.fromJson({...p.toJson(), 'bestSeller': !p.bestSeller}),
            ),
            'Best-seller flag updated',
          ),
          secondary: true,
        ),
      ],
    ]);
  }

  Widget welcome() => screen([
    Center(
      child: Image.asset(
        'assets/branding/CUE-app-icon.png',
        height: 190,
        semanticLabel: 'CUE logo',
      ),
    ),
    heading(
      [
        'Your next great break.',
        'Equipment for every player.',
        'Shop at your own pace.',
      ][intro],
    ),
    note(
      [
        'Explore 140 products with realistic photographs.',
        'Browse cues, balls, cloth, parts, and accessories.',
        'Save favorites, build a cart, and try a simulated checkout.',
      ][intro],
    ),
    button(
      intro < 2 ? 'Next' : 'Enter CUE',
      () => act(() async {
        if (intro < 2) {
          setState(() => intro++);
        } else {
          await widget.store.write('onboarded', true);
          setState(() => page = 'Home');
        }
      }, ''),
    ),
    if (intro < 2)
      button(
        'Skip introduction',
        () => act(() async {
          await widget.store.write('onboarded', true);
          setState(() => page = 'Home');
        }, ''),
        secondary: true,
      ),
  ]);
  Widget body() => switch (page) {
    'Welcome' => welcome(),
    'Home' => home(),
    'Shop' => catalog(),
    'Filters' => filters(),
    'Product' => product(),
    'Wishlist' => screen([
      heading('Your wishlist'),
      grid(
        shop.state.products
            .where((p) => shop.state.wishlist.contains(p.id))
            .toList(),
      ),
    ]),
    'Cart' => cart(),
    'Checkout' => checkout(),
    'Review order' => review(),
    'Orders' => orders(),
    'Order' => order(),
    'Account' => account(),
    'Sign in' => authentication(false),
    'Create account' => authentication(true),
    'Reset password' => reset(),
    'Edit profile' => profileEdit(),
    'Change password' => passwordEdit(),
    'Support' => support(),
    'Admin' => admin(),
    'Inventory' => inventory(),
    'Product editor' => productEditor(),
    'Delete product' => deleteProduct(),
    'Admin orders' => screen([
      heading('All local orders'),
      for (final o in shop.state.orders)
        LessonPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${o.id}\n${o.owner}\n${orderStatuses[o.status]} · ${money(o.total)}',
              ),
              if (o.status < 5)
                button(
                  'Advance delivery',
                  () => act(() => shop.advance(o.id), 'Tracking updated'),
                  secondary: true,
                ),
            ],
          ),
        ),
    ]),
    'Notifications' => screen([
      heading('Notifications'),
      note('Use BREAK10 for 10% off up to ₱1,500.'),
      for (final o in shop.state.orders.where(
        (o) => o.owner == (auth.state?['email'] ?? 'guest'),
      ))
        note('${o.id}: ${orderStatuses[o.status]}'),
    ]),
    _ => home(),
  };
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CUE',
    debugShowCheckedModeBanner: false,
    themeMode: mode == 2
        ? ThemeMode.dark
        : mode == 1
        ? ThemeMode.light
        : ThemeMode.system,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    home: Scaffold(
      appBar: AppBar(
        title: Text(page == 'Home' ? 'CUE' : page),
        leading: history.isEmpty
            ? null
            : SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton.small(
                  heroTag: null,
                  elevation: 0,
                  tooltip: 'Back',
                  onPressed: back,
                  child: const Icon(Icons.arrow_back),
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FloatingActionButton.small(
              heroTag: null,
              elevation: 0,
              tooltip: 'Shopping cart',
              onPressed: () => go('Cart'),
              child: Icon(
                Icons.shopping_bag_outlined,
                semanticLabel:
                    'Cart ${shop.state.cart.values.fold(0, (a, b) => a + b)} items',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFE8DEB4),
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF163C2C)),
              ),
            ),
          Expanded(child: body()),
        ],
      ),
      bottomNavigationBar: page == 'Welcome'
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
              child: Row(
                children: [
                  for (final item in <String, IconData>{
                    'Home': Icons.home_outlined,
                    'Shop': Icons.grid_view,
                    'Wishlist': Icons.favorite_border,
                    'Account': Icons.person_outline,
                  }.entries)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 38,
                            child: FloatingActionButton.small(
                              heroTag: null,
                              elevation: 0,
                              tooltip: item.key,
                              backgroundColor: page == item.key
                                  ? const Color(0xFFD9EADC)
                                  : const Color(0xFFEDECE5),
                              onPressed: () => setState(() {
                                page = item.key;
                                history.clear();
                                message = '';
                              }),
                              child: Icon(
                                item.value,
                                color: const Color(0xFF16432E),
                              ),
                            ),
                          ),
                          Text(item.key, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
  ThemeData theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF075139),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF131B17)
        : const Color(0xFFF5F5F2),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark
          ? const Color(0xFF213328)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    appBarTheme: const AppBarThemeData(surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(15),
    ),
  );
}
