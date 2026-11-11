import '../models/product.dart';

/// Prices use integer centavos so rounding is explicit and reproducible.
class CartTotals {
  final int subtotal, discount, shipping, tax, savings, total;
  const CartTotals(
    this.subtotal,
    this.discount,
    this.shipping,
    this.tax,
    this.savings,
    this.total,
  );
  factory CartTotals.calculate(
    Map<String, int> cart,
    List<Product> products,
    String coupon,
  ) {
    var subtotal = 0, savings = 0;
    for (final p in products) {
      final qty = cart[p.id] ?? 0;
      subtotal += p.effectivePrice * qty;
      savings += (p.price - p.effectivePrice) * qty;
    }
    final discount = coupon == 'BREAK10'
        ? (subtotal * 0.10).round().clamp(0, 150000)
        : 0;
    final shipping = subtotal == 0 || subtotal >= 500000 || coupon == 'FREESHIP'
        ? 0
        : 15000;
    final tax = ((subtotal - discount) * 0.12).round();
    return CartTotals(
      subtotal,
      discount,
      shipping,
      tax,
      savings + discount,
      subtotal - discount + shipping + tax,
    );
  }
}
