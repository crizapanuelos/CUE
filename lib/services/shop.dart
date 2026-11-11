import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../core/commerce.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/local_store.dart';
import '../utils/format.dart';
import '../constants/catalog.dart';
import '../core/delivery.dart';
import '../core/media_migration.dart';

class ShopState {
  final List<Product> products;
  final Map<String, int> cart;
  final Set<String> wishlist;
  final List<String> recent;
  final List<ShopOrder> orders;
  final String coupon;
  const ShopState({
    required this.products,
    this.cart = const {},
    this.wishlist = const {},
    this.recent = const [],
    this.orders = const [],
    this.coupon = '',
  });
  ShopState copy({
    List<Product>? products,
    Map<String, int>? cart,
    Set<String>? wishlist,
    List<String>? recent,
    List<ShopOrder>? orders,
    String? coupon,
  }) => ShopState(
    products: products ?? this.products,
    cart: cart ?? this.cart,
    wishlist: wishlist ?? this.wishlist,
    recent: recent ?? this.recent,
    orders: orders ?? this.orders,
    coupon: coupon ?? this.coupon,
  );
  CartTotals get totals => CartTotals.calculate(cart, products, coupon);
}

/// One immutable commerce aggregate keeps inventory, cart and checkout consistent.
class ShopController {
  final LocalStore store;
  final List<Product> initialProducts;
  final AuthController auth;
  late ShopState state;
  ShopController(this.store, this.initialProducts, this.auth) {
    state = build();
  }
  Future<void> _tail = Future<void>.value();
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    return result;
  }

  Future<void> add(Product p, [int quantity = 1]) =>
      _serialize(() => _add(p, quantity));
  Future<void> quantity(String id, int qty) =>
      _serialize(() => _quantity(id, qty));
  Future<void> adjust(String id, int delta) =>
      _serialize(() => _quantity(id, (state.cart[id] ?? 0) + delta));
  Future<void> favorite(String id) => _serialize(() => _favorite(id));
  Future<void> viewed(String id) => _serialize(() => _viewed(id));
  Future<void> coupon(String value) => _serialize(() => _coupon(value));
  Future<ShopOrder> checkout(Map<String, String> delivery, String payment) =>
      _serialize(() => _checkout(delivery, payment));
  Future<void> advance(String id) => _serialize(() => _advance(id));
  Future<void> saveProduct(Product p) => _serialize(() => _saveProduct(p));
  Future<void> deleteProduct(String id) => _serialize(() => _deleteProduct(id));
  Future<void> moveToCart(Product p) => _serialize(() async {
    final current = state.products.firstWhere((x) => x.id == p.id);
    final n = (state.cart[p.id] ?? 0) + 1;
    if (n > current.stock) {
      throw StateError('Stock limit reached.');
    }
    await _commit(
      state.copy(
        cart: {...state.cart, p.id: n},
        wishlist: {...state.wishlist}..remove(p.id),
      ),
    );
  });
  Future<void> saveForLater(String id) => _serialize(() async {
    await _commit(
      state.copy(
        cart: {...state.cart}..remove(id),
        wishlist: {...state.wishlist, id},
      ),
    );
  });

  String get owner => auth.state?['email'] ?? 'guest';
  ShopState build() {
    final data = store.read('commerce', <String, dynamic>{}) as Map;
    return ShopState(
      products: initialProducts,
      cart: Map<String, int>.from(data['cart'] ?? {}),
      wishlist: Set<String>.from(data['wishlist'] ?? []),
      recent: List<String>.from(data['recent'] ?? []),
      coupon: data['coupon'] ?? '',
      orders: (data['orders'] as List? ?? [])
          .map(
            (j) => upgradeOrderMedia(
              ShopOrder.fromJson(Map<String, dynamic>.from(j)),
              initialProducts,
            ),
          )
          .toList(),
    );
  }

  Future<void> _commit(ShopState next) async {
    // A single saved envelope makes order + stock + cart writes atomic at app level.
    await store.write('commerce', {
      'mediaRevision': 2,
      'cart': next.cart,
      'wishlist': next.wishlist.toList(),
      'recent': next.recent,
      'coupon': next.coupon,
      'orders': next.orders.map((o) => o.toJson()).toList(),
      'products': next.products.map((p) => p.toJson()).toList(),
    });
    state = next;
  }

  Future<void> _add(Product p, [int quantity = 1]) async {
    final current = state.products.where((x) => x.id == p.id).firstOrNull;
    if (current == null) {
      throw StateError('This product is no longer available.');
    }
    final n = (state.cart[p.id] ?? 0) + quantity;
    if (n > current.stock) {
      throw StateError('Only ${current.stock} available.');
    }
    if (quantity < 1) {
      throw StateError('Choose a positive quantity.');
    }
    await _commit(state.copy(cart: {...state.cart, p.id: n}));
  }

  Future<void> _quantity(String id, int qty) async {
    final cart = {...state.cart};
    if (qty <= 0) {
      cart.remove(id);
    } else {
      final p = state.products.firstWhere((p) => p.id == id);
      if (qty > p.stock) {
        throw StateError('Stock limit reached.');
      }
      cart[id] = qty;
    }
    await _commit(state.copy(cart: cart));
  }

  Future<void> _favorite(String id) async {
    final items = {...state.wishlist};
    items.contains(id) ? items.remove(id) : items.add(id);
    await _commit(state.copy(wishlist: items));
  }

  Future<void> _viewed(String id) => _commit(
    state.copy(
      recent: [id, ...state.recent.where((x) => x != id)].take(12).toList(),
    ),
  );
  Future<void> _coupon(String value) async {
    final code = value.trim().toUpperCase();
    if (!['', 'BREAK10', 'FREESHIP'].contains(code)) {
      throw StateError('Invalid code. Try BREAK10 or FREESHIP.');
    }
    await _commit(state.copy(coupon: code));
  }

  bool _checkingOut = false;
  Future<ShopOrder> _checkout(
    Map<String, String> delivery,
    String payment,
  ) async {
    if (deliveryFields.any(
          (key) => deliveryError(key, delivery[key]) != null,
        ) ||
        !paymentMethods.contains(payment)) {
      throw StateError(
        'Complete valid delivery details and choose a supported demo payment method.',
      );
    }
    if (_checkingOut) {
      throw StateError('Order is already being placed.');
    }
    _checkingOut = true;
    try {
      if (state.cart.isEmpty) {
        throw StateError('Your cart is empty.');
      }
      final lines = <OrderLine>[];
      final products = state.products.map((p) {
        final qty = state.cart[p.id] ?? 0;
        if (qty > p.stock) {
          throw StateError('${p.name} has insufficient stock.');
        }
        if (qty > 0) {
          lines.add(OrderLine(p, qty));
        }
        return p.copyWith(stock: p.stock - qty);
      }).toList();
      if (lines.length != state.cart.length) {
        throw StateError('A cart product is no longer available.');
      }
      final t = state.totals;
      final order = ShopOrder(
        id: 'CUE-${DateTime.now().microsecondsSinceEpoch}',
        owner: owner,
        payment: payment,
        created: DateTime.now(),
        lines: lines,
        delivery: Map.of(delivery),
        subtotal: t.subtotal,
        discount: t.discount,
        shipping: t.shipping,
        tax: t.tax,
        total: t.total,
      );
      await _commit(
        state.copy(
          products: products,
          cart: {},
          coupon: '',
          orders: [order, ...state.orders],
        ),
      );
      return order;
    } finally {
      _checkingOut = false;
    }
  }

  Future<void> _advance(String id) => _commit(
    state.copy(
      orders: state.orders.map((o) => o.id == id ? o.advance() : o).toList(),
    ),
  );
  Future<void> _saveProduct(Product p) async {
    if (p.name.trim().isEmpty ||
        p.brand.trim().isEmpty ||
        p.sku.trim().isEmpty ||
        p.description.trim().isEmpty ||
        !categories.contains(p.category) ||
        p.price <= 0 ||
        p.discountPrice < 0 ||
        p.discountPrice >= p.price ||
        p.stock < 0 ||
        p.reviews < 0 ||
        !p.rating.isFinite ||
        p.rating < 0 ||
        p.rating > 5 ||
        p.images.isEmpty ||
        p.specifications.isEmpty) {
      throw StateError(
        'Product details, prices, stock, rating, and specifications must be valid.',
      );
    }
    if (state.products.any(
      (x) => x.id != p.id && x.sku.toLowerCase() == p.sku.toLowerCase(),
    )) {
      throw StateError('SKU already exists.');
    }
    if ((state.cart[p.id] ?? 0) > p.stock) {
      throw StateError('Stock cannot be lower than the cart quantity.');
    }
    final items = [...state.products];
    final i = items.indexWhere((x) => x.id == p.id);
    i < 0 ? items.insert(0, p) : items[i] = p;
    await _commit(state.copy(products: items));
  }

  Future<void> _deleteProduct(String id) async {
    final cart = {...state.cart}..remove(id);
    await _commit(
      state.copy(
        products: state.products.where((p) => p.id != id).toList(),
        cart: cart,
        wishlist: {...state.wishlist}..remove(id),
        recent: state.recent.where((x) => x != id).toList(),
      ),
    );
  }
}

class AuthController {
  final LocalStore store;
  Map<String, dynamic>? state;
  AuthController(this.store) {
    state = build();
  }
  Map<String, dynamic>? build() {
    final session = store.read('session', null);
    return session == null ? null : Map<String, dynamic>.from(session);
  }

  String hash(String pass, String salt) =>
      sha256.convert(utf8.encode('$salt:$pass')).toString();
  List<Map<String, dynamic>> get accounts =>
      (store.read('accounts', []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> register(String name, String email, String pass) async {
    if (requiredText(name) != null ||
        emailError(email) != null ||
        passwordError(pass) != null) {
      throw StateError(
        'Enter a name, valid email and password with at least eight characters.',
      );
    }
    email = email.trim().toLowerCase();
    final users = accounts;
    if (users.any((u) => u['email'] == email)) {
      throw StateError('An account with this email already exists.');
    }
    final salt = List.generate(
      24,
      (_) => Random.secure().nextInt(256),
    ).join('-');
    users.add({
      'name': name.trim(),
      'email': email,
      'salt': salt,
      'hash': hash(pass, salt),
    });
    await store.write('accounts', users);
  }

  Future<void> login(String email, String pass, bool remember) async {
    final user = accounts
        .where((u) => u['email'] == email.trim().toLowerCase())
        .firstOrNull;
    if (user == null || user['hash'] != hash(pass, user['salt'])) {
      throw StateError('Email or password is incorrect.');
    }
    final profile = {'name': user['name'], 'email': user['email']};
    await store.write('session', remember ? profile : null);
    state = profile;
  }

  Future<void> logout() async {
    await store.write('session', null);
    state = null;
  }

  Future<void> edit(String name) async {
    if (requiredText(name) != null) {
      throw StateError('Enter your name.');
    }
    if (state == null) {
      throw StateError('Sign in to edit your profile.');
    }
    final users = accounts;
    users.firstWhere((u) => u['email'] == state!['email'])['name'] = name
        .trim();
    await store.write('accounts', users);
    final next = {...state!, 'name': name.trim()};
    if (store.read('session', null) != null) {
      await store.write('session', next);
    }
    state = next;
  }

  Future<void> changePassword(String old, String next) async {
    if (state == null || passwordError(next) != null) {
      throw StateError('Sign in and use an eight-character password.');
    }
    final users = accounts;
    final user = users.firstWhere((u) => u['email'] == state?['email']);
    if (user['hash'] != hash(old, user['salt'])) {
      throw StateError('Current password is incorrect.');
    }
    user['hash'] = hash(next, user['salt']);
    await store.write('accounts', users);
  }

  String? _otp, _resetEmail;
  DateTime? _expires;
  int _attempts = 0;
  String requestReset(String email) {
    email = email.trim().toLowerCase();
    if (!accounts.any((u) => u['email'] == email)) {
      throw StateError('No local account found for this email.');
    }
    _resetEmail = email;
    _attempts = 0;
    _expires = DateTime.now().add(const Duration(minutes: 5));
    _otp = (100000 + Random.secure().nextInt(900000)).toString();
    return _otp!;
  }

  Future<void> resetPassword(String code, String pass) async {
    if (passwordError(pass) != null) {
      throw StateError('Use at least eight characters.');
    }
    _attempts++;
    if (_otp == null ||
        _attempts > 5 ||
        DateTime.now().isAfter(_expires!) ||
        code != _otp) {
      throw StateError(
        'Invalid or expired code. Request a new code after five attempts.',
      );
    }
    final users = accounts;
    final user = users.firstWhere((u) => u['email'] == _resetEmail);
    user['hash'] = hash(pass, user['salt']);
    await store.write('accounts', users);
    _otp = null;
    _resetEmail = null;
  }
}
